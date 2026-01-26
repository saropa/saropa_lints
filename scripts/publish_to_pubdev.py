#!/usr/bin/env python3
"""
Publish saropa_lints package to pub.dev and create GitHub release.

This is the SINGLE ENTRY POINT for the complete release workflow.
It gates publishing behind comprehensive audit checks, including
tier integrity verification.

Workflow:
    Step 0:  Check that module scripts exist in scripts/modules/
    Step 0a: Run tier integrity checks (BLOCKING)
    Step 0b: Run full rule audit (BLOCKING on duplicates)
    Step 0c: Prompt Y/N to continue to publish
    Step 1:  Check prerequisites (flutter, git, gh)
    Step 2:  Validate working tree
    Step 3:  Check remote sync
    Step 4:  Run tests
    Step 5:  Format code
    Step 6:  Run static analysis
    Step 7:  Validate CHANGELOG.md
    Step 8:  Generate documentation
    Step 9:  Pre-publish validation (dart pub publish --dry-run)
    Step 10: Commit and push
    Step 11: Create git tag
    Step 12: Publish via GitHub Actions
    Step 13: Create GitHub release

Options:
    --audit-only      Run audit + integrity checks only, skip publish
    --skip-audit      Skip audit (use with caution)
    --silent          Suppress all output except errors
    --warnings-only   Only show warnings and errors
    --verbose         Show all details (default)

Version:   4.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Platforms:
    - Windows (uses shell=True for .bat executables)
    - macOS (native executable lookup)
    - Linux (native executable lookup)

Troubleshooting:
    GitHub release fails with "Bad credentials":
        If you have a GITHUB_TOKEN environment variable set (even if invalid),
        it takes precedence over 'gh auth login' credentials. To fix:
        - PowerShell: $env:GITHUB_TOKEN = ""
        - Bash: unset GITHUB_TOKEN
        Then run 'gh auth status' to verify your keyring credentials are active.

Exit Codes:
    0  - Success
    1  - Prerequisites failed
    2  - Working tree check failed
    3  - Tests failed
    4  - Analysis failed
    5  - Changelog validation failed
    6  - Pre-publish validation failed
    7  - Publish failed
    8  - Git operations failed
    9  - GitHub release failed
    10 - User cancelled
    11 - Audit failed (tier integrity or duplicates)
"""

from __future__ import annotations

import re
import subprocess
import sys
import webbrowser
from pathlib import Path

# Allow running as `python scripts/publish_to_pubdev.py` from project root
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)


SCRIPT_VERSION = "4.0"


# =============================================================================
# MODULE CHECK (runs before any module imports)
# =============================================================================

_REQUIRED_MODULES = [
    "modules/_utils.py",
    "modules/_audit.py",
    "modules/_tier_integrity.py",
    "modules/__init__.py",
]


def check_modules_exist() -> bool:
    """Verify all required module files exist before importing.

    This runs BEFORE any module imports so the user gets a clear
    error message instead of a Python ImportError traceback.

    Returns:
        True if all modules found, False otherwise.
    """
    scripts_dir = Path(__file__).resolve().parent
    all_found = True

    for module_rel in _REQUIRED_MODULES:
        module_path = scripts_dir / module_rel
        if module_path.exists():
            # Use basic print here - utils not imported yet
            print(f"  \033[92m✓\033[0m Module found: {module_rel}")
        else:
            print(f"  \033[91m✗\033[0m Module MISSING: {module_rel}")
            all_found = False

    if not all_found:
        print()
        print(
            "\033[91m  Required modules are missing from scripts/modules/.\033[0m"
        )
        print(
            "  Ensure the following files exist:"
        )
        for m in _REQUIRED_MODULES:
            print(f"    scripts/{m}")

    return all_found


# =============================================================================
# EARLY GATE: Check modules before importing anything from them
# =============================================================================

if not check_modules_exist():
    sys.exit(1)


