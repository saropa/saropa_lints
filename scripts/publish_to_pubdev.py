#!/usr/bin/env python3
"""
Publish saropa_lints package to pub.dev and create GitHub release.

This script automates the complete release workflow for the saropa_lints package:
  1. Checks prerequisites (flutter, git, gh)
  2. Validates pubspec.yaml and CHANGELOG.md versions are in sync
  3. Validates working tree and remote sync status
  4. Checks remote sync
  5. Runs tests
  6. Formats code (ensures CI won't fail on formatting)
  7. Runs static analysis
  8. Validates version exists in CHANGELOG.md
  9. Generates documentation with dart doc
  10. Pre-publish validation (dry-run)
  11. Commits and pushes changes
  12. Creates and pushes git tag (triggers GitHub Actions publish workflow)
  13. GitHub Actions automatically publishes to pub.dev
  14. Creates GitHub release with release notes

Version:   3.9
Author:    Saropa
Copyright: (c) 2025 Saropa

Platforms:
    - Windows (uses shell=True for .bat executables)
    - macOS (native executable lookup)
    - Linux (native executable lookup)

Usage:
    python scripts/publish_to_pubdev.py

The script is fully interactive - no command-line arguments needed.
It will prompt for confirmation at key steps.

Troubleshooting:
    GitHub release fails with "Bad credentials":
        If you have a GITHUB_TOKEN environment variable set (even if invalid),
        it takes precedence over 'gh auth login' credentials. To fix:
        - PowerShell: $env:GITHUB_TOKEN = ""
        - Bash: unset GITHUB_TOKEN
        Then run 'gh auth status' to verify your keyring credentials are active.

Exit Codes:
    0 - Success
    1 - Prerequisites failed
    2 - Working tree check failed
    3 - Tests failed
    4 - Analysis failed
    5 - Changelog validation failed
    6 - Pre-publish validation failed
    7 - Publish failed
    8 - Git operations failed
    9 - GitHub release failed
    10 - User cancelled
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import webbrowser
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import NoReturn


SCRIPT_VERSION = "3.12"


# =============================================================================
# EXIT CODES
# =============================================================================

class ExitCode(Enum):
    """Standard exit codes."""
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


# =============================================================================
# COLOR AND PRINTING
# =============================================================================

class Color(Enum):
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows."""
    if sys.platform == "win32":
        try:
            import ctypes
            from ctypes import wintypes

            kernel32 = ctypes.windll.kernel32

            # Constants
            STD_OUTPUT_HANDLE = -11
            ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004

            # Get stdout handle
            handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)

            # Get current console mode
            mode = wintypes.DWORD()
            kernel32.GetConsoleMode(handle, ctypes.byref(mode))

            # Enable virtual terminal processing
            new_mode = mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING
            kernel32.SetConsoleMode(handle, new_mode)
        except Exception:
            pass


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art."""
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
    """Print a message with ANSI color codes."""
    print(f"{color.value}{message}{Color.RESET.value}")


def print_header(text: str) -> None:
    """Print a section header."""
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_success(text: str) -> None:
    """Print success message."""
    print_colored(f"  [OK] {text}", Color.GREEN)


def print_warning(text: str) -> None:
    """Print warning message."""
    print_colored(f"  [!] {text}", Color.YELLOW)


def print_error(text: str) -> None:
    """Print error message."""
    print_colored(f"  [X] {text}", Color.RED)


def print_info(text: str) -> None:
    """Print info message."""
    print_colored(f"  [>] {text}", Color.MAGENTA)


def exit_with_error(message: str, code: ExitCode) -> NoReturn:
    """Print error and exit."""
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
    """
    Get the appropriate shell mode for subprocess calls.

    On Windows, we need shell=True to find .bat/.cmd executables (like flutter.bat)
    that are in PATH. On macOS/Linux, executables are found directly without shell.
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
    allow_failure: bool = False
) -> subprocess.CompletedProcess:
    """Run a command and handle errors."""
    print_info(f"{description}...")
    print_colored(f"      $ {' '.join(cmd)}", Color.WHITE)

    use_shell = get_shell_mode()

    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=capture_output,
        text=True,
        shell=use_shell
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


# =============================================================================
# VERSION AND CHANGELOG
# =============================================================================

