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
    Post:    Bump version for next cycle (pubspec)

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
import urllib.request
import webbrowser
from dataclasses import dataclass
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
    update_analysis_options_plugin_version,
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
# Version prompt split into helpers to keep cognitive complexity under limit (SonarQube).
def _handle_win_key(
    ch: str, buffer: list[str], default: str
) -> tuple[str | None, bool]:
    """Handle one Windows key; return (value to return or None, raise KeyboardInterrupt)."""
    if ch in ("\r", "\n"):
        return ("".join(buffer).strip() or default, False)
    if ch == "\x08":  # Backspace
        if buffer:
            buffer.pop()
            sys.stdout.write("\b \b")
            sys.stdout.flush()
        return (None, False)
    if ch == "\x03":  # Ctrl+C
        return (None, True)
    if ch.isprintable():
        buffer.append(ch)
        sys.stdout.write(ch)
        sys.stdout.flush()
    return (None, False)


def _prompt_version_windows(default: str, timeout: int) -> str:
    """Windows: editable pre-filled prompt; return buffer or default on Enter/timeout."""
    import msvcrt

    sys.stdout.write(f"  Version to publish: {default}")
    sys.stdout.flush()
    buffer = list(default)
    start = time.time()
    while time.time() - start < timeout:
        if not msvcrt.kbhit():
            time.sleep(0.05)
            continue
        ch = msvcrt.getwch()
        result, do_raise = _handle_win_key(ch, buffer, default)
        if do_raise:
            raise KeyboardInterrupt
        if result is not None:
            print()
            return result
        time.sleep(0.05)
    print()
    return "".join(buffer).strip() or default


def _prompt_version_unix(default: str, timeout: int) -> str:
    """Unix: readline with select-based timeout; [default] in brackets."""
    import select

    sys.stdout.write(f"  Version to publish [{default}]: ")
    sys.stdout.flush()
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if not ready:
        print()
        return default
    user_input = sys.stdin.readline().strip()
    return user_input if user_input else default


def _prompt_version(default: str, timeout: int = 30) -> str:
    """Prompt for publish version with timeout.

    On Windows the default is pre-filled and editable.
    On Unix it is shown in brackets; press Enter to accept.
    Returns the default after *timeout* seconds of inactivity.
    """
    if sys.platform == "win32":
        return _prompt_version_windows(default, timeout)
    return _prompt_version_unix(default, timeout)


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


def _fetch_marketplace_latest_version(item_name: str) -> str | None:
    """Return latest Marketplace version for publisher.extension, or None on lookup failure."""
    url = (
        "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"
    )
    payload = {
        "filters": [
            {
                "criteria": [{"filterType": 7, "value": item_name}],
                "pageNumber": 1,
                "pageSize": 1,
                "sortBy": 0,
                "sortOrder": 0,
            }
        ],
        "assetTypes": [],
        "flags": 103,
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json;api-version=7.2-preview.1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
        results = data.get("results", [])
        if not results:
            return None
        extensions = results[0].get("extensions", [])
        if not extensions:
            return None
        versions = extensions[0].get("versions", [])
        if not versions:
            return None
        return versions[0].get("version")
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ):
        return None


def _fetch_open_vsx_latest_version(
    publisher: str, extension_name: str,
) -> str | None:
    """Return latest Open VSX version, or None on lookup failure."""
    url = f"https://open-vsx.org/api/{publisher}/{extension_name}"
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            data = json.loads(response.read().decode("utf-8"))
        version = data.get("version")
        return version if isinstance(version, str) else None
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
    ):
        return None


