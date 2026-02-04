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

import os
import shutil
import subprocess
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import NoReturn


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
# COLOR AND PRINTING
# =============================================================================
# Unified ANSI color codes used by all scripts.
#
# NOTE: The Saropa ASCII logo (show_saropa_logo) is defined here but
# must ONLY be called by entry point scripts (e.g. publish_to_pubdev.py,
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
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/\033[0m
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


# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes.

    Respects the global output level: suppressed in SILENT mode.
    """
    if _output_level == OutputLevel.SILENT:
        return
    print(f"{color.value}{message}{Color.RESET.value}")


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
    USER_CANCELLED = 10
    AUDIT_FAILED = 11


def exit_with_error(message: str, code: ExitCode) -> NoReturn:
    """Print an error message and exit with the given code."""
    print_error(message)
    sys.exit(code.value)


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
) -> subprocess.CompletedProcess:
    """Run a shell command and handle errors.

    Args:
        cmd: The command and arguments to run.
        cwd: Working directory for the command.
        description: Human-readable description for logging.
        capture_output: If True, capture stdout/stderr.
        allow_failure: If True, don't print error on non-zero exit.

    Returns:
        The CompletedProcess result.
    """
    print_info(f"{description}...")
    print_colored(f"      $ {' '.join(cmd)}", Color.WHITE)

    use_shell = get_shell_mode()

    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=capture_output,
        text=True,
        shell=use_shell,
    )

    if result.returncode != 0 and not allow_failure:
        if capture_output:
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(result.stderr)
        print_error(f"{description} failed (exit code {result.returncode})")
        return result

    print_success(f"{description} completed")
    return result


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
