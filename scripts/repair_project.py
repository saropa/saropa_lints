#!/usr/bin/env python3
"""
Repair the saropa_lints project after filesystem or cache corruption.

Scans the entire project tree for corrupted NTFS directories (errno
1392), removes them with escalating strategies (rmdir, robocopy
mirror, chkdsk guidance), cleans stale Dart caches, restores missing
files from git, and re-resolves all dependencies.

Steps:
  1. Kill Dart processes that hold file locks
  2. Detect and remove corrupted NTFS directories
  3. Clean Dart caches (.dart_tool, pubspec.lock, build/)
  4. Restore deleted/missing files from git
  5. Restore dependencies (dart pub get)
  6. Verify project integrity

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
Usage:     python scripts/repair_project.py [--verbose | --silent]
           For best results, close IDEs and run from an ELEVATED terminal.
"""

from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
from pathlib import Path

# Ensure project root is on sys.path so `scripts.modules` resolves
_SCRIPT_DIR = Path(__file__).resolve().parent
_PROJECT_DIR = _SCRIPT_DIR.parent
sys.path.insert(0, str(_PROJECT_DIR))

from scripts.modules._utils import (
    Color,
    ExitCode,
    OutputLevel,
    enable_ansi_support,
    exit_with_error,
    get_project_dir,
    is_windows,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_section,
    print_success,
    print_warning,
    run_command,
    set_output_level,
    show_saropa_logo,
)
from scripts.modules._timing import StepTimer


# =============================================================================
# CONSTANTS
# =============================================================================

# Directories that MUST be readable after a clean — verification targets
_KEY_DIRS = [
    Path("lib"),
    Path("lib") / "src" / "rules",
    Path("lib") / "src" / "fixes",
    Path("test"),
    Path("example") / "lib",
]

# Dart processes that hold file locks on Windows
_DART_PROCESS_NAMES = [
    "dart",
    "dart_language_server",
    "analysis_server",
]


# =============================================================================
# SIGNAL HANDLING
# =============================================================================

def _setup_signals() -> None:
    """Log a clean message on Ctrl+C instead of a stack trace."""
    def _handler(signum, frame):
        print()
        print_warning("Interrupted by user (Ctrl+C)")
        sys.exit(130)

    signal.signal(signal.SIGINT, _handler)
    # SIGTERM doesn't exist on Windows but signal.signal silently ignores it
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, _handler)


# =============================================================================
# DIRECTORY CORRUPTION
# =============================================================================

def _scan_for_corruption(root: Path) -> list[Path]:
    """Walk the project tree and find directories that can't be enumerated.

    A corrupted directory exists on disk but raises OSError when listed.
    This catches errno 1392 (corrupted and unreadable) and similar NTFS
    damage without crashing the script.
    """
    corrupted: list[Path] = []
    dirs_to_check: list[Path] = [root]
    visited: set[Path] = set()

    while dirs_to_check:
        parent = dirs_to_check.pop()
        if parent in visited:
            continue
        visited.add(parent)

        try:
            entries = list(parent.iterdir())
        except OSError:
            # This parent itself is corrupted — can't enumerate its children
            corrupted.append(parent)
            continue

        for entry in entries:
            if not entry.is_dir():
                continue
            # Skip .git internals — pack files, loose objects, etc.
            if entry.name == ".git":
                continue
            dirs_to_check.append(entry)

    return corrupted


