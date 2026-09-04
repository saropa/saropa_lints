"""
Shared utilities for saropa_lints scripts.

Provides ANSI color output, printing helpers, platform detection,
Saropa branding, command execution, and project path discovery.

All scripts should import from this module instead of defining
their own Color, print_*, or platform detection functions.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import io
import os
import re as _re
import shutil
import subprocess
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import NoReturn


# =============================================================================
# VERSION PATTERN
# =============================================================================
# Semver pattern matching X.Y.Z with optional pre-release suffix
# (e.g. "15.2.7", "1.0.0-beta.1"). Single source of truth — all
# version-parsing code in the publish pipeline imports this constant.
VERSION_RE = r"\d+\.\d+\.\d+(?:-[\w]+(?:\.[\w]+)*)?"


def is_prerelease_version(version: str) -> bool:
    """Return True when *version* has a semver prerelease suffix (e.g. "1.2.3-beta.1").

    Single source of truth for "is this publish a prerelease" — vsce,
    ovsx, and `gh release create` all need an explicit --pre-release (or
    --prerelease) flag to route to their prerelease channel instead of
    the default (stable) one.
    """
    return "-" in version


def strip_prerelease_suffix(version: str) -> str:
    """Return the plain MAJOR.MINOR.PATCH core of *version*.

    The VS Code Marketplace requires extension/package.json's "version"
    field to be a plain three-part semver — vsce hard-rejects a hyphenated
    version like "1.2.3-beta.1" outright, even with --pre-release (that
    flag marks the channel; the version field itself must stay plain).
    pub.dev has no such restriction, so the .vsix filename and the
    publish-flag decision keep using the full pub.dev version, while only
    the value written into package.json is stripped down to its numeric
    core before reaching vsce.
    """
    return version.split("-", 1)[0]


# Base offset band added to PATCH for every prerelease extension version.
# Large enough that it will never collide with a genuine stable PATCH
# release (this project's patch history tops out in the low teens), small
# enough to stay legible. See extension_version_for() for why this exists.
_PRERELEASE_PATCH_OFFSET = 500

# Second band, added on top of _PRERELEASE_PATCH_OFFSET, derived from the
# prerelease CHANNEL name (the "beta" in "beta.1") so different channels of
# the same base version ("16.0.0-beta.1" vs "16.0.0-rc.1") don't collide —
# the version prompt accepts any channel tag, not just "beta". Bounded to
# keep the final number readable; collisions between two DIFFERENT channel
# names are reduced, not mathematically ruled out (this is a hash band, not
# a registry of issued versions).
_PRERELEASE_CHANNEL_BAND = 1000

_PRERELEASE_ITERATION_RE = _re.compile(r"(\d+)\s*$")


def extension_version_for(version: str) -> str:
    """Return the extension/package.json version to publish for *version*.

    A stable *version* passes through strip_prerelease_suffix() unchanged.
    A prerelease *version* (e.g. "16.0.0-beta.1") gets PATCH offset by
    _PRERELEASE_PATCH_OFFSET, plus a channel-derived band from the text
    before the trailing number ("beta" in "beta.1"), plus the trailing
    iteration number itself — producing e.g. "16.1.913" for "beta.1" and
    a different value for "rc.1" of the same base version.

    The MINOR is forced to odd for prerelease versions. VS Code uses an
    odd/even minor convention to distinguish pre-release from stable: even
    minor = stable, odd minor = pre-release. Without an odd minor, the
    "Switch to Pre-Release Version" button in VS Code fails with
    ``net::ERR_FAILED`` because it can't find a version on the pre-release
    channel.

    Without the PATCH offset, every prerelease iteration of the same pub.dev
    base version strips down to the identical extension version ("16.0.0"),
    and the second publish collides with the first at the Marketplace/Open
    VSX level — pub.dev's hyphenated prerelease identifier has no equivalent
    in the extension version field, so a distinct signal has to be
    manufactured from the numbers that ARE available.
    """
    base = strip_prerelease_suffix(version)
    if not is_prerelease_version(version):
        return base
    suffix = version.split("-", 1)[1]
    match = _PRERELEASE_ITERATION_RE.search(suffix)
    iteration = int(match.group(1)) if match else 1
    channel = suffix[: match.start()].rstrip(".") if match else suffix
    channel_band = sum(ord(c) for c in channel) % _PRERELEASE_CHANNEL_BAND
    major, minor, patch = base.split(".")
    # VS Code requires an odd minor version for pre-release extensions;
    # even minor = stable. Force odd so "Switch to Pre-Release" works.
    prerelease_minor = int(minor) | 1
    new_patch = (
        int(patch) + _PRERELEASE_PATCH_OFFSET + channel_band + iteration
    )
    return f"{major}.{prerelease_minor}.{new_patch}"


# =============================================================================
# OUTPUT LEVEL
# =============================================================================
# Controls verbosity of print functions. Set once at startup by the
# entry point script. Modules never parse CLI args themselves.
#
# Usage in entry point:
#   from scripts.modules._utils import OutputLevel, set_output_level
#   set_output_level(OutputLevel.WARNINGS_ONLY)


class OutputLevel(Enum):
    """Controls which messages are printed.

    SILENT:        No output at all (data-only mode).
    WARNINGS_ONLY: Only warnings and errors.
    NORMAL:        Warnings, errors, success, info, stats.
    VERBOSE:       Everything including section headers and details.
    """

    SILENT = 0
    WARNINGS_ONLY = 1
    NORMAL = 2
    VERBOSE = 3


_output_level: OutputLevel = OutputLevel.VERBOSE


def set_output_level(level: OutputLevel) -> None:
    """Set the global output verbosity level.

    Call this once from the entry point script before any audit
    or publish functions run. Modules respect this setting via
    the print_* functions below.
    """
    global _output_level
    _output_level = level


def get_output_level() -> OutputLevel:
    """Get the current output verbosity level."""
    return _output_level


# =============================================================================
# FILE LOGGING & NON-INTERACTIVE MODE
# =============================================================================
# When a log file is set, every print_* call also writes a plain-text
# (ANSI-stripped) copy to the log. Non-interactive mode auto-answers
# prompts with their defaults so the script can run unattended.

# Regex to strip ANSI escape sequences for plain-text log output
_ANSI_RE = _re.compile(r"\x1b\[[0-9;]*m")

# File handle for the optional log file; None = logging disabled
_log_file: io.TextIOWrapper | None = None

# Non-interactive flag — set when stdin is not a TTY or explicitly requested
_non_interactive: bool = False


def set_log_file(path: Path | str, *, append: bool = False) -> None:
    """Open a UTF-8 log file for tee-style output.

    All print_* output is mirrored to this file with ANSI codes
    stripped. Call close_log_file() at exit to flush and close.
    Prints a warning and continues without logging if the path
    is unwritable (e.g. missing parent directory, read-only).

    Args:
        path: File path for the log.
        append: If True, append to existing file instead of overwriting.
    """
    global _log_file
    # Close any previously opened log file
    close_log_file()
    file_mode = "a" if append else "w"
    try:
        _log_file = open(path, file_mode, encoding="utf-8", errors="replace")
    except OSError as exc:
        # Don't crash the whole publish pipeline for a bad log path
        print(f"  WARNING: Cannot open log file '{path}': {exc}")
        print("  Continuing without file logging.")
        return
    log_write(f"--- saropa_lints publish log started {datetime.now().isoformat()} ---")


def close_log_file() -> None:
    """Flush and close the log file if one is open."""
    global _log_file
    if _log_file is not None:
        try:
            log_write(f"--- log ended {datetime.now().isoformat()} ---")
            _log_file.close()
        except OSError:
            pass
        _log_file = None


def log_write(msg: str) -> None:
    """Write one line to the log file (ANSI codes stripped).

    Public API for other modules (e.g. _timing.py) that need
    to log plain-text output alongside the print_* functions.
    Defensive ANSI stripping covers future callers that may pass
    colorized strings; current callers pass plain text.
    """
    if _log_file is None:
        return
    try:
        clean = _ANSI_RE.sub("", msg)
        _log_file.write(clean + "\n")
    except OSError:
        pass


def set_non_interactive(enabled: bool) -> None:
    """Enable or disable non-interactive mode.

    When enabled, safe_input() returns the default value without
    waiting for user input, and prompt_step_failure() auto-retries
    (up to the auto-retry limit) then auto-aborts.
    """
    global _non_interactive
    _non_interactive = enabled


def is_non_interactive() -> bool:
    """Check whether the session is running non-interactively."""
    return _non_interactive


# =============================================================================
# AUTO-RETRY
# =============================================================================
# Maximum number of automatic retries for failed steps before aborting.
# Set via set_auto_retry_limit(); checked in prompt_step_failure().

_auto_retry_limit: int = 0
_auto_retry_counts: dict[str, int] = {}


def set_auto_retry_limit(limit: int) -> None:
    """Set the maximum number of auto-retries for failed pipeline steps.

    When > 0, prompt_step_failure() will auto-retry up to this many
    times per step before aborting (in non-interactive mode) or
    falling through to the interactive menu (in interactive mode).
    """
    global _auto_retry_limit
    _auto_retry_limit = max(0, limit)


def get_auto_retry_limit() -> int:
    """Get the current auto-retry limit."""
    return _auto_retry_limit


def safe_input(prompt: str, default: str = "") -> str:
    """Read user input, or return default in non-interactive mode.

    In non-interactive mode, logs the prompt and default to the log
    file and returns the default without blocking on stdin.
    """
    if _non_interactive:
        log_write(f"[non-interactive] {prompt} -> {default!r}")
        print(f"{prompt}{default}  [auto]")
        return default
    try:
        return input(prompt)
    except (EOFError, KeyboardInterrupt):
        # stdin closed or interrupted — behave like non-interactive
        print()
        return default


# =============================================================================
# COLOR AND PRINTING
# =============================================================================
# Unified ANSI color codes used by all scripts.
#
# NOTE: The Saropa ASCII logo (show_saropa_logo) is defined here but
# must ONLY be called by entry point scripts (e.g. publish.py,
# improve_dx_messages.py). Module scripts must NEVER call it.


class Color(Enum):
    """ANSI color codes for terminal output."""

    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"
    DIM = "\033[2m"
    BOLD = "\033[1m"
    BLUE = "\033[94m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows (CMD and PowerShell).

    On Windows, this:
      1. Enables virtual terminal processing for the stdout handle
      2. Sets the TERM environment variable if not already set
      3. Reconfigures stdout to use UTF-8 encoding

    On macOS/Linux this is a no-op (ANSI is natively supported).
    """
    if sys.platform != "win32":
        return

    try:
        import ctypes
        from ctypes import wintypes

        kernel32 = ctypes.windll.kernel32
        STD_OUTPUT_HANDLE = -11
        ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
        mode = wintypes.DWORD()
        kernel32.GetConsoleMode(handle, ctypes.byref(mode))
        kernel32.SetConsoleMode(
            handle, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING
        )
    except Exception:
        pass

    if "TERM" not in os.environ:
        os.environ["TERM"] = "xterm-256color"

    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art with copyright."""
    logo = """