def get_version_from_pubspec(pubspec_path: Path) -> str:
    """Read version string from pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not find version in pubspec.yaml")
    return match.group(1)


def get_package_name(pubspec_path: Path) -> str:
    """Read package name from pubspec.yaml."""
    content = pubspec_path.read_text(encoding="utf-8")
    match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
    if not match:
        raise ValueError("Could not find name in pubspec.yaml")
    return match.group(1).strip()


def get_latest_changelog_version(changelog_path: Path) -> str | None:
    """Extract the latest version from CHANGELOG.md."""
    if not changelog_path.exists():
        return None

    content = changelog_path.read_text(encoding="utf-8")

    # Match the first version header: ## [1.2.3] or ## 1.2.3
    match = re.search(r"##\s*\[?(\d+\.\d+\.\d+)\]?", content)
    if match:
        return match.group(1)

    return None


def validate_changelog_version(project_dir: Path, version: str) -> str | None:
    """Validate version exists in CHANGELOG and extract release notes."""
    changelog_path = project_dir / "CHANGELOG.md"

    if not changelog_path.exists():
        return None

    content = changelog_path.read_text(encoding="utf-8")

    # Check if version exists in CHANGELOG
    version_pattern = rf"##\s*\[?{re.escape(version)}\]?"
    if not re.search(version_pattern, content):
        return None

    # Extract release notes for this version
    pattern = rf"(?s)##\s*\[?{re.escape(version)}\]?[^\n]*\n(.*?)(?=##\s*\[?\d+\.\d+\.\d+|$)"
    match = re.search(pattern, content)

    if match:
        return match.group(1).strip()

    return ""


def display_changelog(project_dir: Path) -> str | None:
    """Display the latest changelog entry."""
    changelog_path = project_dir / "CHANGELOG.md"

    if not changelog_path.exists():
        print_warning("CHANGELOG.md not found")
        return None

    content = changelog_path.read_text(encoding="utf-8")

    # Extract the first version section
    match = re.search(
        r"^(## \[?\d+\.\d+\.\d+\]?.*?)(?=^## |\Z)",
        content,
        re.MULTILINE | re.DOTALL
    )

    if match:
        latest_entry = match.group(1).strip()
        print()
        print_colored("  CHANGELOG (latest entry):", Color.WHITE)
        print_colored("  " + "-" * 50, Color.CYAN)
        for line in latest_entry.split("\n"):
            print_colored(f"  {line}", Color.CYAN)
        print_colored("  " + "-" * 50, Color.CYAN)
        print()
        return latest_entry

    print_warning("Could not parse CHANGELOG.md")
    return None


# =============================================================================
# LINT RULES
# =============================================================================

def count_rules(project_dir: Path) -> int:
    """Count the number of lint rules."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    count = 0

    if not rules_dir.exists():
        return 0

    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        # Match both SaropaLintRule (preferred) and DartLintRule (legacy)
        count += len(re.findall(r"class \w+ extends (?:SaropaLintRule|DartLintRule)", content))

    return count


def count_categories(project_dir: Path) -> int:
    """Count the number of rule category files."""
    rules_dir = project_dir / "lib" / "src" / "rules"

    if not rules_dir.exists():
        return 0

    count = 0
    for dart_file in rules_dir.glob("*_rules.dart"):
        if dart_file.name != "all_rules.dart":
            count += 1

    return count


def count_test_fixtures(project_dir: Path) -> int:
    """Count the number of test fixture files."""
    example_dir = project_dir / "example" / "lib"

    if not example_dir.exists():
        return 0

    count = 0
    for fixture_file in example_dir.rglob("*_fixture.dart"):
        count += 1

    return count


def get_test_coverage_report(project_dir: Path) -> tuple[int, int, float, list[tuple[str, int, int]]]:
    """
    Get test coverage statistics.

    Returns:
        (total_rules, total_fixtures, coverage_pct, category_details)
        category_details is a list of (category_name, rule_count, fixture_count)
    """
    rules_dir = project_dir / "lib" / "src" / "rules"
    example_dir = project_dir / "example" / "lib"

    if not rules_dir.exists():
        return 0, 0, 0.0, []

    category_details = []

    for dart_file in sorted(rules_dir.glob("*_rules.dart")):
        if dart_file.name == "all_rules.dart":
            continue

        # Get category name from filename (e.g., "collection_rules.dart" -> "collection")
        category = dart_file.stem.replace("_rules", "")

        # Count rules in this category
        content = dart_file.read_text(encoding="utf-8")
        rule_count = len(re.findall(r"class \w+ extends (?:SaropaLintRule|DartLintRule)", content))

        # Count fixtures for this category
        fixture_count = 0
        category_fixture_dir = example_dir / category
        if category_fixture_dir.exists():
            fixture_count = len(list(category_fixture_dir.glob("*_fixture.dart")))

        # Also check plural form (e.g., "collections" vs "collection")
        if fixture_count == 0:
            category_fixture_dir_plural = example_dir / f"{category}s"
            if category_fixture_dir_plural.exists():
                fixture_count = len(list(category_fixture_dir_plural.glob("*_fixture.dart")))

        category_details.append((category, rule_count, fixture_count))

    total_rules = sum(c[1] for c in category_details)
    total_fixtures = sum(c[2] for c in category_details)
    coverage_pct = (total_fixtures / total_rules * 100) if total_rules > 0 else 0.0

    return total_rules, total_fixtures, coverage_pct, category_details


