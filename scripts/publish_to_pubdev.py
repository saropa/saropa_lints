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
    Step 8:  Prompt for publish version
    Step 9:  Validate CHANGELOG.md
    Step 10: Generate documentation
    Step 11: Pre-publish validation (dart pub publish --dry-run)
    Step 12: Commit and push
    Step 13: Create git tag
    Step 14: Publish via GitHub Actions
    Step 15: Create GitHub release
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
    10 - User canceled
    11 - Audit failed (tier integrity or duplicates)
"""

from __future__ import annotations

import re
import sys
import time
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
    "modules/_us_spelling.py",
    "modules/_timing.py",
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
        # Python 3.7+ supports reconfigure; older versions raise AttributeError
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    except (AttributeError, OSError):
        pass  # Not available or not writable — fall back to system encoding

    scripts_dir = Path(__file__).resolve().parent
    missing: list[str] = []

    for module_rel in _REQUIRED_MODULES:
        module_path = scripts_dir / module_rel
        if not module_path.exists():  # Module file not found on disk
            missing.append(module_rel)

    if missing:  # At least one required module is missing
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
    display_todo_audit,
    display_unit_test_coverage,
    sync_readme_badges,
)
from scripts.modules._timing import StepTimer
from scripts.modules._version_changelog import (
    _VERSION_RE,
    add_unreleased_section,
    add_version_section,
    display_changelog,
    get_latest_changelog_version,
    get_package_name,
    get_version_from_pubspec,
    increment_version,
    parse_version,
    rename_unreleased_to_version,
    set_version_in_pubspec,
)


# =============================================================================
# OUTPUT LEVEL PARSING
# =============================================================================


def _parse_output_level() -> OutputLevel:
    """Determine output level from CLI args."""
    if "--silent" in sys.argv:  # Suppress all output except errors
        return OutputLevel.SILENT
    if "--warnings-only" in sys.argv:  # Show warnings and errors only
        return OutputLevel.WARNINGS_ONLY
    if "--verbose" in sys.argv:  # Explicitly requested verbose
        return OutputLevel.VERBOSE
    return OutputLevel.VERBOSE  # Default: show everything

# cspell:ignore kbhit getwch
def _prompt_version(default: str, timeout: int = 30) -> str:
    """Prompt for publish version with timeout.

    On Windows the default is pre-filled and editable.
    On Unix it is shown in brackets; press Enter to accept.
    Returns the default after *timeout* seconds of inactivity.
    """
    if sys.platform == "win32":  # Windows: editable pre-filled prompt
        import msvcrt

        sys.stdout.write(f"  Version to publish: {default}")
        sys.stdout.flush()
        buffer = list(default)
        start = time.time()
        while time.time() - start < timeout:  # Poll for keystrokes
            if msvcrt.kbhit():  # Key available
                ch = msvcrt.getwch()
                if ch in ("\r", "\n"):  # Enter pressed — submit
                    print()
                    return "".join(buffer).strip() or default
                if ch == "\x08":  # Backspace — delete last char
                    if buffer:
                        buffer.pop()
                        sys.stdout.write("\b \b")
                        sys.stdout.flush()
                elif ch == "\x03":  # Ctrl+C — abort
                    raise KeyboardInterrupt
                elif ch.isprintable():  # Normal character — append
                    buffer.append(ch)
                    sys.stdout.write(ch)
                    sys.stdout.flush()
            time.sleep(0.05)
        print()
        return "".join(buffer).strip() or default  # Timeout — use buffer

    # Unix: simple readline with select-based timeout
    import select

    sys.stdout.write(f"  Version to publish [{default}]: ")
    sys.stdout.flush()
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if ready:  # User typed something before timeout
        user_input = sys.stdin.readline().strip()
        return user_input if user_input else default
    print()
    return default  # Timeout — use default version


# =============================================================================
# HELPERS
# =============================================================================



def _print_success_banner(
    package_name: str, version: str, repo_path: str,
) -> None:
    """Print final success status with links."""
    print_colored(
        f"  \u2713 PUBLISHED {package_name} v{version}",
        Color.GREEN,
    )
    print()
    print_colored(
        f"      Package:  https://pub.dev/packages/{package_name}",
        Color.CYAN,
    )
    print_colored(
        f"      Score:    https://pub.dev/packages/{package_name}/score",
        Color.CYAN,
    )
    print_colored(
        f"      CI:       https://github.com/{repo_path}/actions",
        Color.CYAN,
    )
    print_colored(
        f"      Release:  https://github.com/{repo_path}"
        f"/releases/tag/v{version}",
        Color.CYAN,
    )
    print()
    print_colored("  Add to your pubspec.yaml:", Color.DIM)
    print()
    print_colored("      dev_dependencies:", Color.WHITE)
    print_colored(
        f"        {package_name}: ^{version}",
        Color.WHITE,
    )
    print()


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
    bugs_dir = project_dir / "bugs"

    if not pubspec_path.exists():  # Can't publish without a pubspec
        exit_with_error(
            f"pubspec.yaml not found at {pubspec_path}",
            ExitCode.PREREQUISITES_FAILED,
        )

    if not changelog_path.exists():  # CHANGELOG is mandatory for releases
        exit_with_error(
            f"CHANGELOG.md not found at {changelog_path}",
            ExitCode.PREREQUISITES_FAILED,
        )

    # --- Quick-exit: --fix-docs (standalone mode, exits after fixing) ---
    if "--fix-docs" in sys.argv:
        print_header("FIX DOC COMMENT ISSUES")
        issues = check_pubdev_lint_issues(project_dir)
        if not issues:  # Clean — nothing to fix
            print_success("No doc comment issues found.")
            return ExitCode.SUCCESS.value
        print_info(f"Found {len(issues)} issue(s):")
        for issue in issues:
            print_colored(f"      {issue}", Color.YELLOW)
        fixed_brackets = fix_doc_angle_brackets(project_dir)
        fixed_refs = fix_doc_references(project_dir)
        total_fixed = fixed_brackets + fixed_refs
        if total_fixed:  # Some issues were auto-fixable
            print_success(
                f"Fixed {total_fixed} issue(s) "
                f"({fixed_brackets} angle bracket(s), "
                f"{fixed_refs} doc reference(s))."
            )
        else:  # Issues exist but none are auto-fixable
            print_warning("No auto-fixable issues found.")
        return ExitCode.SUCCESS.value

    # --- Package info (basic, version-independent) ---
    package_name = get_package_name(pubspec_path)
    pubspec_version = get_version_from_pubspec(pubspec_path)
    branch = get_current_branch(project_dir)
    remote_url = get_remote_url(project_dir)
    rule_count = count_rules(project_dir)
    category_count = count_categories(project_dir)

    print_header(f"SAROPA LINTS PUBLISHER v{SCRIPT_VERSION}")
    print_colored("  Package Information:", Color.WHITE)
    print_colored(f"      Name:       {package_name}", Color.CYAN)
    print_colored(f"      Current:    {pubspec_version}", Color.CYAN)
    print_colored(f"      Branch:     {branch}", Color.CYAN)
    print_colored(f"      Repository: {remote_url}", Color.CYAN)
    print_colored(
        f"      Rules:      {rule_count} in {category_count} categories",
        Color.CYAN,
    )
    print()

    display_changelog(project_dir)
    display_test_coverage(project_dir)
    display_unit_test_coverage(project_dir)
    display_todo_audit(project_dir)
    display_roadmap_summary(project_dir, bugs_dir=bugs_dir)

    # --- Timed workflow ---
    audit_only = "--audit-only" in sys.argv
    skip_audit = "--skip-audit" in sys.argv
    timer = StepTimer()
    exit_code = ExitCode.SUCCESS.value
    version = pubspec_version
    release_notes = ""
    succeeded = False

    try:
        # --- Step 1: Pre-publish audits (unless --skip-audit) ---
        if not skip_audit:  # Normal path: run full audit
            with timer.step("Pre-publish audit"):
                print_header("STEP 1: PRE-PUBLISH AUDIT")
                if not run_pre_publish_audits(project_dir):  # Blocking issue
                    exit_with_error(
                        "Pre-publish audit failed. "
                        "Fix issues before publishing.",
                        ExitCode.AUDIT_FAILED,
                    )

            if audit_only:  # --audit-only: stop after audit, don't publish
                print_success("Audit complete (--audit-only mode).")
                succeeded = True
                return ExitCode.SUCCESS.value

            # Gate: user must confirm before starting the publish workflow
            print()
            response = (
                input("  Audit passed. Continue to publish? [Y/n] ")
                .strip()
                .lower()
            )
            if response.startswith("n"):  # User declined to continue
                print_warning("Publish canceled by user.")
                return ExitCode.USER_CANCELED.value
        elif audit_only:  # --skip-audit + --audit-only = nonsensical
            print_warning(
                "--audit-only and --skip-audit are contradictory."
            )
            return ExitCode.USER_CANCELED.value

        # --- Steps 2-7: Pre-publish analysis workflow ---
        with timer.step("Prerequisites"):  # Step 2: flutter, git, gh
            if not check_prerequisites():  # Missing required tool
                exit_with_error(
                    "Prerequisites failed",
                    ExitCode.PREREQUISITES_FAILED,
                )

        with timer.step("Working tree"):  # Step 3: uncommitted changes
            ok, _ = check_working_tree(project_dir)
            if not ok:  # User declined to include uncommitted changes
                exit_with_error("Aborted.", ExitCode.USER_CANCELED)

        with timer.step("Remote sync"):  # Step 4: local/remote in sync
            if not check_remote_sync(project_dir, branch):  # Sync failed
                exit_with_error(
                    "Remote sync failed",
                    ExitCode.WORKING_TREE_FAILED,
                )

        with timer.step("Tests"):  # Step 5: dart test
            if not run_tests(project_dir):  # Test failure
                exit_with_error("Tests failed.", ExitCode.TEST_FAILED)

        with timer.step("Format"):  # Step 6: dart format
            if not run_format(project_dir):  # Format error
                exit_with_error(
                    "Formatting failed.", ExitCode.VALIDATION_FAILED,
                )

        with timer.step("Analysis"):  # Step 7: dart analyze --fatal-infos
            if not run_analysis(project_dir):  # Analysis error
                exit_with_error(
                    "Analysis failed.", ExitCode.ANALYSIS_FAILED,
                )

        # --- Step 8: Version prompt (interactive, not timed) ---
        print_header("VERSION")
        if tag_exists_on_remote(project_dir, f"v{pubspec_version}"):
            # Current version already published — suggest next patch
            default_version = increment_version(pubspec_version)
        else:
            # Current version not yet published — offer it as default
            default_version = pubspec_version

        while True:  # Loop until valid version format entered
            version = _prompt_version(default_version)
            if re.match(rf"^{_VERSION_RE}$", version):  # Valid semver
                break
            print_warning(  # Invalid format — prompt again
                f"Invalid version format '{version}'. "
                f"Use X.Y.Z or X.Y.Z-pre.N"
            )

        with timer.step("Version sync"):  # Align pubspec, CHANGELOG, tag
            if version != pubspec_version:  # User chose a different version
                set_version_in_pubspec(pubspec_path, version)
                print_success(f"Updated pubspec.yaml to {version}")

            # Rename [Unreleased] to this version in CHANGELOG
            try:
                if rename_unreleased_to_version(changelog_path, version):
                    print_success(
                        f"Renamed [Unreleased] to [{version}] "
                        f"in CHANGELOG.md"
                    )
            except ValueError as exc:  # Malformed CHANGELOG
                exit_with_error(
                    str(exc), ExitCode.CHANGELOG_FAILED,
                )

            # Validate pubspec and CHANGELOG versions match
            changelog_version = get_latest_changelog_version(
                changelog_path,
            )
            if changelog_version is None:  # No version found in CHANGELOG
                exit_with_error(
                    "Could not extract version from CHANGELOG.md",
                    ExitCode.CHANGELOG_FAILED,
                )
            if version != changelog_version:  # Version mismatch
                if parse_version(version) < parse_version(
                    changelog_version,
                ):
                    # Pubspec behind CHANGELOG — auto-update pubspec
                    print_warning(
                        f"pubspec version ({version}) is behind "
                        f"CHANGELOG ({changelog_version}). "
                        f"Updating pubspec..."
                    )
                    set_version_in_pubspec(
                        pubspec_path, changelog_version,
                    )
                    version = changelog_version
                    print_success(
                        f"Updated pubspec.yaml to {version}"
                    )
                else:
                    # Pubspec ahead of CHANGELOG — offer to add section
                    print_warning(
                        f"pubspec version ({version}) is ahead "
                        f"of CHANGELOG ({changelog_version})."
                    )
                    response = (
                        input(
                            f"  Add a [{version}] section to "
                            f"CHANGELOG.md? [Y/n] "
                        )
                        .strip()
                        .lower()
                    )
                    if response.startswith("n"):  # User wants manual fix
                        exit_with_error(
                            "Publish canceled — update "
                            "CHANGELOG.md manually.",
                            ExitCode.CHANGELOG_FAILED,
                        )
                    add_version_section(
                        changelog_path, version, "Version bump",
                    )
                    print_success(
                        f"Added [{version}] section to "
                        f"CHANGELOG.md"
                    )

            # Fail fast if version already published
            tag_name = f"v{version}"
            if tag_exists_on_remote(project_dir, tag_name):
                exit_with_error(
                    f"Tag {tag_name} already exists on remote. "
                    f"Version {version} has already been published.",
                    ExitCode.GIT_FAILED,
                )

        print_colored(
            f"      Publishing: {version}", Color.CYAN,
        )
        print_colored(f"      Tag:        v{version}", Color.CYAN)
        print()

        # --- Steps 9-11: Version-dependent validation ---
        with timer.step("Badge sync"):  # Step 9: update README badges
            sync_readme_badges(project_dir, version, rule_count)

        with timer.step("CHANGELOG validation"):  # Step 10: extract notes
            ok, release_notes = validate_changelog(
                project_dir, version,
            )
            if not ok:  # Version missing or empty in CHANGELOG
                exit_with_error(
                    "CHANGELOG failed", ExitCode.CHANGELOG_FAILED,
                )

        with timer.step("Docs"):  # Step 11: dart doc
            if not generate_docs(project_dir):  # Doc generation error
                exit_with_error(
                    "Docs failed", ExitCode.VALIDATION_FAILED,
                )

        with timer.step("Pre-publish validation"):  # dart pub publish --dry-run
            if not pre_publish_validation(project_dir):  # Would fail on pub.dev
                exit_with_error(
                    "Validation failed", ExitCode.VALIDATION_FAILED,
                )

        # --- Final CI gate: re-check after version bump changed files ---
        with timer.step("Final CI gate"):
            print_header("FINAL CI GATE")
            print_info(
                "Re-running CI checks after version changes to "
                "prevent burning a tag on a broken build..."
            )
            if not run_analysis(project_dir):  # Post-bump analysis failure
                exit_with_error(
                    "Final CI gate failed \u2014 aborting before "
                    "tag creation. Fix analysis issues and re-run.",
                    ExitCode.ANALYSIS_FAILED,
                )
            print_success("CI gate passed \u2014 safe to create tag")

        # --- Commit, tag, publish, release ---
        with timer.step("Git commit & push"):  # Stage and push all changes
            if not git_commit_and_push(
                project_dir, version, branch,
            ):
                exit_with_error(
                    "Git operations failed", ExitCode.GIT_FAILED,
                )

        with timer.step("Git tag"):  # Create vX.Y.Z tag
            if not create_git_tag(project_dir, version):
                exit_with_error(
                    "Git tag failed", ExitCode.GIT_FAILED,
                )

        with timer.step("Publish"):  # dart pub publish to pub.dev
            if not publish_to_pubdev_step(project_dir, version):
                exit_with_error(
                    "Publish failed", ExitCode.PUBLISH_FAILED,
                )

        with timer.step("GitHub release"):  # Create GH release with notes
            gh_success, gh_error = create_github_release(
                project_dir, version, release_notes,
            )
            if not gh_success:  # GH CLI or auth failure
                exit_with_error(
                    f"GitHub release failed: {gh_error}",
                    ExitCode.GITHUB_RELEASE_FAILED,
                )

        succeeded = True

        # --- Post-publish: bump version for next dev cycle ---
        try:
            with timer.step("Version bump"):
                next_version = increment_version(version)
                set_version_in_pubspec(pubspec_path, next_version)
                add_unreleased_section(changelog_path)
                if post_publish_commit(
                    project_dir, next_version, branch,
                ):  # Commit succeeded
                    print_success(
                        f"Bumped to {next_version} with "
                        f"[Unreleased] section"
                    )
                else:  # Commit failed (non-fatal)
                    print_warning(
                        f"Version bump to {next_version} "
                        f"not committed \u2014 commit manually"
                    )
        except Exception as exc:  # Version bump is best-effort
            print_warning(f"Post-publish version bump failed: {exc}")

        # --- Post-publish: open pub.dev page (convenience) ---
        try:
            webbrowser.open(
                f"https://pub.dev/packages/{package_name}",
            )
        except Exception:
            pass  # Browser open is non-critical

    except SystemExit as exc:  # Caught from exit_with_error() calls
        exit_code = exc.code if isinstance(exc.code, int) else 1

    finally:  # Always show timing summary, even on failure
        timer.print_summary()

    # Final status banner (always the last output)
    if succeeded:  # Publish completed successfully
        repo_path = extract_repo_path(remote_url)
        _print_success_banner(package_name, version, repo_path)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