def _force_remove_corrupted(path: Path) -> bool:
    """Aggressively remove a corrupted directory.

    Tries multiple strategies in escalating order because Python's
    pathlib and shutil cannot handle NTFS corruption (errno 1392):

    1. cmd.exe rmdir /s /q — bypasses Python's directory enumeration
    2. robocopy empty-dir mirror — overwrites the directory metadata
       with an empty listing, which can fix entries the filesystem
       can't enumerate normally
    3. Reports failure with chkdsk guidance if nothing worked
    """
    if not path.exists():
        return True

    rel = _rel(path)

    # Strategy 1: cmd.exe rmdir — handles some corruption Python can't
    if is_windows():
        result = subprocess.run(
            ["cmd", "/c", "rmdir", "/s", "/q", str(path)],
            capture_output=True, check=False,
        )
        if result.returncode == 0 and not path.exists():
            print_success(f"Removed corrupted dir (rmdir): {rel}")
            return True

    # Strategy 2: robocopy empty-dir trick (Windows only)
    # Mirrors an empty folder over the target, which can repair NTFS
    # directory entries that rmdir and Remove-Item both choke on
    if is_windows():
        empty_dir = Path(os.environ.get("TEMP", "")) / "_saropa_empty_mirror"
        empty_dir.mkdir(parents=True, exist_ok=True)
        try:
            result = subprocess.run(
                [
                    "robocopy", str(empty_dir), str(path),
                    "/MIR",     # mirror (delete everything in target)
                    "/R:1",     # 1 retry
                    "/W:1",     # 1 second wait
                    "/NFL",     # no file listing
                    "/NDL",     # no directory listing
                    "/NP",      # no progress
                ],
                capture_output=True, check=False,
            )
            # Robocopy exit codes 0-7 are success (bits indicate what changed)
            if result.returncode <= 7:
                # Robocopy emptied it — remove the now-empty shell
                subprocess.run(
                    ["cmd", "/c", "rmdir", "/s", "/q", str(path)],
                    capture_output=True, check=False,
                )
                if not path.exists():
                    print_success(f"Removed corrupted dir (robocopy mirror): {rel}")
                    return True
        finally:
            try:
                empty_dir.rmdir()
            except Exception:
                pass

    # Strategy 3 (non-Windows fallback): rm -rf
    if not is_windows():
        result = subprocess.run(
            ["rm", "-rf", str(path)],
            capture_output=True, check=False,
        )
        if result.returncode == 0 and not path.exists():
            print_success(f"Removed corrupted dir (rm -rf): {rel}")
            return True

    # All strategies failed — filesystem-level repair needed
    print_error(f"Cannot remove corrupted dir: {rel}")
    print_warning("  This directory has filesystem-level corruption (errno 1392).")
    print_warning("  Run 'chkdsk D: /f' from an elevated prompt, then re-run.")
    return False


def _rmtree_native(path: Path) -> bool:
    """Delete a directory using the native OS command.

    Python's shutil.rmtree is single-threaded file-by-file deletion —
    the native OS command is orders of magnitude faster on large dirs.
    """
    if is_windows():
        result = subprocess.run(
            ["cmd", "/c", "rmdir", "/s", "/q", str(path)],
            capture_output=True, check=False,
        )
    else:
        result = subprocess.run(
            ["rm", "-rf", str(path)],
            capture_output=True, check=False,
        )
    return result.returncode == 0


def _remove(path: Path, description: str | None = None) -> bool:
    """Remove a file or directory. Returns True if something was removed."""
    if not path.exists():
        return False
    try:
        if path.is_file():
            path.unlink()
        elif not _rmtree_native(path):
            # Native command failed — try Python as last resort
            import shutil
            shutil.rmtree(path)

        if description:
            print_success(f"Removed: {description}")
        return True
    except PermissionError as e:
        print_warning(f"Permission denied: {path} — {e}")
    except OSError as e:
        print_warning(f"OS error removing {path}: {e}")
    except Exception as e:
        print_warning(f"Could not remove {path}: {e}")
    return False


# =============================================================================
# PROCESS MANAGEMENT
# =============================================================================

def _kill_dart_processes() -> None:
    """Kill Dart analyzer and tooling processes that hold file locks.

    Uses taskkill on Windows; pkill on Unix. Failures are silently
    ignored — the process may not be running, which is fine.
    """
    for name in _DART_PROCESS_NAMES:
        try:
            if is_windows():
                subprocess.run(
                    ["taskkill", "/F", "/IM", f"{name}.exe"],
                    capture_output=True, check=False,
                )
            else:
                subprocess.run(
                    ["pkill", "-9", name],
                    capture_output=True, check=False,
                )
        except Exception:
            pass


# =============================================================================
# HELPERS
# =============================================================================

def _rel(path: Path) -> Path:
    """Return path relative to project root for display."""
    try:
        return path.relative_to(_PROJECT_DIR)
    except ValueError:
        return path


# =============================================================================
# STEP IMPLEMENTATIONS
# =============================================================================