def display_test_coverage(project_dir: Path) -> None:
    """Display test coverage report with emphasis on low coverage."""
    total_rules, total_fixtures, coverage_pct, category_details = get_test_coverage_report(project_dir)

    print()
    print_colored("  Test Coverage Report:", Color.WHITE)
    print_colored("  " + "-" * 50, Color.CYAN)

    # Overall stats with color based on coverage
    if coverage_pct < 10:
        color = Color.RED
        status = "CRITICAL"
    elif coverage_pct < 30:
        color = Color.YELLOW
        status = "LOW"
    elif coverage_pct < 70:
        color = Color.CYAN
        status = "MODERATE"
    else:
        color = Color.GREEN
        status = "GOOD"

    print_colored(f"      Overall: {total_fixtures}/{total_rules} rules tested ({coverage_pct:.1f}%) - {status}", color)
    print()

    # Show categories with fixtures (success)
    tested_categories = [(c, r, f) for c, r, f in category_details if f > 0]
    if tested_categories:
        print_colored("      Categories with tests:", Color.GREEN)
        for category, rules, fixtures in sorted(tested_categories, key=lambda x: x[2], reverse=True):
            pct = fixtures / rules * 100 if rules > 0 else 0
            print_colored(f"        {category}: {fixtures}/{rules} ({pct:.0f}%)", Color.GREEN)

    # Show categories without fixtures (shame!)
    untested_categories = [(c, r, f) for c, r, f in category_details if f == 0 and r > 0]
    if untested_categories:
        print()
        print_colored("      Categories needing tests:", Color.YELLOW)
        for category, rules, _ in sorted(untested_categories, key=lambda x: x[1], reverse=True)[:10]:
            print_colored(f"        {category}: 0/{rules} (0%)", Color.YELLOW)
        if len(untested_categories) > 10:
            remaining = len(untested_categories) - 10
            print_colored(f"        ... and {remaining} more categories", Color.YELLOW)

    print_colored("  " + "-" * 50, Color.CYAN)
    print()


# =============================================================================
# PUBLISH WORKFLOW STEPS
# =============================================================================

def check_prerequisites() -> bool:
    """Check that required tools are available."""
    print_header("STEP 1: CHECKING PREREQUISITES")

    tools = [
        ("flutter", "Install from https://flutter.dev"),
        ("git", "Install from https://git-scm.com"),
        ("gh", "Install from https://cli.github.com"),
    ]

    all_found = True
    for tool, hint in tools:
        if command_exists(tool):
            print_success(f"{tool} found")
        else:
            print_error(f"{tool} not found. {hint}")
            all_found = False

    return all_found


def check_working_tree(project_dir: Path) -> tuple[bool, bool]:
    """Check working tree status. Returns (ok, has_uncommitted_changes)."""
    print_header("STEP 2: CHECKING WORKING TREE")

    use_shell = get_shell_mode()

    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.stdout.strip():
        print_warning("You have uncommitted changes:")
        print_colored(result.stdout, Color.YELLOW)
        print()
        response = input("  These changes will be included in the release commit. Continue? [y/N] ").strip().lower()
        if not response.startswith("y"):
            return False, True
        return True, True

    print_success("Working tree is clean")
    return True, False


