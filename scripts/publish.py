#!/usr/bin/env python3
"""
Publish saropa_lints package to pub.dev and create GitHub release.

This is the SINGLE ENTRY POINT for the complete release workflow
(package to pub.dev and VS Code extension). Package and extension
are intrinsically linked; both are driven from this script.

Workflow:
    Step 1:  Pre-publish audit (tier integrity, duplicates, quality checks)
    Step 2:  Check prerequisites (flutter, git, gh)
    Step 3:  Validate working tree
    Step 4:  Check remote sync
    Step 4.5: Commit and push .github/workflows/publish.yml if changed (no manual git)
    Step 5:  Run tests
    Step 6:  Format code
    Step 7:  Run static analysis
    Step 8:  Prompt for publish version
    Step 9:  Validate CHANGELOG.md
    Step 10: Generate documentation
    Step 11: Pre-publish validation (dart pub publish --dry-run)
    Step 12: Commit and push (if no changes, strip 2nd/3rd party attribution from HEAD)
    Step 13: Create git tag
    Step 14: Publish via GitHub Actions
    Step 15: Create GitHub release
    Step 16: Extension: sync version, package .vsix, optionally publish (Marketplace + Open VSX)
    Post:    Bump version for next cycle (pubspec + [Unreleased])

Run from project root: python scripts/publish.py. Prompts: full publish /
audit only / fix doc comments / publish without audit / analyze only /
extension only. No flags. Other logic is in scripts/modules/
(audit, DX improver, retrigger CI); run standalone with e.g.
python -m scripts.modules._improve_dx_messages if needed. Historical scripts
(version_rules, release-note scrapers, lint candidates) are in
scripts/historical/ and are not part of the build.

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

import json
import re
import sys
import time
import webbrowser
from pathlib import Path

# Allow running as `python scripts/publish.py` from project root (add parent to path)
_scripts_parent = str(Path(__file__).resolve().parent.parent)
if _scripts_parent not in sys.path:
    sys.path.insert(0, _scripts_parent)


SCRIPT_VERSION = "4.0"

# Shown when audit fails with no auto-fix (e.g. tier integrity or duplicate rule names)
_AUDIT_FAILED_MSG = (
    "Pre-publish audit failed. Fix the blocking issue(s) "
    "marked with ✗ above and re-run."
)


# =============================================================================
# MODULE CHECK (runs before any module imports)

# =============================================================================

# Modules under scripts/modules/ that must exist before any of them are imported
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
    "modules/_roadmap_implemented.py",
    "modules/_duplicated_messages.py",
    "modules/_extension_publish.py",
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
        # At least one required module missing; caller will exit with code 1
        return False

    # All required modules present; safe to import
    return True


# =============================================================================
# EARLY GATE: Check modules before importing anything from them
# =============================================================================

if not check_modules_exist():
    sys.exit(1)

# Import publish workflow modules (all required files verified above)

# Colors, exit codes, output level, project dir, and logo from shared utils
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

# Git tag, GitHub release, commit/push, remote URL, and tag-exists check
from scripts.modules._git_ops import (
    create_git_tag,
    create_github_release,
    ensure_publish_workflow_committed,
    extract_repo_path,
    get_current_branch,
    get_remote_url,
    git_commit_and_push,
    post_publish_commit,
    publish_to_pubdev_step,
    tag_exists_on_remote,
)

# Pub.dev doc-comment lint: issue check and auto-fix for angle brackets and refs
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)

# Prerequisites, working tree, remote sync, format, analysis, tests, audit, docs, validation
from scripts.modules._publish_steps import (
    check_prerequisites,
    check_remote_sync,
    check_working_tree,
    generate_docs,
    pre_publish_validation,
    run_analysis,
    run_analyze_to_log,
    run_format,
    run_pre_publish_audits,
    run_tests,
    validate_changelog,
)

# Rule/category counts, roadmap summary, test coverage display, README badge sync
from scripts.modules._rule_metrics import (
    count_categories,
    count_rules,
    display_roadmap_summary,
    display_test_coverage,
    sync_readme_badges,
)

# Extension: sync version, package .vsix, publish to Marketplace/Open VSX
from scripts.modules._extension_publish import (
    extension_exists,
    install_extension,
    package_extension,
    publish_extension,
    set_extension_version,
)
# Step timing and summary display
from scripts.modules._timing import StepTimer
# Version regex, pubspec/changelog read/write, version parse/increment, display
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
    """Return default output level (verbose). No CLI flags."""
    # Script has no CLI flags; always verbose
    return OutputLevel.VERBOSE


# cspell:ignore kbhit getwch
def _prompt_version(default: str, timeout: int = 30) -> str:
    """Prompt for publish version with timeout.

    On Windows the default is pre-filled and editable.
    On Unix it is shown in brackets; press Enter to accept.
    Returns the default after *timeout* seconds of inactivity.
    """
    if sys.platform == "win32":
        # Windows: editable pre-filled prompt (no readline with prefill on Windows)
        import msvcrt

        sys.stdout.write(f"  Version to publish: {default}")
        sys.stdout.flush()
        buffer = list(default)
        start = time.time()
        while time.time() - start < timeout:
            if msvcrt.kbhit():
                ch = msvcrt.getwch()
                if ch in ("\r", "\n"):
                    print()
                    # Enter: submit current buffer or default
                    return "".join(buffer).strip() or default
                if ch == "\x08":  # Backspace
                    if buffer:
                        buffer.pop()
                        sys.stdout.write("\b \b")
                        sys.stdout.flush()
                elif ch == "\x03":  # Ctrl+C
                    raise KeyboardInterrupt
                elif ch.isprintable():
                    buffer.append(ch)
                    sys.stdout.write(ch)
                    sys.stdout.flush()
            time.sleep(0.05)
        print()
        # Timeout: submit current buffer or default
        return "".join(buffer).strip() or default

    # Unix: readline with select-based timeout; [default] shown in brackets
    import select

    sys.stdout.write(f"  Version to publish [{default}]: ")
    sys.stdout.flush()
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if ready:
        user_input = sys.stdin.readline().strip()
        # User entered something; use it or default
        return user_input if user_input else default
    print()
    # Timeout: use default version
    return default


# =============================================================================
# HELPERS
# =============================================================================


def _get_extension_identity(project_dir: Path) -> tuple[str, str]:
    """Read publisher and name from extension/package.json.

    Returns (publisher, name) or ('', '') if unavailable.
    """
    pkg_json = project_dir / "extension" / "package.json"
    if not pkg_json.is_file():
        return ("", "")
    try:
        data = json.loads(pkg_json.read_text(encoding="utf-8"))
        return (data.get("publisher", ""), data.get("name", ""))
    except (json.JSONDecodeError, OSError):
        return ("", "")


def _print_success_banner(
    package_name: str, version: str, repo_path: str,
    publisher: str, extension_name: str,
    extension_published: bool,
) -> None:
    """Print final success banner with pub.dev, CI, release, and store URLs plus pubspec snippet."""
    print_colored(
        f"  \u2713 PUBLISHED {package_name} v{version}",
        Color.GREEN,
    )
    print()
    print_colored(
        f"      Package:      https://pub.dev/packages/{package_name}",
        Color.CYAN,
    )
    print_colored(
        f"      Score:        https://pub.dev/packages/{package_name}/score",
        Color.CYAN,
    )
    print_colored(
        f"      CI:           https://github.com/{repo_path}/actions",
        Color.CYAN,
    )
    print_colored(
        f"      Release:      https://github.com/{repo_path}"
        f"/releases/tag/v{version}",
        Color.CYAN,
    )
    # Store links only shown when the extension was actually published
    if extension_published and publisher and extension_name:
        print_colored(
            f"      Marketplace:  https://marketplace.visualstudio.com"
            f"/items?itemName={publisher}.{extension_name}",
            Color.CYAN,
        )
        print_colored(
            f"      Open VSX:     https://open-vsx.org"
            f"/extension/{publisher}/{extension_name}",
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


def _prompt_publish_mode() -> str:
    """Ask user for run mode: full publish, audit only, fix docs, or publish without audit."""
    print_header("PUBLISH OPTIONS")
    print(
        "  1) Full publish (audit → format → analysis → tests → version → release)"
    )
    print("  2) Audit only (tier integrity, DX checks; no publish)")
    print("  3) Fix doc comments (angle brackets, refs; then exit)")
    print("  4) Publish without audit (skip audit; format → analysis → tests → release)")
    print("  5) Analyze only (run dart analyze, write log; then exit)")
    print("  6) Extension only (package .vsix, optionally publish to Marketplace/Open VSX)")
    try:
        raw = input("  Choice [1]: ").strip() or "1"
        n = int(raw)
        if n == 2:
            return "audit_only"
        if n == 3:
            return "fix_docs"
        if n == 4:
            return "full_skip_audit"
        if n == 5:
            return "analyze_only"
        if n == 6:
            return "extension_only"
    except (ValueError, EOFError, KeyboardInterrupt):
        pass
    # Default or invalid input: full publish
    return "full"


def main(
    mode: str = "full",
    output_level: OutputLevel | None = None,
) -> int:
    """Run publish workflow. Returns exit code (0 = success). mode: 'full' | 'audit_only' | 'fix_docs' | 'full_skip_audit' | 'analyze_only' | 'extension_only'."""
    enable_ansi_support()
    set_output_level(output_level or _parse_output_level())

    show_saropa_logo()

    # --- Resolve project paths and validate presence of pubspec/CHANGELOG ---
    project_dir = get_project_dir()
    pubspec_path = project_dir / "pubspec.yaml"
    changelog_path = project_dir / "CHANGELOG.md"
    bugs_dir = project_dir / "bugs"

    # Abort if pubspec or CHANGELOG missing (required for publish)
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

    # --- analyze_only: standalone mode, then exit ---
    if mode == "analyze_only":
        ok = run_analyze_to_log(project_dir)
        return ExitCode.SUCCESS.value if ok else ExitCode.ANALYSIS_FAILED.value

    # --- extension_only: package .vsix, optionally publish, then exit ---
    if mode == "extension_only":
        if not extension_exists(project_dir):
            exit_with_error(
                f"Extension directory not found: {project_dir / 'extension'}",
                ExitCode.PREREQUISITES_FAILED,
            )
        ext_version = get_version_from_pubspec(pubspec_path)
        print_header("EXTENSION: PACKAGE .VSIX")
        vsix = package_extension(project_dir, ext_version)
        if not vsix:
            exit_with_error(
                "Extension package failed",
                ExitCode.VALIDATION_FAILED,
            )
        # Install locally (default yes)
        response = (
            input("  Install extension locally? [Y/n] ")
            .strip()
            .lower()
        )
        if not response.startswith("n"):
            install_extension(vsix)
        # Publish to stores (default no)
        response = (
            input(
                "  Publish extension to Marketplace and Open VSX? [y/N] "
            )
            .strip()
            .lower()
        )
        if response.startswith("y"):
            if not publish_extension(project_dir, vsix):
                exit_with_error(
                    "Extension publish failed",
                    ExitCode.PUBLISH_FAILED,
                )
        return ExitCode.SUCCESS.value

    # --- fix_docs: standalone mode, then exit ---
    if mode == "fix_docs":
        print_header("FIX DOC COMMENT ISSUES")
        issues = check_pubdev_lint_issues(project_dir)
        if not issues:
            print_success("No doc comment issues found.")
            # fix_docs mode: nothing to fix, exit success
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
        else:
            print_warning("No auto-fixable issues found.")
        # fix_docs mode: done (fixed or not), exit success
        return ExitCode.SUCCESS.value

    # --- Show package info (name, current version, branch, rule/category counts) ---
    # Fields used for banner, version prompt, and release
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
    todo_log = display_roadmap_summary(project_dir, bugs_dir=bugs_dir)
    if todo_log:
        print_info(f"TODO log: {todo_log.relative_to(project_dir)}")

    # --- Timed workflow: audit (optional), then prerequisites → format → analysis → tests ---
    # Fields: mode flags, timer, exit code, version/release_notes (set later), success flag
    audit_only = mode == "audit_only"
    skip_audit = mode == "full_skip_audit"
    timer = StepTimer()
    exit_code = ExitCode.SUCCESS.value
    version = pubspec_version
    release_notes = ""
    succeeded = False
    extension_published = False

    try:
        # --- Step 1: Pre-publish audits (tier integrity, duplicates, DX; skip if full_skip_audit) ---
        if not skip_audit:
            # Timed step: run tier integrity, duplicates, DX checks; retry if prefix fix applied
            with timer.step("Pre-publish audit"):
                print_header("STEP 1: AUDIT")
                # audit_ok: True if all checks passed; audit_result: details for auto-fix or error
                audit_ok, audit_result = run_pre_publish_audits(project_dir)
                while not audit_ok and audit_result:
                    rules_dir = project_dir / "lib" / "src" / "rules"
                    missing_prefix = getattr(
                        audit_result, "rules_missing_prefix", None
                    )
                    if missing_prefix:
                        # Lazy import: fix missing [rule_name] prefix in rule problem messages
                        from scripts.modules._audit_checks import fix_missing_prefix

                        n = fix_missing_prefix(rules_dir)
                        if n:
                            print_success(
                                f"Added [rule_name] prefix to {n} rule(s)."
                            )
                            print_info("Re-running audit...")
                            audit_ok, audit_result = run_pre_publish_audits(
                                project_dir
                            )
                            if audit_ok:
                                break
                            continue
                    # No auto-fix (e.g. tier/duplicate error): show message and exit
                    exit_with_error(
                        _AUDIT_FAILED_MSG,
                        ExitCode.AUDIT_FAILED,
                    )
                if not audit_ok:
                    exit_with_error(_AUDIT_FAILED_MSG, ExitCode.AUDIT_FAILED)

            if audit_only:
                print_success("Audit-only run complete (no format/analysis/tests).")
                succeeded = True
                # Audit-only: stop here, do not run format/analysis/tests
                return ExitCode.SUCCESS.value

            # Gate: user must confirm before format/analysis/tests (commented out)
            # print()
            # response = (
            #     input(
            #         "  Audit step done. Continue to format, analysis, and tests? [Y/n] "
            #     )
            #     .strip()
            #     .lower()
            # )
            # if response.startswith("n"):  # User declined to continue
            #     print_warning("Publish canceled by user.")
            #     return ExitCode.USER_CANCELED.value
        elif audit_only:
            # audit_only but skip_audit was true (invalid combination)
            return ExitCode.USER_CANCELED.value

        if skip_audit:
            print_warning("Audit skipped (publish without audit).")

        # --- Steps 2-7: Pre-publish analysis workflow ---
        # Timed step: ensure flutter, git, gh are available
        with timer.step("Prerequisites"):
            if not check_prerequisites():  # Missing required tool
                exit_with_error(
                    "Prerequisites failed",
                    ExitCode.PREREQUISITES_FAILED,
                )

        # Timed step: ensure working tree clean or user confirms uncommitted changes
        with timer.step("Working tree"):
            # ok: True if clean or user chose to continue with changes
            ok, _ = check_working_tree(project_dir)
            if not ok:
                exit_with_error("Aborted.", ExitCode.USER_CANCELED)

        # Timed step: ensure local branch is in sync with remote
        with timer.step("Remote sync"):
            if not check_remote_sync(project_dir, branch):  # Sync failed
                exit_with_error(
                    "Remote sync failed",
                    ExitCode.WORKING_TREE_FAILED,
                )

        # Timed step: commit and push publish workflow if changed (so tag sees it; no manual git)
        with timer.step("Publish workflow"):
            if not ensure_publish_workflow_committed(project_dir, branch):
                exit_with_error(
                    "Failed to commit/push .github/workflows/publish.yml",
                    ExitCode.GIT_FAILED,
                )

        # Format and analyze before tests: fail fast on analysis without
        # running 7k+ tests (which can fill temp and fail with disk space errors).
        # Timed step: run dart format on project
        with timer.step("Format"):
            if not run_format(project_dir):  # Format error
                exit_with_error(
                    "Formatting failed.", ExitCode.VALIDATION_FAILED,
                )

        # Timed step: run dart analyze --fatal-infos
        with timer.step("Analysis"):
            if not run_analysis(project_dir):  # Analysis error
                exit_with_error(
                    "Analysis failed.", ExitCode.ANALYSIS_FAILED,
                )

        # Timed step: run dart test
        with timer.step("Tests"):
            if not run_tests(project_dir):  # Test failure
                exit_with_error("Tests failed.", ExitCode.TEST_FAILED)

        # --- Step 8: Version prompt (interactive; suggest next patch if current tag exists) ---
        print_header("VERSION")
        if tag_exists_on_remote(project_dir, f"v{pubspec_version}"):
            default_version = increment_version(pubspec_version)
        else:
            default_version = pubspec_version

        while True:
            # Accept only semver (X.Y.Z or X.Y.Z-pre.N)
            version = _prompt_version(default_version)
            if re.match(rf"^{_VERSION_RE}$", version):  # Valid semver
                break
            print_warning(  # Invalid format — prompt again
                f"Invalid version format '{version}'. "
                f"Use X.Y.Z or X.Y.Z-pre.N"
            )

        # Timed step: write version to pubspec, rename [Unreleased] in CHANGELOG, reconcile versions
        with timer.step("Version sync"):
            # Align pubspec and CHANGELOG: update pubspec if needed, then rename [Unreleased] → [version]
            # version_to_sync: may be re-prompted if CHANGELOG has duplicate version sections
            version_to_sync = version
            while True:
                if version_to_sync != pubspec_version:
                    set_version_in_pubspec(pubspec_path, version_to_sync)
                    print_success(f"Updated pubspec.yaml to {version_to_sync}")

                try:
                    # Rename [Unreleased] to [version_to_sync] in CHANGELOG
                    if rename_unreleased_to_version(
                        changelog_path, version_to_sync
                    ):
                        print_success(
                            f"Renamed [Unreleased] to [{version_to_sync}] "
                            f"in CHANGELOG.md"
                        )
                    break
                except ValueError as exc:
                    # CHANGELOG already has both [Unreleased] and [version]: prompt for which version to use
                    suggested = increment_version(version_to_sync)
                    print_warning(str(exc))
                    print_colored(
                        f"  Suggested version: {suggested} "
                        f"(press Enter or edit)",
                        Color.CYAN,
                    )
                    version_to_sync = _prompt_version(suggested)
                    if not re.match(rf"^{_VERSION_RE}$", version_to_sync):
                        print_warning(
                            f"Invalid version format '{version_to_sync}'. "
                            f"Use X.Y.Z or X.Y.Z-pre.N"
                        )
                        continue
            # Use synced version for rest of workflow
            version = version_to_sync

            # Ensure pubspec and CHANGELOG agree (reconcile or add section if needed)
            # changelog_version: latest version heading found in CHANGELOG
            changelog_version = get_latest_changelog_version(
                changelog_path,
            )
            if changelog_version is None:  # No version found in CHANGELOG
                exit_with_error(
                    "Could not extract version from CHANGELOG.md",
                    ExitCode.CHANGELOG_FAILED,
                )
            if version != changelog_version:
                if parse_version(version) < parse_version(changelog_version):
                    # Pubspec behind CHANGELOG: update pubspec to match
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
                    # Pubspec ahead of CHANGELOG: offer to add [version] section
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

            # If version already published, auto-bump pubspec and add release note to CHANGELOG
            tag_name = f"v{version}"
            if tag_exists_on_remote(project_dir, tag_name):
                next_version = increment_version(version)
                print_warning(
                    f"Tag {tag_name} already exists on remote. "
                    f"Version {version} has already been published."
                )
                print_info(
                    f"Bumping to {next_version} and adding CHANGELOG section."
                )
                set_version_in_pubspec(pubspec_path, next_version)
                add_version_section(
                    changelog_path, next_version, "Release version",
                )
                version = next_version
                print_success(
                    f"Updated pubspec.yaml to {version} and added "
                    f"[{version}] to CHANGELOG.md (Release version)."
                )

        print_colored(
            f"      Publishing: {version}", Color.CYAN,
        )
        print_colored(f"      Tag:        v{version}", Color.CYAN)
        # Keep extension version in sync with package version
        if extension_exists(project_dir):
            set_extension_version(project_dir, version)
        print()

        # --- Steps 9-11: Badge sync, CHANGELOG validation, doc generation, dry-run ---
        # Timed step: update README badges with version and rule count
        with timer.step("Badge sync"):
            sync_readme_badges(project_dir, version, rule_count)

        # Timed step: ensure CHANGELOG has entry for this version and extract release notes
        with timer.step("CHANGELOG validation"):
            # ok: version present and valid; release_notes: body for GitHub release
            ok, release_notes = validate_changelog(
                project_dir, version,
            )
            if not ok:
                exit_with_error(
                    "CHANGELOG failed",                     ExitCode.CHANGELOG_FAILED,
                )

        # Timed step: generate API docs (dart doc)
        with timer.step("Docs"):
            if not generate_docs(project_dir):  # Doc generation error
                exit_with_error(
                    "Docs failed",                     ExitCode.VALIDATION_FAILED,
                )

        # Timed step: dart pub publish --dry-run to catch pub.dev issues
        with timer.step("Pre-publish validation"):
            if not pre_publish_validation(project_dir):  # Would fail on pub.dev
                exit_with_error(
                    "Validation failed", ExitCode.VALIDATION_FAILED,
                )

        # --- Re-run analysis after version bump so we don't tag a broken build ---
        # Timed step: re-run analysis after version changes; abort if it fails
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

        # --- Commit and push versioned files, then tag, publish to pub.dev, create GitHub release ---
        # Timed step: stage all changes, commit, push to remote
        with timer.step("Git commit & push"):
            if not git_commit_and_push(
                project_dir, version, branch,
            ):
                exit_with_error(
                    "Git operations failed", ExitCode.GIT_FAILED,
                )

        # --- Optionally re-trigger CI if workflow failed (e.g. flaky check) ---
        # Timed step: optionally re-run failed GitHub Actions workflow
        with timer.step("CI status"):
            # Lazy import: prompt to re-run failed GitHub Actions workflow
            from scripts.modules._retrigger_ci import offer_retrigger_ci

            offer_retrigger_ci(limit=10)

        # Timed step: create git tag vX.Y.Z
        with timer.step("Git tag"):
            if not create_git_tag(project_dir, version):
                exit_with_error(
                    "Git tag failed",                     ExitCode.GIT_FAILED,
                )

        # Timed step: publish package to pub.dev (dart pub publish)
        with timer.step("Publish"):
            if not publish_to_pubdev_step(project_dir, version):
                exit_with_error(
                    "Publish failed",                     ExitCode.PUBLISH_FAILED,
                )

        # Timed step: create GitHub release with notes from CHANGELOG
        with timer.step("GitHub release"):
            # gh_success: True if release created; gh_error: message on failure
            gh_success, gh_error = create_github_release(
                project_dir, version, release_notes,
            )
            if not gh_success:
                exit_with_error(
                    f"GitHub release failed: {gh_error}",
                    ExitCode.GITHUB_RELEASE_FAILED,
                )

        # Mark success so final banner is printed and exit code stays 0
        succeeded = True

        # --- Bump pubspec and add [Unreleased] in CHANGELOG for next cycle; commit if possible ---
        try:
            # Timed step: bump pubspec to next version, add [Unreleased], commit
            with timer.step("Version bump"):
                next_version = increment_version(version)
                set_version_in_pubspec(pubspec_path, next_version)
                add_unreleased_section(changelog_path)
                if post_publish_commit(project_dir, next_version, branch):
                    print_success(
                        f"Bumped to {next_version} with "
                        f"[Unreleased] section"
                    )
                else:  # Commit failed (non-fatal)
                    print_warning(
                        f"Version bump to {next_version} "
                        f"not committed \u2014 commit manually"
                    )
        except Exception as exc:
            print_warning(f"Post-publish version bump failed: {exc}")

        # --- Extension: package .vsix and optionally publish (runs after package publish so versions stay aligned) ---
        extension_published = False
        if extension_exists(project_dir):
            with timer.step("Extension"):
                vsix = package_extension(project_dir, version)
                if vsix:
                    # Install locally (default yes)
                    response = (
                        input("  Install extension locally? [Y/n] ")
                        .strip()
                        .lower()
                    )
                    if not response.startswith("n"):
                        install_extension(vsix)
                    # Publish to stores (default no)
                    response = (
                        input(
                            "  Publish extension to Marketplace and Open VSX? [y/N] "
                        )
                        .strip()
                        .lower()
                    )
                    if response.startswith("y"):
                        if publish_extension(project_dir, vsix):
                            extension_published = True
                        else:
                            print_warning("Extension publish failed (package already published).")
                else:
                    print_warning("Extension package failed (package already published).")

        # --- Post-publish: open pub.dev page (convenience) ---
        try:
            webbrowser.open(
                f"https://pub.dev/packages/{package_name}",
            )
        except Exception:
            pass  # Browser open is non-critical

    except SystemExit as exc:
        # Capture exit code from exit_with_error() or sys.exit() for final return
        exit_code = exc.code if isinstance(exc.code, int) else 1

    finally:
        # Always print step timing summary
        timer.print_summary()

    if succeeded:
        # Show success banner with package/release/store links and pubspec snippet
        repo_path = extract_repo_path(remote_url)
        publisher, ext_name = _get_extension_identity(project_dir)
        _print_success_banner(
            package_name, version, repo_path, publisher, ext_name,
            extension_published,
        )

    # Return 0 on success, or the exit code set by exit_with_error()
    return exit_code


if __name__ == "__main__":
    # Interactive: prompt for mode (full / audit only / fix docs / full_skip_audit) then run
    sys.exit(main(mode=_prompt_publish_mode()))