def step_kill_processes() -> None:
    """Kill Dart processes that hold file locks on the project tree."""
    print_section("Terminating Dart Processes")
    print_warning("Terminating Dart analyzer and tooling processes.")
    print_warning("  This WILL disrupt the Dart extension in VS Code / IntelliJ.")
    _kill_dart_processes()
    print_success("Dart processes terminated.")


def step_fix_corruption() -> bool:
    """Scan for and fix corrupted directories.

    Returns True if all corruption was fixed (or none was found).
    Returns False if unfixable corruption remains — caller should abort.
    """
    print_section("Scanning for Filesystem Corruption")
    print_info(f"Scanning {_PROJECT_DIR} for corrupted directories...")

    corrupted = _scan_for_corruption(_PROJECT_DIR)

    if not corrupted:
        print_success("No filesystem corruption found.")
        return True

    print_warning(f"Found {len(corrupted)} corrupted directory(ies):")
    for p in corrupted:
        print_warning(f"  - {_rel(p)}")

    # Attempt to fix each one with escalating strategies
    unfixed: list[Path] = []
    for p in corrupted:
        if not _force_remove_corrupted(p):
            unfixed.append(p)

    if unfixed:
        print_error(f"{len(unfixed)} corrupted dir(s) could not be removed.")
        print_warning("Steps to fix:")
        print_warning("  1. Close all IDEs and terminals using this project")
        print_warning("  2. Open an elevated PowerShell (Run as Administrator)")
        print_warning("  3. Run: chkdsk D: /f")
        print_warning("  4. Re-run this script after chkdsk completes")
        return False

    print_success("All corruption fixed.")
    return True


def step_clean_caches() -> None:
    """Clean Dart caches across all package directories.

    Removes .dart_tool, pubspec.lock, and build/ so that
    dart pub get fully re-resolves and rebuilds everything.
    """
    print_section("Cleaning Dart Caches")

    # Find and remove all .dart_tool directories in the project tree
    dart_tool_dirs = sorted(_PROJECT_DIR.rglob(".dart_tool"))
    if dart_tool_dirs:
        for dt in dart_tool_dirs:
            _remove(dt, f".dart_tool ({_rel(dt)})")
    else:
        print_info("No .dart_tool directories found.")

    # Remove pubspec.lock so deps are fully re-resolved
    _remove(_PROJECT_DIR / "pubspec.lock", "pubspec.lock")
    _remove(_PROJECT_DIR / "example" / "pubspec.lock", "example/pubspec.lock")

    # Remove build output directories
    _remove(_PROJECT_DIR / "build", "build/")
    _remove(_PROJECT_DIR / "example" / "build", "example/build/")

    print_success("Caches cleaned.")


def step_restore_git() -> None:
    """Restore deleted/missing files from git.

    Finds all unstaged deletions (files that git tracks but are
    missing from the working tree) and restores them with
    git checkout. This recovers files lost to corruption or
    accidental deletion.
    """
    print_section("Restoring Files from Git")

    # Find unstaged deletions in porcelain format (" D path")
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True, text=True, check=False,
        cwd=_PROJECT_DIR,
    )
    if result.returncode != 0:
        print_warning("Could not read git status — skipping file restoration.")
        return

    deleted_files: list[str] = []
    for line in result.stdout.splitlines():
        # " D path" = unstaged deletion (space + D + space + path)
        if line.startswith(" D "):
            deleted_files.append(line[3:].strip())

    if not deleted_files:
        print_success("No deleted files to restore.")
        return

    print_info(f"Found {len(deleted_files)} deleted file(s) to restore:")
    for f in deleted_files:
        print_info(f"  - {f}")

    # Restore all deleted files in one git checkout call
    run_command(
        ["git", "checkout", "--"] + deleted_files,
        cwd=_PROJECT_DIR,
        description=f"Restoring {len(deleted_files)} file(s) from git",
        allow_failure=True,
    )