def _verify_extension_store_publication(
    publisher: str,
    extension_name: str,
    expected_version: str,
    interval_seconds: int = 30,
    timeout_seconds: int = 600,
) -> bool:
    """Poll Marketplace and Open VSX until both report expected version or timeout."""
    print_header("FINAL STEP: STORE PUBLICATION VERIFICATION")
    print_info(
        "Checking Marketplace and Open VSX every "
        f"{interval_seconds}s for up to {timeout_seconds // 60} minutes..."
    )
    item_name = f"{publisher}.{extension_name}"
    attempts = (timeout_seconds // interval_seconds) + 1

    last_marketplace = "unknown"
    last_openvsx = "unknown"
    for attempt in range(1, attempts + 1):
        marketplace_version = _fetch_marketplace_latest_version(item_name)
        open_vsx_version = _fetch_open_vsx_latest_version(
            publisher, extension_name,
        )
        last_marketplace = marketplace_version or "unavailable"
        last_openvsx = open_vsx_version or "unavailable"

        marketplace_ok = marketplace_version == expected_version
        open_vsx_ok = open_vsx_version == expected_version

        if marketplace_ok and open_vsx_ok:
            print_success(
                f"Store propagation complete: Marketplace={marketplace_version}, "
                f"Open VSX={open_vsx_version}"
            )
            return True

        print_info(
            f"Attempt {attempt}/{attempts}: Marketplace={last_marketplace}, "
            f"Open VSX={last_openvsx}"
        )
        if attempt < attempts:
            time.sleep(interval_seconds)

    print_warning(
        "Store propagation not confirmed within 10 minutes. "
        f"Last seen versions: Marketplace={last_marketplace}, "
        f"Open VSX={last_openvsx}."
    )
    return False


@dataclass(frozen=True)
class _PublishContext:
    """Holds project paths and derived info for the publish workflow."""

    project_dir: Path
    pubspec_path: Path
    changelog_path: Path
    bugs_dir: Path
    package_name: str
    pubspec_version: str
    branch: str
    remote_url: str
    rule_count: int
    category_count: int


def _run_analyze_only(mode: str, project_dir: Path) -> int | None:
    """If mode is analyze_only, run analyze-to-log and return exit code; else None."""
    if mode != "analyze_only":
        return None
    ok = run_analyze_to_log(project_dir)
    return ExitCode.SUCCESS.value if ok else ExitCode.ANALYSIS_FAILED.value


def _prompt_extension_install_and_publish(
    vsix: Path, skip_publish_msg: str = "Extension NOT published to Marketplace.",
) -> bool:
    """Prompt to install .vsix locally and to publish to Marketplace/Open VSX. Returns True if user chose to publish."""
    response = input("  Install extension locally? [Y/n] ").strip().lower()
    if not response.startswith("n"):
        install_extension(vsix)
    response = (
        input("  Publish extension to Marketplace and Open VSX? [Y/n] ")
        .strip()
        .lower()
    )
    if response.startswith("n"):
        print_warning(skip_publish_msg)
        return False
    return True


def _run_extension_only_mode(
    mode: str,
    project_dir: Path,
    pubspec_path: Path,
) -> int | None:
    """If mode is extension_only, run workflow and return exit code; else None. Exits on failure."""
    if mode != "extension_only":
        return None
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
    if _prompt_extension_install_and_publish(vsix):
        if not publish_extension(project_dir, vsix):
            exit_with_error(
                "Extension publish failed",
                ExitCode.PUBLISH_FAILED,
            )
    return ExitCode.SUCCESS.value


def _run_fix_docs_mode(mode: str, project_dir: Path) -> int | None:
    """If mode is fix_docs, run fix-docs workflow and return exit code; else None."""
    if mode != "fix_docs":
        return None
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


def _validate_pubspec_changelog(
    pubspec_path: Path, changelog_path: Path,
) -> None:
    """Ensure pubspec and CHANGELOG exist; exit on failure."""
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


def _print_package_banner(ctx: _PublishContext) -> None:
    """Print package info, changelog, coverage, and roadmap summary."""
    print_header(f"SAROPA LINTS PUBLISHER v{SCRIPT_VERSION}")
    print_colored("  Package Information:", Color.WHITE)
    print_colored(f"      Name:       {ctx.package_name}", Color.CYAN)
    print_colored(f"      Current:    {ctx.pubspec_version}", Color.CYAN)
    print_colored(f"      Branch:     {ctx.branch}", Color.CYAN)
    print_colored(f"      Repository: {ctx.remote_url}", Color.CYAN)
    print_colored(
        f"      Rules:      {ctx.rule_count} in {ctx.category_count} categories",
        Color.CYAN,
    )
    print()
    display_changelog(ctx.project_dir)
    display_test_coverage(ctx.project_dir)
    todo_log = display_roadmap_summary(
        ctx.project_dir, bugs_dir=ctx.bugs_dir,
    )
    if todo_log:
        print_info(f"TODO log: {todo_log.relative_to(ctx.project_dir)}")


def _run_audit_with_retry(project_dir: Path) -> tuple[bool, object]:
    """Run pre-publish audit; if prefix fix applies, fix and retry. Returns (ok, result)."""
    audit_ok, audit_result = run_pre_publish_audits(project_dir)
    while not audit_ok and audit_result:
        rules_dir = project_dir / "lib" / "src" / "rules"
        missing_prefix = getattr(
            audit_result, "rules_missing_prefix", None,
        )
        if not missing_prefix:
            exit_with_error(
                _AUDIT_FAILED_MSG,
                ExitCode.AUDIT_FAILED,
            )
        from scripts.modules._audit_checks import fix_missing_prefix

        n = fix_missing_prefix(rules_dir)
        if not n:
            exit_with_error(
                _AUDIT_FAILED_MSG,
                ExitCode.AUDIT_FAILED,
            )
        print_success(
            f"Added [rule_name] prefix to {n} rule(s)."
        )
        print_info("Re-running audit...")
        audit_ok, audit_result = run_pre_publish_audits(project_dir)
    return audit_ok, audit_result


def _run_audit_step(
    project_dir: Path,
    skip_audit: bool,
    audit_only: bool,
    timer: StepTimer,
) -> int | None:
    """Run pre-publish audit. Returns exit code to return from main, or None to continue."""
    if not skip_audit:
        with timer.step("Pre-publish audit"):
            print_header("STEP 1: AUDIT")
            audit_ok, _ = _run_audit_with_retry(project_dir)
            if not audit_ok:
                exit_with_error(_AUDIT_FAILED_MSG, ExitCode.AUDIT_FAILED)

        if audit_only:
            print_success(
                "Audit-only run complete (no format/analysis/tests)."
            )
            return ExitCode.SUCCESS.value
    elif audit_only:
        return ExitCode.USER_CANCELED.value

    if skip_audit:
        print_warning("Audit skipped (publish without audit).")
    return None


def _run_pre_publish_pipeline(
    project_dir: Path, branch: str, timer: StepTimer,
) -> None:
    """Run prerequisites, working tree, sync, workflow, format, analysis, tests. Exits on failure."""
    with timer.step("Prerequisites"):
        if not check_prerequisites():
            exit_with_error(
                "Prerequisites failed",
                ExitCode.PREREQUISITES_FAILED,
            )
    with timer.step("Working tree"):
        ok, _ = check_working_tree(project_dir)
        if not ok:
            exit_with_error("Aborted.", ExitCode.USER_CANCELED)
    with timer.step("Remote sync"):
        if not check_remote_sync(project_dir, branch):
            exit_with_error(
                "Remote sync failed",
                ExitCode.WORKING_TREE_FAILED,
            )
    with timer.step("Publish workflow"):
        if not ensure_publish_workflow_committed(project_dir, branch):
            exit_with_error(
                "Failed to commit/push .github/workflows/publish.yml",
                ExitCode.GIT_FAILED,
            )
    with timer.step("Format"):
        if not run_format(project_dir):
            exit_with_error(
                "Formatting failed.", ExitCode.VALIDATION_FAILED,
            )
    with timer.step("Analysis"):
        if not run_analysis(project_dir):
            exit_with_error(
                "Analysis failed.", ExitCode.ANALYSIS_FAILED,
            )
    with timer.step("Tests"):
        if not run_tests(project_dir):
            exit_with_error("Tests failed.", ExitCode.TEST_FAILED)


def _prompt_version_until_valid(default_version: str) -> str:
    """Prompt for version until valid semver; return version string."""
    while True:
        version = _prompt_version(default_version)
        if re.match(rf"^{_VERSION_RE}$", version):
            return version
        print_warning(
            f"Invalid version format '{version}'. "
            f"Use X.Y.Z or X.Y.Z-pre.N"
        )


def _apply_version_and_rename_unreleased(
    pubspec_path: Path,
    changelog_path: Path,
    pubspec_version: str,
    version: str,
) -> str:
    """Write version to pubspec and rename [Unreleased] in CHANGELOG; retry on conflict. Returns version_to_sync."""
    version_to_sync = version
    while True:
        if version_to_sync != pubspec_version:
            set_version_in_pubspec(pubspec_path, version_to_sync)
            print_success(f"Updated pubspec.yaml to {version_to_sync}")
        try:
            if rename_unreleased_to_version(
                changelog_path, version_to_sync,
            ):
                print_success(
                    f"Renamed [Unreleased] to [{version_to_sync}] "
                    f"in CHANGELOG.md"
                )
            return version_to_sync
        except ValueError as exc:
            suggested = increment_version(version_to_sync)
            print_warning(str(exc))
            print_colored(
                f"  Suggested version: {suggested} (press Enter or edit)",
                Color.CYAN,
            )
            version_to_sync = _prompt_version(suggested)
            if not re.match(rf"^{_VERSION_RE}$", version_to_sync):
                print_warning(
                    f"Invalid version format '{version_to_sync}'. "
                    f"Use X.Y.Z or X.Y.Z-pre.N"
                )


def _reconcile_pubspec_changelog_versions(
    pubspec_path: Path,
    changelog_path: Path,
    version_to_sync: str,
) -> str:
    """Ensure pubspec and CHANGELOG versions match; exit on failure. Returns version_to_sync."""
    changelog_version = get_latest_changelog_version(changelog_path)
    if changelog_version is None:
        exit_with_error(
            "Could not extract version from CHANGELOG.md",
            ExitCode.CHANGELOG_FAILED,
        )
    if version_to_sync == changelog_version:
        return version_to_sync
    if parse_version(version_to_sync) < parse_version(changelog_version):
        print_warning(
            f"pubspec version ({version_to_sync}) is behind "
            f"CHANGELOG ({changelog_version}). Updating pubspec..."
        )
        set_version_in_pubspec(pubspec_path, changelog_version)
        print_success(f"Updated pubspec.yaml to {changelog_version}")
        return changelog_version
    print_warning(
        f"pubspec version ({version_to_sync}) is ahead "
        f"of CHANGELOG ({changelog_version})."
    )
    response = (
        input(
            f"  Add a [{version_to_sync}] section to "
            f"CHANGELOG.md? [Y/n] "
        )
        .strip()
        .lower()
    )
    if response.startswith("n"):
        exit_with_error(
            "Publish canceled — update CHANGELOG.md manually.",
            ExitCode.CHANGELOG_FAILED,
        )
    add_version_section(
        changelog_path, version_to_sync, "Version bump",
    )
    print_success(
        f"Added [{version_to_sync}] section to CHANGELOG.md"
    )
    return version_to_sync


def _maybe_bump_for_tag_clash(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    version_to_sync: str,
) -> str:
    """If tag v{version} exists on remote, bump version and add CHANGELOG section; return final version."""
    tag_name = f"v{version_to_sync}"
    if not tag_exists_on_remote(project_dir, tag_name):
        return version_to_sync
    next_version = increment_version(version_to_sync)
    print_warning(
        f"Tag {tag_name} already exists on remote. "
        f"Version {version_to_sync} has already been published."
    )
    print_info(
        f"Bumping to {next_version} and adding CHANGELOG section."
    )
    set_version_in_pubspec(pubspec_path, next_version)
    add_version_section(
        changelog_path, next_version, "Release version",
    )
    print_success(
        f"Updated pubspec.yaml to {next_version} and added "
        f"[{next_version}] to CHANGELOG.md (Release version)."
    )
    return next_version


def _sync_version_with_changelog(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    pubspec_version: str,
    version: str,
) -> str:
    """Update pubspec/CHANGELOG with chosen version; reconcile; handle tag clash. Returns final version."""
    version_to_sync = _apply_version_and_rename_unreleased(
        pubspec_path, changelog_path, pubspec_version, version,
    )
    version_to_sync = _reconcile_pubspec_changelog_versions(
        pubspec_path, changelog_path, version_to_sync,
    )
    return _maybe_bump_for_tag_clash(
        project_dir, pubspec_path, changelog_path, version_to_sync,
    )


def _run_badge_validation_docs_dryrun(
    project_dir: Path,
    version: str,
    rule_count: int,
    timer: StepTimer,
) -> str:
    """Badge sync, CHANGELOG validation, docs, pre-publish dry-run. Returns release_notes for GitHub. Exits on failure."""
    with timer.step("Badge sync"):
        sync_readme_badges(project_dir, version, rule_count)
    with timer.step("CHANGELOG validation"):
        ok, release_notes = validate_changelog(project_dir, version)
        if not ok:
            exit_with_error(
                "CHANGELOG failed",
                ExitCode.CHANGELOG_FAILED,
            )
    with timer.step("Docs"):
        if not generate_docs(project_dir):
            exit_with_error(
                "Docs failed",
                ExitCode.VALIDATION_FAILED,
            )
    with timer.step("Pre-publish validation"):
        if not pre_publish_validation(project_dir):
            exit_with_error(
                "Validation failed",
                ExitCode.VALIDATION_FAILED,
            )
    return release_notes


def _run_final_ci_gate(project_dir: Path, timer: StepTimer) -> None:
    """Re-run analysis after version bump; exit on failure."""
    with timer.step("Final CI gate"):
        print_header("FINAL CI GATE")
        print_info(
            "Re-running CI checks after version changes to "
            "prevent burning a tag on a broken build..."
        )
        if not run_analysis(project_dir):
            exit_with_error(
                "Final CI gate failed — aborting before "
                "tag creation. Fix analysis issues and re-run.",
                ExitCode.ANALYSIS_FAILED,
            )
        print_success("CI gate passed — safe to create tag")


def _run_commit_tag_publish_release(
    project_dir: Path,
    version: str,
    branch: str,
    release_notes: str,
    timer: StepTimer,
) -> None:
    """Commit/push, retrigger CI, tag, publish to pub.dev, GitHub release. Exits on failure."""
    with timer.step("Git commit & push"):
        if not git_commit_and_push(project_dir, version, branch):
            exit_with_error(
                "Git operations failed",
                ExitCode.GIT_FAILED,
            )
    with timer.step("CI status"):
        from scripts.modules._retrigger_ci import offer_retrigger_ci

        offer_retrigger_ci(limit=10)
    with timer.step("Git tag"):
        if not create_git_tag(project_dir, version):
            exit_with_error(
                "Git tag failed",
                ExitCode.GIT_FAILED,
            )
    with timer.step("Publish"):
        if not publish_to_pubdev_step(project_dir, version):
            exit_with_error(
                "Publish failed",
                ExitCode.PUBLISH_FAILED,
            )
    with timer.step("GitHub release"):
        gh_success, gh_error = create_github_release(
            project_dir, version, release_notes,
        )
        if not gh_success:
            exit_with_error(
                f"GitHub release failed: {gh_error}",
                ExitCode.GITHUB_RELEASE_FAILED,
            )


def _run_version_bump(
    project_dir: Path,
    pubspec_path: Path,
    package_name: str,
    version: str,
    branch: str,
    timer: StepTimer,
) -> None:
    """Bump pubspec to next version; commit if possible. Non-fatal on failure."""
    try:
        with timer.step("Version bump"):
            next_version = increment_version(version)
            set_version_in_pubspec(pubspec_path, next_version)
            update_analysis_options_plugin_version(
                project_dir, package_name, version,
            )
            if post_publish_commit(project_dir, next_version, branch):
                print_success(f"Bumped to {next_version}")
            else:
                print_warning(
                    f"Version bump to {next_version} "
                    "not committed — commit manually"
                )
    except Exception as exc:
        print_warning(f"Post-publish version bump failed: {exc}")


def _run_extension_after_publish(
    project_dir: Path, version: str, timer: StepTimer,
) -> bool:
    """Package .vsix, optionally install and publish. Returns True if published."""
    if not extension_exists(project_dir):
        return False
    with timer.step("Extension"):
        vsix = package_extension(project_dir, version)
        if not vsix:
            print_warning(
                "Extension packaging failed — .vsix was not created. "
                "Check compile errors above."
            )
            return False
        if not _prompt_extension_install_and_publish(
            vsix,
            skip_publish_msg=(
                "Extension NOT published to Marketplace. "
                "Run option 6 (extension only) to publish later."
            ),
        ):
            return False
        if publish_extension(project_dir, vsix):
            return True
        print_warning(
            "Extension publish to Marketplace/Open VSX failed. "
            "Check output above for details."
        )
        return False


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
    """Run publish workflow. Returns exit code (0 = success). mode: 'full' | 'audit_only' | 'fix_docs' | 'full_skip_audit' | 'analyze_only' | 'extension_only'.

    Flow: validate paths → early modes (analyze/extension/fix_docs) → build context →
    audit → pre-publish pipeline → version prompt & sync → badge/validation/docs/dry-run →
    final CI gate → commit/tag/publish/release → version bump → extension. SystemExit
    from exit_with_error() is caught so finally (timer summary) runs and exit code is returned.
    """
    enable_ansi_support()
    set_output_level(output_level or _parse_output_level())
    show_saropa_logo()

    project_dir = get_project_dir()
    pubspec_path = project_dir / "pubspec.yaml"
    changelog_path = project_dir / "CHANGELOG.md"
    bugs_dir = project_dir / "bugs"
    _validate_pubspec_changelog(pubspec_path, changelog_path)

    code = _run_analyze_only(mode, project_dir)
    if code is not None:
        return code
    code = _run_extension_only_mode(mode, project_dir, pubspec_path)
    if code is not None:
        return code
    code = _run_fix_docs_mode(mode, project_dir)
    if code is not None:
        return code

    ctx = _PublishContext(
        project_dir=project_dir,
        pubspec_path=pubspec_path,
        changelog_path=changelog_path,
        bugs_dir=bugs_dir,
        package_name=get_package_name(pubspec_path),
        pubspec_version=get_version_from_pubspec(pubspec_path),
        branch=get_current_branch(project_dir),
        remote_url=get_remote_url(project_dir),
        rule_count=count_rules(project_dir),
        category_count=count_categories(project_dir),
    )
    _print_package_banner(ctx)

    audit_only = mode == "audit_only"
    skip_audit = mode == "full_skip_audit"
    timer = StepTimer()
    exit_code = ExitCode.SUCCESS.value
    version = ctx.pubspec_version
    release_notes = ""
    succeeded = False
    extension_published = False

    try:
        code = _run_audit_step(
            ctx.project_dir, skip_audit, audit_only, timer,
        )
        if code is not None:
            return code

        _run_pre_publish_pipeline(
            ctx.project_dir, ctx.branch, timer,
        )

        print_header("VERSION")
        default_version = (
            increment_version(ctx.pubspec_version)
            if tag_exists_on_remote(
                ctx.project_dir, f"v{ctx.pubspec_version}",
            )
            else ctx.pubspec_version
        )
        version = _prompt_version_until_valid(default_version)
        with timer.step("Version sync"):
            version = _sync_version_with_changelog(
                ctx.project_dir,
                ctx.pubspec_path,
                ctx.changelog_path,
                ctx.pubspec_version,
                version,
            )

        print_colored(f"      Publishing: {version}", Color.CYAN)
        print_colored(f"      Tag:        v{version}", Color.CYAN)
        if extension_exists(ctx.project_dir):
            set_extension_version(ctx.project_dir, version)
        print()

        release_notes = _run_badge_validation_docs_dryrun(
            ctx.project_dir, version, ctx.rule_count, timer,
        )
        _run_final_ci_gate(ctx.project_dir, timer)
        _run_commit_tag_publish_release(
            ctx.project_dir, version, ctx.branch, release_notes, timer,
        )
        succeeded = True

        _run_version_bump(
            ctx.project_dir,
            ctx.pubspec_path,
            ctx.package_name,
            version,
            ctx.branch,
            timer,
        )
        extension_published = _run_extension_after_publish(
            ctx.project_dir, version, timer,
        )
        if extension_published:
            with timer.step("Store verification"):
                publisher, ext_name = _get_extension_identity(ctx.project_dir)
                if publisher and ext_name:
                    _verify_extension_store_publication(
                        publisher=publisher,
                        extension_name=ext_name,
                        expected_version=version,
                        interval_seconds=30,
                        timeout_seconds=600,
                    )
                else:
                    print_warning(
                        "Could not resolve extension identity; "
                        "skipping store publication verification."
                    )

        try:
            webbrowser.open(
                f"https://pub.dev/packages/{ctx.package_name}",
            )
        except Exception:
            pass

    finally:
        timer.print_summary()

    if succeeded:
        repo_path = extract_repo_path(ctx.remote_url)
        publisher, ext_name = _get_extension_identity(ctx.project_dir)
        _print_success_banner(
            ctx.package_name,
            version,
            repo_path,
            publisher,
            ext_name,
            extension_published,
        )
    # On success we return 0; exit_with_error() raises SystemExit and never returns here.
    return exit_code


if __name__ == "__main__":
    # Interactive: prompt for mode (full / audit only / fix docs / full_skip_audit) then run
    sys.exit(main(mode=_prompt_publish_mode()))