# Now safe to import from modules
from scripts.modules._utils import (
    Color,
    ExitCode,
    OutputLevel,
    command_exists,
    enable_ansi_support,
    exit_with_error,
    get_project_dir,
    get_shell_mode,
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


# =============================================================================
# OUTPUT LEVEL PARSING
# =============================================================================


def _parse_output_level() -> OutputLevel:
    """Determine output level from CLI args."""
    if "--silent" in sys.argv:
        return OutputLevel.SILENT
    if "--warnings-only" in sys.argv:
        return OutputLevel.WARNINGS_ONLY
    if "--verbose" in sys.argv:
        return OutputLevel.VERBOSE
    return OutputLevel.VERBOSE  # default


# =============================================================================
# PRE-PUBLISH AUDIT GATE
# =============================================================================


def run_pre_publish_audits(project_dir: Path) -> bool:
    """Run all audits before publish. Returns True if publish can proceed.

    BLOCKING checks (fail = no publish):
      - Tier integrity: orphans, phantoms, multi-tier, misplaced opinionated
      - Duplicate rule names, class names, or aliases

    INFORMATIONAL checks (warn but don't block):
      - DX message quality
      - OWASP coverage gaps
      - ROADMAP sync
      - Quality metrics
    """
    from scripts.modules._tier_integrity import (
        check_tier_integrity,
        print_tier_integrity_report,
    )
    from scripts.modules._audit import run_full_audit

    rules_dir = project_dir / "lib" / "src" / "rules"
    tiers_path = project_dir / "lib" / "src" / "tiers.dart"

    # --- BLOCKING: Tier integrity ---
    tier_result = check_tier_integrity(rules_dir, tiers_path)
    print_tier_integrity_report(tier_result)

    if not tier_result.passed:
        print_error(
            f"Tier integrity FAILED with {tier_result.issues_count} issue(s)."
        )
        print_error("Fix tier assignments in lib/src/tiers.dart.")
        return False

    # --- BLOCKING + INFORMATIONAL: Full audit ---
    audit_result = run_full_audit(
        project_dir=project_dir,
        skip_dx=False,
        compact=True,
    )

    if audit_result.has_blocking_issues:
        print_error("Blocking audit issues found (duplicate rules).")
        return False

    print_success("All pre-publish audit checks passed.")
    return True


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
    match = re.search(r"##\s*\[?(\d+\.\d+\.\d+)\]?", content)
    return match.group(1) if match else None


def validate_changelog_version(project_dir: Path, version: str) -> str | None:
    """Validate version exists in CHANGELOG and extract release notes."""
    changelog_path = project_dir / "CHANGELOG.md"
    if not changelog_path.exists():
        return None

    content = changelog_path.read_text(encoding="utf-8")
    version_pattern = rf"##\s*\[?{re.escape(version)}\]?"
    if not re.search(version_pattern, content):
        return None

    pattern = (
        rf"(?s)##\s*\[?{re.escape(version)}\]?[^\n]*\n"
        rf"(.*?)(?=##\s*\[?\d+\.\d+\.\d+|$)"
    )
    match = re.search(pattern, content)
    return match.group(1).strip() if match else ""


def display_changelog(project_dir: Path) -> str | None:
    """Display the latest changelog entry."""
    changelog_path = project_dir / "CHANGELOG.md"
    if not changelog_path.exists():
        print_warning("CHANGELOG.md not found")
        return None

    content = changelog_path.read_text(encoding="utf-8")
    match = re.search(
        r"^(## \[?\d+\.\d+\.\d+\]?.*?)(?=^## |\Z)",
        content,
        re.MULTILINE | re.DOTALL,
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
# LINT RULE COUNTING
# =============================================================================


def count_rules(project_dir: Path) -> int:
    """Count the number of lint rules."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    if not rules_dir.exists():
        return 0

    count = 0
    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        count += len(
            re.findall(
                r"class \w+ extends (?:SaropaLintRule|DartLintRule)", content
            )
        )
    return count


def count_categories(project_dir: Path) -> int:
    """Count the number of rule category files."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    if not rules_dir.exists():
        return 0
    return sum(
        1
        for f in rules_dir.glob("*_rules.dart")
        if f.name != "all_rules.dart"
    )


def count_test_fixtures(project_dir: Path) -> int:
    """Count the number of test fixture files."""
    example_dir = project_dir / "example" / "lib"
    if not example_dir.exists():
        return 0
    return sum(1 for _ in example_dir.rglob("*_fixture.dart"))


def display_test_coverage(project_dir: Path) -> None:
    """Display test coverage report with emphasis on low coverage."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    example_dir = project_dir / "example" / "lib"
    if not rules_dir.exists():
        return

    category_details: list[tuple[str, int, int]] = []
    for dart_file in sorted(rules_dir.glob("*_rules.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        category = dart_file.stem.replace("_rules", "")
        content = dart_file.read_text(encoding="utf-8")
        rule_count = len(
            re.findall(
                r"class \w+ extends (?:SaropaLintRule|DartLintRule)", content
            )
        )

        fixture_count = 0
        for suffix in [category, f"{category}s"]:
            fixture_dir = example_dir / suffix
            if fixture_dir.exists():
                fixture_count = len(list(fixture_dir.glob("*_fixture.dart")))
                if fixture_count > 0:
                    break

        category_details.append((category, rule_count, fixture_count))

    total_rules = sum(c[1] for c in category_details)
    total_fixtures = sum(c[2] for c in category_details)
    coverage_pct = (total_fixtures / total_rules * 100) if total_rules > 0 else 0

    print()
    print_colored("  Test Coverage Report:", Color.WHITE)
    print_colored("  " + "-" * 50, Color.CYAN)

    if coverage_pct < 10:
        color, status = Color.RED, "CRITICAL"
    elif coverage_pct < 30:
        color, status = Color.YELLOW, "LOW"
    elif coverage_pct < 70:
        color, status = Color.CYAN, "MODERATE"
    else:
        color, status = Color.GREEN, "GOOD"

    print_colored(
        f"      Overall: {total_fixtures}/{total_rules} "
        f"({coverage_pct:.1f}%) - {status}",
        color,
    )
    print_colored("  " + "-" * 50, Color.CYAN)
    print()


# =============================================================================
# PUBLISH WORKFLOW STEPS
# =============================================================================


def check_prerequisites() -> bool:
    """Step 1: Check that required tools are available."""
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
    """Step 2: Check working tree status.

    Returns:
        (ok, has_uncommitted_changes)
    """
    print_header("STEP 2: CHECKING WORKING TREE")

    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.stdout.strip():
        print_warning("You have uncommitted changes:")
        print_colored(result.stdout, Color.YELLOW)
        print()
        response = (
            input(
                "  These changes will be included in the "
                "release commit. Continue? [y/N] "
            )
            .strip()
            .lower()
        )
        if not response.startswith("y"):
            return False, True
        return True, True

    print_success("Working tree is clean")
    return True, False


def check_remote_sync(project_dir: Path, branch: str) -> bool:
    """Step 3: Check if local branch is in sync with remote."""
    print_header("STEP 3: CHECKING REMOTE SYNC")

    use_shell = get_shell_mode()

    # Fetch from remote
    print_info("Fetching from remote...")
    result = subprocess.run(
        ["git", "fetch", "origin", branch],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode != 0:
        print_warning("Could not fetch from remote. Proceeding anyway.")
        return True

    # Check if behind
    result = subprocess.run(
        ["git", "rev-list", "--count", f"HEAD..origin/{branch}"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0 and result.stdout.strip():
        behind_count = int(result.stdout.strip())
        if behind_count > 0:
            print_warning(
                f"Local branch is behind remote by {behind_count} commit(s)."
            )
            print_info(f"Pulling changes from origin/{branch}...")
            pull_result = subprocess.run(
                ["git", "pull", "origin", branch],
                cwd=project_dir,
                capture_output=True,
                text=True,
                shell=use_shell,
            )
            if pull_result.returncode != 0:
                print_error("Failed to pull changes from remote.")
                if pull_result.stderr:
                    print_colored(pull_result.stderr, Color.RED)
                return False
            print_success(f"Pulled {behind_count} commit(s) from remote")

    # Check if ahead
    result = subprocess.run(
        ["git", "rev-list", "--count", f"origin/{branch}..HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0 and result.stdout.strip():
        ahead_count = int(result.stdout.strip())
        if ahead_count > 0:
            print_warning(
                f"You have {ahead_count} unpushed commit(s) "
                f"that will be included."
            )
            print_success("Local branch is ahead of remote")
            return True

    print_success("Local branch is in sync with remote")
    return True


def run_tests(project_dir: Path) -> bool:
    """Step 4: Run flutter test and custom_lint tests."""
    print_header("STEP 4: RUNNING TESTS")

    test_dir = project_dir / "test"
    if test_dir.exists():
        result = run_command(
            ["flutter", "test"], project_dir, "Running unit tests"
        )
        if result.returncode != 0:
            return False
    else:
        print_warning("No test directory found, skipping unit tests")

    # Run custom_lint tests on example/
    example_dir = project_dir / "example"
    if example_dir.exists() and (example_dir / "pubspec.yaml").exists():
        print_info("Running custom_lint tests on example fixtures...")
        result = run_command(
            ["dart", "pub", "get"],
            example_dir,
            "Installing example dependencies",
        )
        if result.returncode != 0:
            print_warning("Could not install example deps, skipping")
            return True

        print_info("Running custom_lint tests...")
        print_colored("      $ dart run custom_lint", Color.WHITE)
        use_shell = get_shell_mode()
        result = subprocess.run(
            ["dart", "run", "custom_lint"],
            cwd=example_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        output = result.stdout + result.stderr
        error_count = output.count(" • ERROR")
        warning_count = output.count(" • WARNING")
        info_count = output.count(" • INFO")
        total_count = error_count + warning_count + info_count

        if total_count > 0:
            print_success(
                f"Custom lint: {total_count} issues "
                f"({error_count}E, {warning_count}W, {info_count}I)"
            )
            print_colored(
                "      (Expected - fixture files trigger lints)", Color.WHITE
            )
        else:
            print_success("Custom lint tests completed: no issues found")

    return True


def run_format(project_dir: Path) -> bool:
    """Step 5: Run dart format."""
    print_header("STEP 5: FORMATTING CODE")

    use_shell = get_shell_mode()

    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "false"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell,
        )

    result = run_command(["dart", "format", "."], project_dir, "Formatting")
    if result.returncode != 0:
        if is_windows():
            subprocess.run(
                ["git", "config", "core.autocrlf", "true"],
                cwd=project_dir,
                capture_output=True,
                shell=use_shell,
            )
        return False

    subprocess.run(
        ["git", "add", "-A"],
        cwd=project_dir,
        capture_output=True,
        shell=use_shell,
    )

    if is_windows():
        subprocess.run(
            ["git", "config", "core.autocrlf", "true"],
            cwd=project_dir,
            capture_output=True,
            shell=use_shell,
        )

    print_success("Code formatted")
    return True


def check_pubdev_lint_issues(project_dir: Path) -> list[str]:
    """Check for issues that pub.dev's stricter lints will catch."""
    issues: list[str] = []
    scan_dirs = [project_dir / "lib", project_dir / "bin"]

    for scan_dir in scan_dirs:
        if not scan_dir.exists():
            continue
        for dart_file in scan_dir.rglob("*.dart"):
            content = dart_file.read_text(encoding="utf-8")
            lines = content.split("\n")
            rel_path = dart_file.relative_to(project_dir)

            # Check: Dangling library doc comments
            in_header = True
            found_doc_comment = False
            doc_comment_line = 0
            for i, line in enumerate(lines, 1):
                stripped = line.strip()
                if not stripped or stripped.startswith("#!"):
                    continue
                if stripped.startswith("// ignore"):
                    continue
                if stripped.startswith("///") and in_header:
                    if not found_doc_comment:
                        found_doc_comment = True
                        doc_comment_line = i
                    continue
                if (
                    stripped == "library;"
                    or stripped.startswith("library ")
                ) and found_doc_comment:
                    found_doc_comment = False
                    break
                if not stripped.startswith("///"):
                    in_header = False
                    if found_doc_comment:
                        issues.append(
                            f"{rel_path}:{doc_comment_line}: "
                            "Dangling library doc comment."
                        )
                    break

            # Check: Angle brackets in doc comments
            in_code_block = False
            for i, line in enumerate(lines, 1):
                stripped = line.strip()
                if stripped.startswith("///") and "```" in stripped:
                    in_code_block = not in_code_block
                    continue
                if in_code_block:
                    continue
                if not stripped.startswith("///"):
                    in_code_block = False
                    continue
                doc_content = stripped[3:].strip()
                if doc_content.startswith("```"):
                    continue
                angle_matches = list(
                    re.finditer(r"\b[\w.]+<[\w\s,]+>", doc_content)
                )
                for match in angle_matches:
                    pos = match.start()
                    before = doc_content[:pos]
                    if before.count("`") % 2 == 1:
                        continue
                    issues.append(
                        f"{rel_path}:{i}: Angle brackets in "
                        f"'{match.group()}' interpreted as HTML."
                    )

    return issues


def run_analysis(project_dir: Path) -> bool:
    """Step 6: Run static analysis."""
    print_header("STEP 6: RUNNING STATIC ANALYSIS")

    print_info("Checking for pub.dev lint issues...")
    pubdev_issues = check_pubdev_lint_issues(project_dir)
    if pubdev_issues:
        print_error("Found pub.dev lint issues:")
        for issue in pubdev_issues:
            print_colored(f"      {issue}", Color.YELLOW)
        return False
    print_success("No pub.dev lint issues found")

    result = run_command(
        ["flutter", "analyze"], project_dir, "Analyzing code"
    )
    return result.returncode == 0


def validate_changelog(
    project_dir: Path, version: str
) -> tuple[bool, str]:
    """Step 7: Validate version in CHANGELOG and get release notes."""
    print_header("STEP 7: VALIDATING CHANGELOG")

    release_notes = validate_changelog_version(project_dir, version)
    if release_notes is None:
        print_error(f"Version {version} not found in CHANGELOG.md")
        return False, ""

    print_success(f"Found version {version} in CHANGELOG.md")

    if not release_notes:
        response = (
            input(f"  Use generic message 'Release {version}'? [y/N] ")
            .strip()
            .lower()
        )
        if not response.startswith("y"):
            return False, ""
        release_notes = f"Release {version}"
    else:
        print_colored("  Release notes preview:", Color.CYAN)
        for line in release_notes.split("\n")[:10]:
            print_colored(f"    {line}", Color.WHITE)
        if release_notes.count("\n") > 10:
            print_colored("    ...", Color.WHITE)

    return True, release_notes


def generate_docs(project_dir: Path) -> bool:
    """Step 8: Generate documentation."""
    print_header("STEP 8: GENERATING DOCUMENTATION")
    result = run_command(["dart", "doc"], project_dir, "Generating docs")
    return result.returncode == 0


def pre_publish_validation(project_dir: Path) -> bool:
    """Step 9: Run dart pub publish --dry-run."""
    print_header("STEP 9: PRE-PUBLISH VALIDATION")

    print_info("Running 'dart pub publish --dry-run'...")
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["dart", "pub", "publish", "--dry-run"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.returncode in (0, 65):
        print_success("Package validated successfully")
        return True

    output = (result.stdout or "") + (result.stderr or "")
    if (
        is_windows()
        and "nul" in output.lower()
        and "path is invalid" in output.lower()
    ):
        print_warning("Windows 'nul' path bug (known issue) - continuing")
        return True

    print_error("Pre-publish validation failed!")
    print_colored(
        "\n======== pub.dev validation errors ========", Color.RED
    )
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr)
    print_colored("============================================\n", Color.RED)
    return False


# =============================================================================
# GIT OPERATIONS
# =============================================================================


def get_current_branch(project_dir: Path) -> str:
    """Get the current git branch name."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    return result.stdout.strip() if result.returncode == 0 else "main"


def get_remote_url(project_dir: Path) -> str:
    """Get the git remote URL."""
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def extract_repo_path(remote_url: str) -> str:
    """Extract owner/repo from git remote URL."""
    match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", remote_url)
    return match.group(1) if match else "owner/repo"


def git_commit_and_push(
    project_dir: Path, version: str, branch: str
) -> bool:
    """Step 10: Commit changes and push to remote."""
    print_header("STEP 10: COMMITTING CHANGES")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    result = run_command(
        ["git", "add", "-A"], project_dir, "Staging changes"
    )
    if result.returncode != 0:
        return False

    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.stdout.strip():
        result = run_command(
            ["git", "commit", "-m", f"Release {tag_name}"],
            project_dir,
            f"Committing: Release {tag_name}",
        )
        if result.returncode != 0:
            return False

        if not _push_with_retry(project_dir, branch):
            return False
    else:
        print_warning("No changes to commit.")

    return True


def _push_with_retry(
    project_dir: Path, branch: str, max_retries: int = 2
) -> bool:
    """Push to remote, pulling and retrying if rejected."""
    use_shell = get_shell_mode()

    for attempt in range(max_retries + 1):
        print_info(f"Pushing to {branch}...")
        result = subprocess.run(
            ["git", "push", "origin", branch],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if result.returncode == 0:
            print_success(f"Pushed to {branch}")
            return True

        output = (result.stdout or "") + (result.stderr or "")
        if "rejected" in output and (
            "fetch first" in output or "non-fast-forward" in output
        ):
            if attempt < max_retries:
                print_warning("Push rejected - pulling and retrying...")
                pull_result = subprocess.run(
                    ["git", "pull", "--rebase", "origin", branch],
                    cwd=project_dir,
                    capture_output=True,
                    text=True,
                    shell=use_shell,
                )
                if pull_result.returncode != 0:
                    print_error("Failed to pull remote changes.")
                    return False
                print_success("Rebased remote changes")
                continue
            print_error("Push failed after retries.")
            return False

        print_error(f"Push failed (exit code {result.returncode})")
        if output:
            print_colored(output, Color.RED)
        return False

    return False


def create_git_tag(project_dir: Path, version: str) -> bool:
    """Step 11: Create and push git tag."""
    print_header("STEP 11: CREATING GIT TAG")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if tag exists locally
    result = subprocess.run(
        ["git", "tag", "-l", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.stdout.strip():
        print_warning(f"Tag {tag_name} already exists locally.")
    else:
        result = run_command(
            ["git", "tag", "-a", tag_name, "-m", f"Release {tag_name}"],
            project_dir,
            f"Creating tag {tag_name}",
        )
        if result.returncode != 0:
            return False

    # Check if tag exists on remote
    result = subprocess.run(
        ["git", "ls-remote", "--tags", "origin", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.stdout.strip():
        print_warning(f"Tag {tag_name} already exists on remote.")
    else:
        result = run_command(
            ["git", "push", "origin", tag_name],
            project_dir,
            f"Pushing tag {tag_name}",
        )
        if result.returncode != 0:
            return False

    return True


def publish_to_pubdev_step(project_dir: Path) -> bool:
    """Step 12: Notify that publishing happens via GitHub Actions."""
    print_header("STEP 12: PUBLISHING TO PUB.DEV VIA GITHUB ACTIONS")

    print_success("Tag push triggered GitHub Actions publish workflow!")
    print_colored(
        "  Publishing is now running automatically on GitHub Actions.",
        Color.CYAN,
    )

    remote_url = get_remote_url(project_dir)
    repo_path = extract_repo_path(remote_url)
    print_colored(
        f"  Monitor: https://github.com/{repo_path}/actions", Color.CYAN
    )
    print()
    return True


def create_github_release(
    project_dir: Path, version: str, release_notes: str
) -> tuple[bool, str | None]:
    """Step 13: Create GitHub release."""
    print_header("STEP 13: CREATING GITHUB RELEASE")

    tag_name = f"v{version}"
    use_shell = get_shell_mode()

    # Check if release exists
    result = subprocess.run(
        ["gh", "release", "view", tag_name],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if result.returncode == 0:
        print_warning(f"Release {tag_name} already exists.")
        return True, None

    result = subprocess.run(
        [
            "gh", "release", "create", tag_name,
            "--title", f"Release {tag_name}",
            "--notes", release_notes,
        ],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.returncode == 0:
        print_success(f"Created GitHub release {tag_name}")
        return True, None

    error_output = (result.stderr or "") + (result.stdout or "")
    if any(
        s in error_output.lower()
        for s in ["401", "bad credentials", "authentication"]
    ):
        return False, (
            "GitHub CLI auth failed. Clear GITHUB_TOKEN env var "
            "and run: gh auth status"
        )
    return False, f"Release failed (exit code {result.returncode})"


# =============================================================================
# MAIN
# =============================================================================


def main() -> int:
    """Main entry point - unified audit + publish workflow."""
    enable_ansi_support()
    set_output_level(_parse_output_level())

    show_saropa_logo()
    print_colored(f"  Saropa Lints publisher v{SCRIPT_VERSION}", Color.MAGENTA)
    print()

    # --- Find project ---
    project_dir = get_project_dir()
    pubspec_path = project_dir / "pubspec.yaml"
    changelog_path = project_dir / "CHANGELOG.md"

    if not pubspec_path.exists():
        exit_with_error(
            f"pubspec.yaml not found at {pubspec_path}",
            ExitCode.PREREQUISITES_FAILED,
        )

    if not changelog_path.exists():
        exit_with_error(
            f"CHANGELOG.md not found at {changelog_path}",
            ExitCode.PREREQUISITES_FAILED,
        )

    # --- Package info ---
    package_name = get_package_name(pubspec_path)
    version = get_version_from_pubspec(pubspec_path)
    branch = get_current_branch(project_dir)
    remote_url = get_remote_url(project_dir)

    if not re.match(r"^\d+\.\d+\.\d+$", version):
        exit_with_error(
            f"Invalid version format '{version}'.",
            ExitCode.VALIDATION_FAILED,
        )

    # Validate versions in sync
    changelog_version = get_latest_changelog_version(changelog_path)
    if changelog_version is None:
        exit_with_error(
            "Could not extract version from CHANGELOG.md",
            ExitCode.CHANGELOG_FAILED,
        )
    if version != changelog_version:
        exit_with_error(
            f"Version mismatch: pubspec={version}, "
            f"CHANGELOG={changelog_version}",
            ExitCode.CHANGELOG_FAILED,
        )

    print_header("SAROPA LINTS PUBLISHER")
    print_colored("  Package Information:", Color.WHITE)
    print_colored(f"      Name:       {package_name}", Color.CYAN)
    print_colored(f"      Version:    {version}", Color.CYAN)
    print_colored(f"      Tag:        v{version}", Color.CYAN)
    print_colored(f"      Branch:     {branch}", Color.CYAN)
    print_colored(f"      Repository: {remote_url}", Color.CYAN)

    rule_count = count_rules(project_dir)
    category_count = count_categories(project_dir)
    print_colored(
        f"      Rules:      {rule_count} in {category_count} categories",
        Color.CYAN,
    )
    print()

    display_changelog(project_dir)
    display_test_coverage(project_dir)

    # --- Step 0: Pre-publish audits (unless --skip-audit) ---
    audit_only = "--audit-only" in sys.argv
    skip_audit = "--skip-audit" in sys.argv

    if not skip_audit:
        print_header("STEP 0: PRE-PUBLISH AUDIT")
        if not run_pre_publish_audits(project_dir):
            exit_with_error(
                "Pre-publish audit failed. Fix issues before publishing.",
                ExitCode.AUDIT_FAILED,
            )

        if audit_only:
            print_success("Audit complete (--audit-only mode).")
            return ExitCode.SUCCESS.value

        # Gate: ask to continue
        print()
        response = (
            input("  Audit passed. Continue to publish? [Y/n] ")
            .strip()
            .lower()
        )
        if response.startswith("n"):
            print_warning("Publish cancelled by user.")
            return ExitCode.USER_CANCELLED.value
    elif audit_only:
        print_warning("--audit-only and --skip-audit are contradictory.")
        return ExitCode.USER_CANCELLED.value

    # --- Steps 1-13: Publish workflow ---
    if not check_prerequisites():
        exit_with_error("Prerequisites failed", ExitCode.PREREQUISITES_FAILED)

    ok, _ = check_working_tree(project_dir)
    if not ok:
        exit_with_error("Aborted.", ExitCode.USER_CANCELLED)

    if not check_remote_sync(project_dir, branch):
        exit_with_error("Remote sync failed", ExitCode.WORKING_TREE_FAILED)

    if not run_tests(project_dir):
        exit_with_error("Tests failed.", ExitCode.TEST_FAILED)

    if not run_format(project_dir):
        exit_with_error("Formatting failed.", ExitCode.VALIDATION_FAILED)

    if not run_analysis(project_dir):
        exit_with_error("Analysis failed.", ExitCode.ANALYSIS_FAILED)

    ok, release_notes = validate_changelog(project_dir, version)
    if not ok:
        exit_with_error("CHANGELOG failed", ExitCode.CHANGELOG_FAILED)

    if not generate_docs(project_dir):
        exit_with_error("Docs failed", ExitCode.VALIDATION_FAILED)

    if not pre_publish_validation(project_dir):
        exit_with_error("Validation failed", ExitCode.VALIDATION_FAILED)

    # --- Commit, tag, publish, release ---
    if not git_commit_and_push(project_dir, version, branch):
        exit_with_error("Git operations failed", ExitCode.GIT_FAILED)

    if not create_git_tag(project_dir, version):
        exit_with_error("Git tag failed", ExitCode.GIT_FAILED)

    if not publish_to_pubdev_step(project_dir):
        exit_with_error("Publish failed", ExitCode.PUBLISH_FAILED)

    gh_success, gh_error = create_github_release(
        project_dir, version, release_notes
    )

    # --- Success ---
    print()
    print_colored("=" * 70, Color.GREEN)
    print_colored(
        f"  PUBLISHED {package_name} v{version} TO PUB.DEV!", Color.GREEN
    )
    print_colored("=" * 70, Color.GREEN)
    print()

    repo_path = extract_repo_path(remote_url)
    print_colored("  Next steps:", Color.WHITE)
    print_colored(
        f"      Package:  https://pub.dev/packages/{package_name}", Color.CYAN
    )
    print_colored(
        f"      Score:    https://pub.dev/packages/{package_name}/score",
        Color.CYAN,
    )
    print_colored(
        f"      CI:       https://github.com/{repo_path}/actions", Color.CYAN
    )

    if gh_success:
        print_colored(
            f"      Release:  https://github.com/{repo_path}"
            f"/releases/tag/v{version}",
            Color.CYAN,
        )
    else:
        print()
        print_warning(f"GitHub release not created: {gh_error}")

    print()
    try:
        webbrowser.open(f"https://pub.dev/packages/{package_name}")
    except Exception:
        pass

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