def step_restore_deps() -> None:
    """Restore project dependencies with dart pub get.

    Runs pub get for the root package and the example package
    (if it has a pubspec.yaml). Uses --no-precompile to skip
    snapshot compilation — faster, and the snapshots will be
    rebuilt on first use.
    """
    print_section("Restoring Dependencies")

    # Root package
    run_command(
        ["dart", "pub", "get", "--no-precompile"],
        cwd=_PROJECT_DIR,
        description="Root package: dart pub get",
    )

    # Example package (if it exists)
    example_pubspec = _PROJECT_DIR / "example" / "pubspec.yaml"
    if example_pubspec.exists():
        run_command(
            ["dart", "pub", "get", "--no-precompile"],
            cwd=_PROJECT_DIR / "example",
            description="Example package: dart pub get",
            allow_failure=True,
        )


def step_verify() -> bool:
    """Verify project integrity after the clean.

    Checks that key directories exist and are readable (not
    corrupted), and that git shows no remaining unstaged deletions.
    Returns True if all checks pass.
    """
    print_section("Verifying Project Integrity")

    errors: list[str] = []

    # Check key directories exist and can be enumerated
    for rel_dir in _KEY_DIRS:
        full = _PROJECT_DIR / rel_dir
        if not full.exists():
            errors.append(f"Missing: {rel_dir}")
            continue
        try:
            # Attempt to list — this triggers corruption errors
            list(full.iterdir())
            print_success(f"Readable: {rel_dir}")
        except OSError as e:
            errors.append(f"Still corrupted: {rel_dir} ({e})")

    # Check for remaining unstaged deletions in git
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True, text=True, check=False,
        cwd=_PROJECT_DIR,
    )
    if result.returncode == 0:
        deletions = [
            l for l in result.stdout.splitlines() if l.startswith(" D ")
        ]
        if deletions:
            errors.append(
                f"{len(deletions)} file(s) still show as deleted in git"
            )

    if errors:
        print_error(f"Verification found {len(errors)} issue(s):")
        for e in errors:
            print_error(f"  - {e}")
        return False

    print_success("Project integrity verified.")
    return True


# =============================================================================
# CLI
# =============================================================================

def _parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Repair saropa_lints after filesystem or cache corruption.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "For best results, close IDEs and run from an elevated terminal.\n"
            "If filesystem corruption cannot be auto-fixed, run:\n"
            "  chkdsk D: /f\n"
            "from an elevated prompt first."
        ),
    )
    verbosity = parser.add_mutually_exclusive_group()
    verbosity.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show detailed output including shell commands.",
    )
    verbosity.add_argument(
        "--silent", "-s",
        action="store_true",
        help="Suppress all output except errors.",
    )
    return parser.parse_args()


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Entry point: run the full deep-clean pipeline."""
    args = _parse_args()

    # Set output verbosity before any printing
    if args.silent:
        set_output_level(OutputLevel.SILENT)
    elif args.verbose:
        set_output_level(OutputLevel.VERBOSE)
    else:
        set_output_level(OutputLevel.NORMAL)

    enable_ansi_support()
    show_saropa_logo()
    _setup_signals()
    os.chdir(_PROJECT_DIR)

    print_header("Repair Project")
    print_info(f"Project: {_PROJECT_DIR}")

    timer = StepTimer()

    # Step 1: Kill processes holding file locks
    with timer.step("Kill Dart processes"):
        step_kill_processes()

    # Step 2: Scan for and fix filesystem corruption
    with timer.step("Fix corruption"):
        all_clear = step_fix_corruption()
        if not all_clear:
            exit_with_error(
                "Cannot proceed until filesystem corruption is repaired.",
                ExitCode.PREREQUISITES_FAILED,
            )

    # Step 3: Clean Dart caches
    with timer.step("Clean caches"):
        step_clean_caches()

    # Step 4: Restore deleted files from git
    with timer.step("Restore from git"):
        step_restore_git()

    # Step 5: Restore dependencies
    with timer.step("Restore dependencies"):
        step_restore_deps()

    # Step 6: Verify project integrity
    with timer.step("Verify integrity"):
        verified = step_verify()

    # Timing summary
    timer.print_summary()

    if not verified:
        print_error("Deep clean finished with verification failures.")
        return ExitCode.VALIDATION_FAILED.value

    print()
    print_colored("=" * 60, Color.GREEN)
    print_colored("  PROJECT REPAIR COMPLETE", Color.GREEN)
    print_colored("=" * 60, Color.GREEN)
    print()

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
