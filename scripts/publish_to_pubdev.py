#!/usr/bin/env python3
"""
Publish saropa_lints package to pub.dev and create GitHub release.

This is the SINGLE ENTRY POINT for the complete release workflow.
It gates publishing behind comprehensive audit checks, including
tier integrity verification.

Workflow:
    Step 1:  Pre-publish audit (tier integrity, duplicates, quality checks)
    Step 2:  Check prerequisites (flutter, git, gh)
    Step 3:  Validate working tree
    Step 4:  Check remote sync
    Step 5:  Run tests
    Step 6:  Format code
    Step 7:  Run static analysis
    Step 8:  Validate CHANGELOG.md
    Step 9:  Generate documentation
    Step 10: Pre-publish validation (dart pub publish --dry-run)
    Step 11: Commit and push
    Step 12: Create git tag
    Step 13: Publish via GitHub Actions
    Step 14: Create GitHub release
    Post:    Bump version for next cycle (pubspec + [Unreleased])

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
    "modules/_publish_steps.py",
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
    missing: list[str] = []

    for module_rel in _REQUIRED_MODULES:
        module_path = scripts_dir / module_rel
        if not module_path.exists():
            missing.append(module_rel)

    if missing:
        for m in missing:
            print(f"  [MISSING] Module MISSING: {m}")
        print()
        print("  ERROR: Required modules are missing from scripts/modules/.")
        print("  Ensure the following files exist:")
        for m in missing:
            print(f"    scripts/{m}")
        return False

    return True


# =============================================================================
# EARLY GATE: Check modules before importing anything from them
# =============================================================================

if not check_modules_exist():
    sys.exit(1)


from scripts.modules._utils import (
    Color,
    ExitCode,
    OutputLevel,
    enable_ansi_support,
    exit_with_error,
    get_project_dir,
    print_colored,
    print_header,
    print_info,
    print_success,
    print_warning,
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
    post_publish_commit,
    publish_to_pubdev_step,
    tag_exists_on_remote,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
from scripts.modules._publish_steps import (
    check_prerequisites,
    check_remote_sync,
    check_working_tree,
    generate_docs,
    pre_publish_validation,
    run_analysis,
    run_format,
    run_pre_publish_audits,
    run_tests,
    validate_changelog,
)
from scripts.modules._rule_metrics import (
    count_categories,
    count_rules,
    display_roadmap_summary,
    display_test_coverage,
    sync_readme_badges,
)
from scripts.modules._version_changelog import (
    add_unreleased_section,
    display_changelog,
    get_latest_changelog_version,
    get_package_name,
    get_version_from_pubspec,
    increment_patch_version,
    parse_version,
    rename_unreleased_to_version,
    set_version_in_pubspec,
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
# MAIN
# =============================================================================


def main() -> int:
    """Main entry point - unified audit + publish workflow."""
    enable_ansi_support()
    set_output_level(_parse_output_level())

    show_saropa_logo()

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

    # Rename [Unreleased] to this version before validation
    try:
        if rename_unreleased_to_version(changelog_path, version):
            print_success(
                f"Renamed [Unreleased] to [{version}] in CHANGELOG.md"
            )
    except ValueError as exc:
        exit_with_error(str(exc), ExitCode.CHANGELOG_FAILED)

    # Validate versions in sync
    changelog_version = get_latest_changelog_version(changelog_path)
    if changelog_version is None:
        exit_with_error(
            "Could not extract version from CHANGELOG.md",
            ExitCode.CHANGELOG_FAILED,
        )
    if version != changelog_version:
        if parse_version(version) < parse_version(changelog_version):
            print_warning(
                f"pubspec version ({version}) is behind "
                f"CHANGELOG ({changelog_version}). Updating pubspec..."
            )
            set_version_in_pubspec(pubspec_path, changelog_version)
            version = changelog_version
            print_success(f"Updated pubspec.yaml to {version}")
        else:
            exit_with_error(
                f"Version mismatch: pubspec={version} is ahead of "
                f"CHANGELOG={changelog_version}. Update CHANGELOG.md first.",
                ExitCode.CHANGELOG_FAILED,
            )

    # Early check: fail fast if this version is already published
    tag_name = f"v{version}"
    if tag_exists_on_remote(project_dir, tag_name):
        exit_with_error(
            f"Tag {tag_name} already exists on remote. "
            f"Version {version} has already been published.",
            ExitCode.GIT_FAILED,
        )

    print_header(f"SAROPA LINTS PUBLISHER v{SCRIPT_VERSION}")
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
    display_roadmap_summary(project_dir)

    # --- Step 1: Pre-publish audits (unless --skip-audit) ---
    audit_only = "--audit-only" in sys.argv
    skip_audit = "--skip-audit" in sys.argv

    if not skip_audit:
        print_header("STEP 1: PRE-PUBLISH AUDIT")
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

    # --- Steps 2-10: Publish workflow ---
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

    # --- Post-publish: bump pubspec version for next cycle ---
    next_version = increment_patch_version(version)
    print_header(f"POST-PUBLISH: BUMPING VERSION TO {next_version}")

    set_version_in_pubspec(pubspec_path, next_version)
    print_success(f"Updated pubspec.yaml to {next_version}")

    if add_unreleased_section(changelog_path):
        print_success("Added [Unreleased] section to CHANGELOG.md")

    if post_publish_commit(project_dir, next_version, branch):
        print_success(
            f"Committed and pushed version bump to {next_version}"
        )
    else:
        print_warning(
            f"Could not commit version bump to {next_version}. "
            f"Manually commit pubspec.yaml and CHANGELOG.md."
        )

    print()
    try:
        webbrowser.open(f"https://pub.dev/packages/{package_name}")
    except Exception:
        pass

    return ExitCode.SUCCESS.value


if __name__ == "__main__":
    sys.exit(main())
