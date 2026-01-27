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
    --fix-docs        Auto-fix doc comment issues (angle brackets, refs), then exit
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
    "modules/__init__.py",
    "modules/_utils.py",
    "modules/_audit_checks.py",
    "modules/_audit_dx.py",
    "modules/_audit.py",
    "modules/_tier_integrity.py",
    "modules/_git_ops.py",
    "modules/_pubdev_lint.py",
    "modules/_rule_metrics.py",
    "modules/_version_changelog.py",
]


def check_modules_exist() -> bool:
    """Verify all required module files exist before importing.

    This runs BEFORE any module imports so the user gets a clear
    error message instead of a Python ImportError traceback.

    Uses ASCII-only output since enable_ansi_support() hasn't run yet.

    Returns:
        True if all modules found, False otherwise.
    """
    # Reconfigure stdout to UTF-8 early (Windows cp1252 can't print Unicode)
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass

    scripts_dir = Path(__file__).resolve().parent
    all_found = True

    for module_rel in _REQUIRED_MODULES:
        module_path = scripts_dir / module_rel
        if module_path.exists():
            print(f"  [OK] Module found: {module_rel}")
        else:
            print(f"  [MISSING] Module MISSING: {module_rel}")
            all_found = False

    if not all_found:
        print()
        print("  ERROR: Required modules are missing from scripts/modules/.")
        print("  Ensure the following files exist:")
        for m in _REQUIRED_MODULES:
            print(f"    scripts/{m}")

    return all_found


# =============================================================================
# EARLY GATE: Check modules before importing anything from them
# =============================================================================

if not check_modules_exist():
    sys.exit(1)


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
    print_success,
    print_warning,
    run_command,
    set_output_level,
    show_saropa_logo,
)
from scripts.modules._git_ops import (
    create_git_tag,
    create_github_release,
    extract_repo_path,
    get_current_branch,
    get_remote_url,
    git_commit_and_push,
    publish_to_pubdev_step,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
from scripts.modules._rule_metrics import (
    count_categories,
    count_rules,
    display_test_coverage,
    sync_readme_badges,
)
from scripts.modules._version_changelog import (
    display_changelog,
    get_latest_changelog_version,
    get_package_name,
    get_version_from_pubspec,
    validate_changelog_version,
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


def run_analysis(project_dir: Path) -> bool:
    """Step 6: Run static analysis."""
    print_header("STEP 6: RUNNING STATIC ANALYSIS")

    print_info("Checking for pub.dev lint issues...")
    pubdev_issues = check_pubdev_lint_issues(project_dir)
    if pubdev_issues:
        print_warning(f"Found {len(pubdev_issues)} pub.dev lint issue(s):")
        for issue in pubdev_issues:
            print_colored(f"      {issue}", Color.YELLOW)

        # Auto-fix doc comment issues
        print_info("Auto-fixing doc comment issues...")
        fixed_brackets = fix_doc_angle_brackets(project_dir)
        fixed_refs = fix_doc_references(project_dir)
        total_fixed = fixed_brackets + fixed_refs

        if total_fixed:
            print_success(
                f"Auto-fixed {total_fixed} issue(s) "
                f"({fixed_brackets} angle bracket(s), "
                f"{fixed_refs} doc reference(s))."
            )

        # Re-check for remaining issues
        remaining = check_pubdev_lint_issues(project_dir)
        if remaining:
            print_error(
                f"{len(remaining)} unfixable pub.dev lint issue(s) remain:"
            )
            for issue in remaining:
                print_colored(f"      {issue}", Color.YELLOW)
            return False

        print_success("All pub.dev lint issues resolved")
    else:
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
        print_success("Package validated successfully")
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

    # --- Quick-exit: --fix-docs ---
    if "--fix-docs" in sys.argv:
        print_header("FIX DOC COMMENT ISSUES")
        issues = check_pubdev_lint_issues(project_dir)
        if not issues:
            print_success("No doc comment issues found.")
            return ExitCode.SUCCESS.value
        print_info(f"Found {len(issues)} issue(s):")
        for issue in issues:
            print_colored(f"      {issue}", Color.YELLOW)
        fixed_brackets = fix_doc_angle_brackets(project_dir)
        fixed_refs = fix_doc_references(project_dir)
        total_fixed = fixed_brackets + fixed_refs
        if total_fixed:
            print_success(
                f"Fixed {total_fixed} issue(s) "
                f"({fixed_brackets} angle bracket(s), "
                f"{fixed_refs} doc reference(s))."
            )
        else:
            print_warning("No auto-fixable issues found.")
        return ExitCode.SUCCESS.value

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

    sync_readme_badges(project_dir, version, rule_count)

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