\033[38;5;208m                               ....\033[0m
\033[38;5;208m                       `-+shdmNMMMMNmdhs+-\033[0m
\033[38;5;209m                    -odMMMNyo/-..````.++:+o+/-\033[0m
\033[38;5;215m                 `/dMMMMMM/`          ``````````\033[0m
\033[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-\033[0m
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh\\\033[0m
\033[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+\033[0m
\033[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo\033[0m
\033[38;5;118m              m                        .+NMMMMMMMMMN\033[0m
\033[38;5;123m              m+                         :MMMMMMMMMm\033[0m
\033[38;5;87m              /N:                        :MMMMMMMMM/\033[0m
\033[38;5;51m               oNs.                    `+NMMMMMMMMo\033[0m
\033[38;5;45m                :dNy/.              ./smMMMMMMMMm:\033[0m
\033[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/\033[0m
\033[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-\033[0m
\033[38;5;57m                       `-+shdNNMMMMNNdhs+-\033[0m
\033[38;5;57m                               ````\033[0m
"""
    print(logo)
    current_year = datetime.now().year
    copyright_year = f"2024-{current_year}" if current_year > 2024 else "2024"
    print(f"\033[38;5;195m(c) {copyright_year} Saropa. All rights reserved.\033[0m")
    print("\033[38;5;117mhttps://saropa.com\033[0m")
    print()
    # Mirror the logo text to the log file (ANSI stripped)
    log_write("Saropa")
    log_write(f"(c) {copyright_year} Saropa. All rights reserved.")
    log_write("https://saropa.com")


# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes.

    Respects the global output level: suppressed in SILENT mode.
    Also mirrors the line (ANSI-stripped) to the log file if one is open.
    """
    if _output_level == OutputLevel.SILENT:
        return
    formatted = f"{color.value}{message}{Color.RESET.value}"
    print(formatted)
    log_write(message)


def print_header(text: str) -> None:
    """Print a major section header. Shown at NORMAL and above."""
    if _output_level.value < OutputLevel.NORMAL.value:
        return
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_section(text: str) -> None:
    """Print a section header. Shown at NORMAL and above."""
    if _output_level.value < OutputLevel.NORMAL.value:
        return
    print()
    print_colored(f"{'─' * 70}", Color.DIM)
    print_colored(f"  {text}", Color.BOLD)
    print_colored(f"{'─' * 70}", Color.DIM)
    print()


def print_subheader(text: str) -> None:
    """Print a subsection header. Shown at VERBOSE only."""
    if _output_level.value < OutputLevel.VERBOSE.value:
        return
    print()
    print_colored(f"▶ {text}", Color.BLUE)
    print()


def print_success(message: str) -> None:
    """Print a success message. Shown at NORMAL and above."""
    if _output_level.value < OutputLevel.NORMAL.value:
        return
    print_colored(f"  ✓ {message}", Color.GREEN)


def print_warning(message: str) -> None:
    """Print a warning message. Shown at WARNINGS_ONLY and above."""
    if _output_level == OutputLevel.SILENT:
        return
    print_colored(f"  ⚠ {message}", Color.YELLOW)


def print_error(message: str) -> None:
    """Print an error message. Always shown (except SILENT)."""
    if _output_level == OutputLevel.SILENT:
        return
    print_colored(f"  ✗ {message}", Color.RED)


def print_info(message: str) -> None:
    """Print an info message. Shown at NORMAL and above."""
    if _output_level.value < OutputLevel.NORMAL.value:
        return
    print_colored(f"  ℹ {message}", Color.CYAN)


def print_stat(
    label: str, value: int | str, color: Color = Color.WHITE
) -> None:
    """Print a statistic. Shown at VERBOSE only."""
    if _output_level.value < OutputLevel.VERBOSE.value:
        return
    print(
        f"    {Color.DIM.value}{label}:{Color.RESET.value} "
        f"{color.value}{value}{Color.RESET.value}"
    )
    log_write(f"    {label}: {value}")


def print_stat_bar(
    label: str,
    value: int,
    total: int,
    color: Color = Color.GREEN,
    width: int = 20,
) -> None:
    """Print a statistic with a visual progress bar. Shown at VERBOSE only.

    Args:
        label: The label to display (left-aligned, 20 chars).
        value: The current value.
        total: The maximum value (for percentage calculation).
        color: The bar fill color.
        width: The bar width in characters.
    """
    if _output_level.value < OutputLevel.VERBOSE.value:
        return
    pct = (value / total * 100) if total > 0 else 0
    filled = int(pct / 100 * width)
    bar = "█" * filled + "░" * (width - filled)
    print(
        f"    {label:<20} {color.value}{bar}{Color.RESET.value} "
        f"{value:>4}/{total:<4} ({pct:>5.1f}%)"
    )
    log_write(f"    {label:<20} {value:>4}/{total:<4} ({pct:>5.1f}%)")


# =============================================================================
# EXIT CODES
# =============================================================================
# Superset of exit codes from all scripts. New scripts should add
# codes here rather than defining their own enum.


class ExitCode(Enum):
    """Standard exit codes for all saropa_lints scripts."""

    SUCCESS = 0
    PREREQUISITES_FAILED = 1
    WORKING_TREE_FAILED = 2
    TEST_FAILED = 3
    ANALYSIS_FAILED = 4
    CHANGELOG_FAILED = 5
    VALIDATION_FAILED = 6
    PUBLISH_FAILED = 7
    GIT_FAILED = 8
    GITHUB_RELEASE_FAILED = 9
    USER_CANCELED = 10
    AUDIT_FAILED = 11


def exit_with_error(message: str, code: ExitCode) -> NoReturn:
    """Print an error message and exit with the given code."""
    print_error(message)
    sys.exit(code.value)


def prompt_step_failure(
    step_name: str,
    *,
    allow_ignore: bool = True,
) -> str:
    """Ask user how to proceed after a pipeline step fails.

    Provides a consistent Retry / Ignore / Abort menu across all
    publish pipeline steps so that no failure is an immediate hard
    exit. The developer can fix the issue in another terminal and
    retry, or consciously skip a non-critical gate.

    When *allow_ignore* is False (used for irreversible steps like
    git push, tag creation, and pub.dev publish), the Ignore option
    is hidden so the developer cannot accidentally skip a critical
    step. Typing 'i' in strict mode is treated as abort.

    Returns:
        'retry' | 'ignore' | 'abort'.
    """
    print_warning(f"{step_name} failed. Choose an action:")

    # Auto-retry: if a retry budget is set, use it before prompting or aborting
    if _auto_retry_limit > 0:
        used = _auto_retry_counts.get(step_name, 0)
        remaining = _auto_retry_limit - used
        if remaining > 0:
            _auto_retry_counts[step_name] = used + 1
            print_info(
                f"Auto-retrying {step_name} "
                f"({used + 1}/{_auto_retry_limit})"
            )
            return "retry"
        print_info(
            f"Auto-retry limit ({_auto_retry_limit}) exhausted for {step_name}"
        )

    # Non-interactive mode: auto-abort after retries exhausted
    if _non_interactive:
        print_info(f"Non-interactive mode: aborting after {step_name} failure")
        return "abort"

    print_colored("  [R]etry  (re-run after fixing the issue)", Color.CYAN)
    if allow_ignore:
        print_colored("  [I]gnore (continue despite the failure)", Color.CYAN)
    print_colored("  [A]bort  (stop the publish)", Color.CYAN)
    default = "a"
    prompt = "  Choice [r/i/a]: " if allow_ignore else "  Choice [r/a]: "
    raw = safe_input(prompt, default).strip().lower() or default
    if raw.startswith("r"):
        return "retry"
    if raw.startswith("i") and allow_ignore:
        return "ignore"
    return "abort"


# =============================================================================
# PLATFORM DETECTION
# =============================================================================


def is_windows() -> bool:
    """Check if running on Windows."""
    return sys.platform == "win32"


def is_macos() -> bool:
    """Check if running on macOS."""
    return sys.platform == "darwin"


def is_linux() -> bool:
    """Check if running on Linux."""
    return sys.platform.startswith("linux")


def get_shell_mode() -> bool:
    """Get the appropriate shell mode for subprocess calls.

    On Windows, we need shell=True to find .bat/.cmd executables
    (like flutter.bat) that are in PATH. On macOS/Linux, executables
    are found directly without shell.
    """
    return is_windows()


# =============================================================================
# COMMAND EXECUTION
# =============================================================================


def run_command(
    cmd: list[str],
    cwd: Path,
    description: str,
    capture_output: bool = False,
    allow_failure: bool = False,
    summarize: bool = False,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
    """Run a shell command and handle errors.

    Args:
        cmd: The command and arguments to run.
        cwd: Working directory for the command.
        description: Human-readable description for logging.
        capture_output: If True, capture stdout/stderr.
        allow_failure: If True, don't print error on non-zero exit.
        summarize: If True, capture output and show only a summary.
            On success: prints the last meaningful line.
            On failure: prints the last 10 lines of output.
            Full output is shown in --verbose mode on failure.
        env: Optional environment for the process. If None, inherits current env.

    Returns:
        The CompletedProcess result.
    """
    print_info(f"{description}...")
    # Log the command line regardless of output level
    log_write(f"      $ {' '.join(cmd)}")
    if _output_level.value >= OutputLevel.VERBOSE.value:
        print_colored(f"      $ {' '.join(cmd)}", Color.WHITE)

    use_shell = get_shell_mode()

    # summarize mode always captures output
    should_capture = capture_output or summarize

    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=should_capture,
        text=True,
        shell=use_shell,
        env=env,
        # Force UTF-8 to avoid UnicodeDecodeError on Windows,
        # where the default cp1252 can't handle all dart output bytes
        encoding="utf-8",
        errors="replace",
    )

    if result.returncode != 0 and not allow_failure:
        if should_capture:
            _print_failure_output(result, summarize)
        print_error(f"{description} failed (exit code {result.returncode})")
        return result

    if result.returncode == 0:
        if summarize and result.stdout:
            _print_summary_line(result.stdout)
        print_success(f"{description} completed")
    return result


def _print_summary_line(stdout: str) -> None:
    """Extract and print a one-line summary from command output."""
    lines = stdout.strip().splitlines()
    if not lines:
        return

    # Look for common summary patterns from the end
    for line in reversed(lines):
        stripped = line.strip()
        if not stripped:
            continue
        # dart test: "+1543: All tests passed!"
        if "All tests passed" in stripped:
            print_colored(f"      {stripped}", Color.GREEN)
            return
        # dart analyze: "No issues found!" or "N issues found."
        if "issues found" in stripped or "No issues found" in stripped:
            print_colored(f"      {stripped}", Color.CYAN)
            return
    # Fallback: last non-empty line
    for line in reversed(lines):
        stripped = line.strip()
        if stripped:
            print_colored(f"      {stripped}", Color.CYAN)
            return


def _print_failure_output(
    result: subprocess.CompletedProcess,
    summarize: bool,
) -> None:
    """Print output from a failed command, respecting summarize mode."""
    combined = (result.stdout or "") + (result.stderr or "")
    if not combined.strip():
        return

    if not summarize or _output_level.value >= OutputLevel.VERBOSE.value:
        # Full output in verbose mode or non-summarized mode
        print(combined)
        return

    # Summarized failure: show last 10 meaningful lines
    lines = combined.strip().splitlines()
    tail = lines[-10:] if len(lines) > 10 else lines
    if len(lines) > 10:
        print_colored(
            f"      ... ({len(lines) - 10} lines omitted, "
            f"use --verbose for full output)",
            Color.YELLOW,
        )
    for line in tail:
        print(f"      {line}")


def command_exists(cmd: str) -> bool:
    """Check if a command exists in PATH."""
    return shutil.which(cmd) is not None


def clear_flutter_lock() -> None:
    """Remove stale Flutter startup lock if present.

    Flutter uses a lockfile at <sdk>/bin/cache/lockfile to prevent
    concurrent SDK operations. If a previous process crashed or was
    killed, this lock can remain and cause subsequent commands to hang
    with "Waiting for another flutter command to release the startup
    lock..."

    This function attempts to remove the lockfile. If the lock is
    actively held by another process, the deletion may fail (Windows)
    or the active process will re-create it (Unix).
    """
    flutter_path = shutil.which("flutter")
    if not flutter_path:
        return

    sdk_bin = Path(flutter_path).resolve().parent
    lockfile = sdk_bin / "cache" / "lockfile"

    if not lockfile.exists():
        return

    print_warning("Found Flutter startup lock file (stale process?)")
    try:
        lockfile.unlink()
        print_success("Cleared stale Flutter lock file")
    except OSError:
        print_warning(
            "Could not clear lock file. "
            "Another Flutter process may be running."
        )


# =============================================================================
# PROJECT DISCOVERY
# =============================================================================
# These functions locate key project paths relative to the scripts/ directory.


def get_project_dir() -> Path:
    """Return the project root directory (parent of scripts/).

    This assumes the script is in scripts/ or scripts/modules/.
    """
    # Navigate up from modules/ to scripts/ to project root
    this_dir = Path(__file__).resolve().parent
    if this_dir.name == "modules":
        return this_dir.parent.parent
    return this_dir.parent


def get_rules_dir() -> Path:
    """Return the lib/src/rules/ directory."""
    return get_project_dir() / "lib" / "src" / "rules"


def get_tiers_path() -> Path:
    """Return the lib/src/tiers.dart file path."""
    return get_project_dir() / "lib" / "src" / "tiers.dart"