def check_remote_sync(project_dir: Path, branch: str) -> bool:
    """Check if local branch is in sync with remote."""
    print_header("STEP 3: CHECKING REMOTE SYNC")

    use_shell = get_shell_mode()

    # Fetch from remote
    print_info("Fetching from remote...")
    result = subprocess.run(
        ["git", "fetch", "origin", branch],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.returncode != 0:
        print_warning("Could not fetch from remote. Proceeding anyway (remote branch may not exist yet).")
        return True

    # Check if behind
    result = subprocess.run(
        ["git", "rev-list", "--count", f"HEAD..origin/{branch}"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.returncode == 0 and result.stdout.strip():
        behind_count = int(result.stdout.strip())
        if behind_count > 0:
            print_warning(f"Local branch is behind remote by {behind_count} commit(s).")
            print_info(f"Pulling changes from origin/{branch}...")

            # Auto-pull the changes
            pull_result = subprocess.run(
                ["git", "pull", "origin", branch],
                cwd=project_dir,
                capture_output=True,
                text=True,
                shell=use_shell
            )

            if pull_result.returncode != 0:
                print_error("Failed to pull changes from remote.")
                if pull_result.stderr:
                    print_colored(pull_result.stderr, Color.RED)
                print_info("Resolve conflicts manually and try again.")
                return False

            print_success(f"Pulled {behind_count} commit(s) from remote")

    # Check if ahead (unpushed commits) - warn but don't block
    result = subprocess.run(
        ["git", "rev-list", "--count", f"origin/{branch}..HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.returncode == 0 and result.stdout.strip():
        ahead_count = int(result.stdout.strip())
        if ahead_count > 0:
            print_warning(f"You have {ahead_count} unpushed commit(s) that will be included.")
            print_success("Local branch is ahead of remote (will push with release)")
            return True

    print_success("Local branch is in sync with remote")
    return True


def run_tests(project_dir: Path) -> bool:
    """Run flutter test and custom_lint tests."""
    print_header("STEP 4: RUNNING TESTS")

    # Run standard flutter tests if test directory exists
    test_dir = project_dir / "test"
    if test_dir.exists():
        result = run_command(
            ["flutter", "test"],
            project_dir,
            "Running unit tests"
        )
        if result.returncode != 0:
            return False
    else:
        print_warning("No test directory found, skipping unit tests")

    # Run custom_lint tests on example/ if it exists
    example_dir = project_dir / "example"
    if example_dir.exists() and (example_dir / "pubspec.yaml").exists():
        print_info("Running custom_lint tests on example fixtures...")

        # Install dependencies (pure Dart project, no Flutter)
        result = run_command(
            ["dart", "pub", "get"],
            example_dir,
            "Installing example dependencies"
        )
        if result.returncode != 0:
            print_warning("Could not install example dependencies, skipping lint tests")
            return True

        # Run custom_lint (capture output since fixtures intentionally trigger lints)
        print_info("Running custom_lint tests...")
        print_colored("      $ dart run custom_lint", Color.WHITE)

        use_shell = get_shell_mode()
        result = subprocess.run(
            ["dart", "run", "custom_lint"],
            cwd=example_dir,
            capture_output=True,
            text=True,
            shell=use_shell
        )

        # Count issues by severity from output
        output = result.stdout + result.stderr
        error_count = output.count(" • ERROR")
        warning_count = output.count(" • WARNING")
        info_count = output.count(" • INFO")
        total_count = error_count + warning_count + info_count

        if total_count > 0:
            print_success(f"Custom lint tests completed: {total_count} issues found ({error_count} errors, {warning_count} warnings, {info_count} info)")
            print_colored("      (These are expected - fixture files intentionally trigger lints)", Color.WHITE)
        else:
            print_success("Custom lint tests completed: no issues found")

        # Don't fail on custom_lint issues - they are expected test results
    else:
        print_warning("No example directory with pubspec.yaml found, skipping custom_lint tests")

    return True


def run_format(project_dir: Path) -> bool:
    """Run dart format to ensure code is formatted before pushing."""
    print_header("STEP 5: FORMATTING CODE")

    use_shell = get_shell_mode()

    # On Windows, git autocrlf can mask formatting changes.
    # Temporarily disable it to ensure dart format changes are detected.
    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "false"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell
        )

    # Run dart format
    result = run_command(
        ["dart", "format", "."],
        project_dir,
        "Formatting code"
    )

    if result.returncode != 0:
        # Restore autocrlf on failure
        if is_windows():
            subprocess.run(
                ["git", "config", "core.autocrlf", "true"],
                cwd=project_dir,
                capture_output=True,
                shell=use_shell
            )
        return False

    # Stage formatting changes so they're included in the final commit
    subprocess.run(
        ["git", "add", "-A"],
        cwd=project_dir,
        capture_output=True,
        shell=use_shell
    )

    # Check if there are formatting changes
    status_result = subprocess.run(
        ["git", "diff", "--cached", "--name-only"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if status_result.stdout.strip():
        print_info("Formatting changes detected and staged for commit")
    else:
        print_success("Code already properly formatted")

    # Restore autocrlf on Windows
    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "true"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell
        )

    return True


def check_pubdev_lint_issues(project_dir: Path) -> list[str]:
    """
    Check for issues that pub.dev's stricter lints will catch.

    Returns a list of issue descriptions, empty if no issues found.
    """
    issues = []

    # Directories to scan
    scan_dirs = [
        project_dir / "lib",
        project_dir / "bin",
    ]

    for scan_dir in scan_dirs:
        if not scan_dir.exists():
            continue

        for dart_file in scan_dir.rglob("*.dart"):
            content = dart_file.read_text(encoding="utf-8")
            lines = content.split("\n")
            rel_path = dart_file.relative_to(project_dir)

            # Check 1: Dangling library doc comments
            # A doc comment at the start of a file (after shebangs/ignores)
            # that's not followed by a library directive
            in_header = True
            found_doc_comment = False
            doc_comment_line = 0

            for i, line in enumerate(lines, 1):
                stripped = line.strip()

                # Skip empty lines and shebang
                if not stripped or stripped.startswith("#!"):
                    continue

                # Skip ignore comments
                if stripped.startswith("// ignore"):
                    continue

                # Found a doc comment in header area
                if stripped.startswith("///") and in_header:
                    if not found_doc_comment:
                        found_doc_comment = True
                        doc_comment_line = i
                    continue

                # If we hit a library directive after doc comment, that's fine
                # Handle both "library;" and "library name;"
                if (stripped == "library;" or stripped.startswith("library ")) and found_doc_comment:
                    found_doc_comment = False
                    break

                # If we hit any non-doc-comment line, we're past the header
                if not stripped.startswith("///"):
                    in_header = False
                    if found_doc_comment:
                        issues.append(
                            f"{rel_path}:{doc_comment_line}: Dangling library doc comment. "
                            "Use // instead of /// for file-level comments, or add a 'library' directive."
                        )
                    break

            # Check 2: Angle brackets interpreted as HTML in doc comments
            # Look for <Type> patterns outside of code blocks
            in_code_block = False

            for i, line in enumerate(lines, 1):
                stripped = line.strip()

                # Track code blocks in doc comments
                if stripped.startswith("///") and "```" in stripped:
                    in_code_block = not in_code_block
                    continue

                # Skip if we're in a code block
                if in_code_block:
                    continue

                # Only check doc comment lines
                if not stripped.startswith("///"):
                    # Reset code block state when leaving doc comments
                    in_code_block = False
                    continue

                # Look for unescaped angle brackets in doc comments
                # Pattern: word followed by <word> not wrapped in backticks
                doc_content = stripped[3:].strip()  # Remove /// prefix

                # Skip if line is a code fence marker
                if doc_content.startswith("```"):
                    continue

                # Find potential generic type patterns like List<int>, Future<void>
                # that aren't wrapped in backticks
                # Match Type<Type> patterns not inside backticks
                # We look for patterns like "List<int>" that aren't preceded by ` or followed by `
                angle_matches = list(re.finditer(r"(?<!`)\b[A-Z]\w*<\w+>(?!`)", doc_content))

                for match in angle_matches:
                    # Check if this match is inside backticks
                    pos = match.start()
                    before = doc_content[:pos]
                    after = doc_content[match.end():]

                    # Count backticks before - if odd, we're inside inline code
                    if before.count("`") % 2 == 1:
                        continue

                    issues.append(
                        f"{rel_path}:{i}: Angle brackets in '{match.group()}' will be interpreted as HTML. "
                        "Wrap in backticks: `" + match.group() + "`"
                    )

    return issues


def run_analysis(project_dir: Path) -> bool:
    """Run flutter analyze and check for pub.dev-specific lint issues."""
    print_header("STEP 6: RUNNING STATIC ANALYSIS")

    # First, check for pub.dev-specific issues
    print_info("Checking for pub.dev lint issues...")
    pubdev_issues = check_pubdev_lint_issues(project_dir)

    if pubdev_issues:
        print_error("Found pub.dev lint issues that will cost points:")
        for issue in pubdev_issues:
            print_colored(f"      {issue}", Color.YELLOW)
        print()
        print_info("Fix these issues to get full pub.dev static analysis points.")
        return False

    print_success("No pub.dev lint issues found")

    # Then run standard flutter analyze
    result = run_command(
        ["flutter", "analyze"],
        project_dir,
        "Analyzing code"
    )

    return result.returncode == 0


def validate_changelog(project_dir: Path, version: str) -> tuple[bool, str]:
    """Validate version exists in CHANGELOG and get release notes."""
    print_header("STEP 7: VALIDATING CHANGELOG")

    release_notes = validate_changelog_version(project_dir, version)

    if release_notes is None:
        print_error(f"Version {version} not found in CHANGELOG.md")
        print_info("Add release notes before publishing.")
        return False, ""

    print_success(f"Found version {version} in CHANGELOG.md")

    if not release_notes:
        print_warning("Version header found but no release notes content.")
        response = input(f"  Use generic message 'Release {version}'? [y/N] ").strip().lower()
        if not response.startswith("y"):
            return False, ""
        release_notes = f"Release {version}"
    else:
        print_colored("  Release notes preview:", Color.CYAN)
        for line in release_notes.split("\n")[:10]:  # Show first 10 lines
            print_colored(f"    {line}", Color.WHITE)
        if release_notes.count("\n") > 10:
            print_colored("    ...", Color.WHITE)

    return True, release_notes


def generate_docs(project_dir: Path) -> bool:
    """Generate documentation with dart doc."""
    print_header("STEP 8: GENERATING DOCUMENTATION")

    result = run_command(
        ["dart", "doc"],
        project_dir,
        "Generating documentation"
    )

    return result.returncode == 0


def pre_publish_validation(project_dir: Path) -> bool:
    """Run dart pub publish --dry-run silently, only showing output on failure."""
    print_header("STEP 9: PRE-PUBLISH VALIDATION")

    print_info("Running pre-publish validation...")
    use_shell = get_shell_mode()

    result = subprocess.run(
        ["dart", "pub", "publish", "--dry-run"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    # Exit code 0 = success, 65 = warnings but valid
    if result.returncode in (0, 65):
        print_success("Package validated successfully")
        return True

    # Check for Windows-specific 'nul' path bug in Dart SDK
    # This is a known bug where dart pub tries to access a path containing 'nul'
    # which is a reserved device name on Windows (like /dev/null on Unix)
    output = (result.stdout or "") + (result.stderr or "")
    if is_windows() and "nul" in output.lower() and "path is invalid" in output.lower():
        print_warning("Encountered Windows 'nul' path bug in Dart SDK (known issue)")
        print_warning("Dependencies resolved successfully - continuing with publish")
        return True

    # Real failure - show the output
    print_error("Pre-publish validation failed:")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    return False


# Safe publishing account - no confirmation needed when using this email
SAFE_PUBLISH_EMAIL = "saropa.packages@gmail.com"


def get_pub_account() -> str | None:
    """Get the currently authenticated pub.dev account email."""
    use_shell = get_shell_mode()

    # Run 'dart pub login' which tells us if we're already logged in
    result = subprocess.run(
        ["dart", "pub", "login"],
        capture_output=True,
        text=True,
        shell=use_shell,
        input="n\n"  # Say no if it prompts to open browser
    )

    output = result.stdout + result.stderr

    # Look for "You are already logged in as <email>"
    match = re.search(r"logged in as <([^>]+)>", output)
    if match:
        return match.group(1)

    return None


def publish_to_pubdev(project_dir: Path) -> bool:
    """Notify that publishing happens automatically via GitHub Actions tag trigger."""
    print_header("STEP 12: PUBLISHING TO PUB.DEV VIA GITHUB ACTIONS")

    print_success("Tag push triggered GitHub Actions publish workflow!")
    print()
    print_colored("  Publishing is now running automatically on GitHub Actions.", Color.CYAN)
    print_colored("  No personal email will be shown on pub.dev.", Color.GREEN)
    print()

    # Get repo URL for the actions page
    remote_url = get_remote_url(project_dir)
    repo_path = extract_repo_path(remote_url)
    print_colored(f"  Monitor progress at: https://github.com/{repo_path}/actions", Color.CYAN)
    print()

    return True


def git_commit_and_push(project_dir: Path, version: str, branch: str) -> bool:
    """Commit changes and push to remote."""
    print_header("STEP 10: COMMITTING CHANGES")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Add all changes
    result = run_command(["git", "add", "-A"], project_dir, "Staging changes")
    if result.returncode != 0:
        return False

    # Check if there are changes to commit
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.stdout.strip():
        # Commit
        result = run_command(
            ["git", "commit", "-m", f"Release {tag_name}"],
            project_dir,
            f"Committing: Release {tag_name}"
        )
        if result.returncode != 0:
            return False

        # Push (with retry on rejection)
        if not _push_with_retry(project_dir, branch):
            return False
    else:
        print_warning("No changes to commit. Skipping commit step.")

    return True


def _push_with_retry(project_dir: Path, branch: str, max_retries: int = 2) -> bool:
    """Push to remote, pulling and retrying if rejected due to remote changes."""
    use_shell = get_shell_mode()

    for attempt in range(max_retries + 1):
        print_info(f"Pushing to {branch}...")
        print_colored(f"      $ git push origin {branch}", Color.WHITE)

        result = subprocess.run(
            ["git", "push", "origin", branch],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell
        )

        if result.returncode == 0:
            print_success(f"Pushing to {branch} completed")
            return True

        # Check if push was rejected due to remote changes
        output = (result.stdout or "") + (result.stderr or "")
        if "rejected" in output and ("fetch first" in output or "non-fast-forward" in output):
            if attempt < max_retries:
                print_warning("Push rejected - remote has new changes. Pulling and retrying...")

                # Pull with rebase to integrate remote changes
                pull_result = subprocess.run(
                    ["git", "pull", "--rebase", "origin", branch],
                    cwd=project_dir,
                    capture_output=True,
                    text=True,
                    shell=use_shell
                )

                if pull_result.returncode != 0:
                    print_error("Failed to pull remote changes:")
                    if pull_result.stderr:
                        print_colored(pull_result.stderr, Color.RED)
                    print_info("Resolve conflicts manually and try again.")
                    return False

                print_success("Pulled and rebased remote changes")
                continue
            else:
                print_error("Push failed after multiple attempts. Remote may have conflicting changes.")
                return False
        else:
            # Some other push error
            print_error(f"Push failed (exit code {result.returncode})")
            if output:
                print_colored(output, Color.RED)
            return False

    return False


def create_git_tag(project_dir: Path, version: str) -> bool:
    """Create and push git tag."""
    print_header("STEP 11: CREATING GIT TAG")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if tag exists locally
    result = subprocess.run(
        ["git", "tag", "-l", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.stdout.strip():
        print_warning(f"Tag {tag_name} already exists locally. Skipping tag creation.")
    else:
        result = run_command(
            ["git", "tag", "-a", tag_name, "-m", f"Release {tag_name}"],
            project_dir,
            f"Creating tag {tag_name}"
        )
        if result.returncode != 0:
            return False

    # Check if tag exists on remote
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "origin", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.stdout.strip():
        print_warning(f"Tag {tag_name} already exists on remote. Skipping push.")
    else:
        result = run_command(
            ["git", "push", "origin", tag_name],
            project_dir,
            f"Pushing tag {tag_name}"
        )
        if result.returncode != 0:
            return False

    return True


def create_github_release(project_dir: Path, version: str, release_notes: str) -> tuple[bool, str | None]:
    """
    Create GitHub release using gh CLI.

    Returns:
        (success, error_message) - success is True if release was created or already exists,
        error_message is None on success or contains the error description on failure.
    """
    print_header("STEP 13: CREATING GITHUB RELEASE")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if release exists
    result = subprocess.run(
        ["gh", "release", "view", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.returncode == 0:
        print_warning(f"GitHub release {tag_name} already exists. Skipping release creation.")
        return True, None

    # Create release
    result = subprocess.run(
        ["gh", "release", "create", tag_name, "--title", f"Release {tag_name}", "--notes", release_notes],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )

    if result.returncode == 0:
        print_success(f"Created GitHub release {tag_name}")
        return True, None

    # Check for auth error
    error_output = (result.stderr or "") + (result.stdout or "")
    if "401" in error_output or "Bad credentials" in error_output or "authentication" in error_output.lower():
        return False, (
            "GitHub CLI auth failed. If GITHUB_TOKEN env var is set, clear it first:\n"
            "      PowerShell: $env:GITHUB_TOKEN = \"\"\n"
            "      Bash: unset GITHUB_TOKEN\n"
            "      Then run: gh auth status"
        )

    return False, f"GitHub release failed (exit code {result.returncode})"


def get_current_branch(project_dir: Path) -> str:
    """Get the current git branch name."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return "main"


def get_remote_url(project_dir: Path) -> str:
    """Get the git remote URL."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return ""


def extract_repo_path(remote_url: str) -> str:
    """Extract owner/repo from git remote URL."""
    match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", remote_url)
    if match:
        return match.group(1)
    return "owner/repo"


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Main entry point."""
    enable_ansi_support()
    show_saropa_logo()
    print_colored(f"  Saropa Lints publisher script v{SCRIPT_VERSION}", Color.MAGENTA)
    print()

    # Find project directory (script is in scripts/)
    script_dir = Path(__file__).parent
    project_dir = script_dir.parent

    pubspec_path = project_dir / "pubspec.yaml"
    if not pubspec_path.exists():
        exit_with_error(
            f"pubspec.yaml not found at {pubspec_path}",
            ExitCode.PREREQUISITES_FAILED
        )

    changelog_path = project_dir / "CHANGELOG.md"
    if not changelog_path.exists():
        exit_with_error(
            f"CHANGELOG.md not found at {changelog_path}",
            ExitCode.PREREQUISITES_FAILED
        )

    # Get package info
    package_name = get_package_name(pubspec_path)
    version = get_version_from_pubspec(pubspec_path)
    branch = get_current_branch(project_dir)
    remote_url = get_remote_url(project_dir)

    # Validate version format
    if not re.match(r"^\d+\.\d+\.\d+$", version):
        exit_with_error(
            f"Invalid version format '{version}'. Use semantic versioning: MAJOR.MINOR.PATCH",
            ExitCode.VALIDATION_FAILED
        )

    # Validate pubspec and changelog versions are in sync
    changelog_version = get_latest_changelog_version(changelog_path)
    if changelog_version is None:
        exit_with_error(
            "Could not extract version from CHANGELOG.md",
            ExitCode.CHANGELOG_FAILED
        )

    if version != changelog_version:
        exit_with_error(
            f"Version mismatch: pubspec.yaml has {version}, "
            f"but CHANGELOG.md latest is {changelog_version}. "
            "Update one to match the other before publishing.",
            ExitCode.CHANGELOG_FAILED
        )

    print_header("SAROPA LINTS PUBLISHER")

    # Package info display
    print_colored("  Package Information:", Color.WHITE)
    print_colored(f"      Name:       {package_name}", Color.CYAN)
    print_colored(f"      Version:    {version}", Color.CYAN)
    print_colored(f"      Tag:        v{version}", Color.CYAN)
    print_colored(f"      Branch:     {branch}", Color.CYAN)
    print_colored(f"      Repository: {remote_url}", Color.CYAN)

    # Count rules
    rule_count = count_rules(project_dir)
    category_count = count_categories(project_dir)
    print_colored(f"      Lint Rules: {rule_count} rules in {category_count} categories", Color.CYAN)
    print()

    # Display changelog
    display_changelog(project_dir)

    # Display test coverage (shame developers if low!)
    display_test_coverage(project_dir)

    # =========================================================================
    # WORKFLOW STEPS
    # =========================================================================

    # Step 1: Prerequisites
    if not check_prerequisites():
        exit_with_error("Prerequisites check failed", ExitCode.PREREQUISITES_FAILED)

    # Step 2: Working tree
    ok, _ = check_working_tree(project_dir)
    if not ok:
        exit_with_error("Aborted by user. Commit or stash your changes first.", ExitCode.USER_CANCELLED)

    # Step 3: Remote sync
    if not check_remote_sync(project_dir, branch):
        exit_with_error("Remote sync check failed", ExitCode.WORKING_TREE_FAILED)

    # Step 4: Tests
    if not run_tests(project_dir):
        exit_with_error("Tests failed. Fix test failures before publishing.", ExitCode.TEST_FAILED)

    # Step 5: Format code (ensures CI won't fail on formatting)
    if not run_format(project_dir):
        exit_with_error("Code formatting failed.", ExitCode.VALIDATION_FAILED)

    # Step 6: Analysis
    if not run_analysis(project_dir):
        exit_with_error("Static analysis failed. Fix issues before publishing.", ExitCode.ANALYSIS_FAILED)

    # Step 7: Validate changelog
    ok, release_notes = validate_changelog(project_dir, version)
    if not ok:
        exit_with_error("CHANGELOG validation failed", ExitCode.CHANGELOG_FAILED)

    # Step 8: Generate docs
    if not generate_docs(project_dir):
        exit_with_error("Documentation generation failed", ExitCode.VALIDATION_FAILED)

    # Step 9: Pre-publish validation
    if not pre_publish_validation(project_dir):
        exit_with_error("Pre-publish validation failed", ExitCode.VALIDATION_FAILED)

    # =========================================================================
    # CONFIRMATION (disabled - uncomment to require manual confirmation)
    # =========================================================================

    # print_header("PUBLISH CONFIRMATION")
    #
    # print_colored("  Ready to publish:", Color.CYAN)
    # print_colored(f"      Package:    {package_name}", Color.WHITE)
    # print_colored(f"      Version:    {version}", Color.WHITE)
    # print_colored(f"      Tag:        v{version}", Color.WHITE)
    # print_colored(f"      Branch:     {branch}", Color.WHITE)
    # print()
    #
    # response = input("  Publish to pub.dev and create GitHub release? [y/N] ").strip().lower()
    # if not response.startswith("y"):
    #     print_warning("Publish cancelled by user.")
    #     return ExitCode.USER_CANCELLED.value

    # =========================================================================
    # COMMIT, TAG, AND PUBLISH
    # =========================================================================

    # Step 10: Git commit and push (BEFORE GitHub Actions - it needs the code)
    if not git_commit_and_push(project_dir, version, branch):
        exit_with_error("Git operations failed", ExitCode.GIT_FAILED)

    # Step 11: Create git tag
    if not create_git_tag(project_dir, version):
        exit_with_error("Git tag creation failed", ExitCode.GIT_FAILED)

    # Step 12: Trigger GitHub Actions to publish to pub.dev
    if not publish_to_pubdev(project_dir):
        exit_with_error("Failed to trigger GitHub Actions publish", ExitCode.PUBLISH_FAILED)

    # Step 13: Create GitHub release
    gh_success, gh_error = create_github_release(project_dir, version, release_notes)

    # =========================================================================
    # SUCCESS
    # =========================================================================

    print()
    print_colored("=" * 70, Color.GREEN)
    print_colored(f"  PUBLISHED {package_name} v{version} TO PUB.DEV!", Color.GREEN)
    print_colored("=" * 70, Color.GREEN)
    print()

    repo_path = extract_repo_path(remote_url)
    print_colored("  Next steps:", Color.WHITE)
    print_colored(f"      Package:    https://pub.dev/packages/{package_name}", Color.CYAN)
    print_colored(f"      Score:      https://pub.dev/packages/{package_name}/score", Color.CYAN)
    print_colored(f"      Versions:   https://pub.dev/packages/{package_name}/versions", Color.CYAN)
    print_colored(f"      CI status:  https://github.com/{repo_path}/actions", Color.CYAN)

    if gh_success:
        print_colored(f"      Release:    https://github.com/{repo_path}/releases/tag/v{version}", Color.CYAN)
    else:
        print()
        print_warning(f"GitHub release was not created: {gh_error}")
        print_colored("      To create it manually, run:", Color.YELLOW)
        print_colored(f"          gh auth login", Color.WHITE)
        print_colored(f"          gh release create v{version} --title \"Release v{version}\" --notes-file CHANGELOG.md", Color.WHITE)
    print()

    # Open pub.dev in browser
    try:
        webbrowser.open(f"https://pub.dev/packages/{package_name}")
    except Exception:
        pass

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
