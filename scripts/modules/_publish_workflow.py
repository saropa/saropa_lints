"""
Publish pipeline orchestration for saropa_lints.

High-level workflow steps that wire together lower-level modules
(_publish_steps, _git_ops, _version_changelog, _extension_publish,
_rule_metrics, _code_comment_metrics, _comment_coverage_report, _pubdev_lint) into the publish pipeline. Each function
represents one stage of the publish process.

Also contains the PublishContext dataclass (shared project state) and
display/banner helpers used across stages.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
import webbrowser
from dataclasses import dataclass
from pathlib import Path

from scripts.modules._utils import (
    Color,
    ExitCode,
    exit_with_error,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
    prompt_step_failure,
)
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
    run_preflight_version_check,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
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
    run_pub_get,
    run_tests,
    validate_changelog,
    verify_pubdev_publication,
)
from scripts.modules._comment_coverage_report import display_full_comment_coverage_report
from scripts.modules._rule_metrics import (
    count_categories,
    count_rules,
    display_roadmap_summary,
    display_test_coverage,
    sync_readme_badges,
)
from scripts.modules._extension_publish import (
    MARKETPLACE_MANAGE_URL,
    extension_exists,
    extension_vsix_path,
    get_extension_identity,
    install_extension,
    package_extension,
    publish_extension,
    set_extension_version,
    verify_extension_store_publication,
)
from scripts.modules._tier_yaml_version import sync_tier_yamls
from scripts.modules._timing import StepTimer
from scripts.modules._version_changelog import (
    display_changelog,
    get_latest_changelog_version,
    get_package_name,
    get_version_from_pubspec,
    has_unreleased_section,
    increment_version,
    parse_version,
    prompt_version_until_valid,
    set_version_in_pubspec,
    sync_version_with_changelog,
)


# Shown when audit fails with no auto-fix (e.g. tier integrity or duplicate rule names)
_AUDIT_FAILED_MSG = (
    "Pre-publish audit failed. Fix the blocking issue(s) "
    "marked with \u2717 above and re-run."
)


# =============================================================================
# PUBLISH CONTEXT
# =============================================================================


@dataclass(frozen=True)
class PublishContext:
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


def build_publish_context(
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
) -> PublishContext:
    """Build a PublishContext by reading project metadata.

    Gathers package name, version, git branch, remote URL, and
    rule/category counts from the project.
    """
    return PublishContext(
        project_dir=project_dir,
        pubspec_path=pubspec_path,
        changelog_path=changelog_path,
        bugs_dir=project_dir / "bugs",
        package_name=get_package_name(pubspec_path),
        pubspec_version=get_version_from_pubspec(pubspec_path),
        branch=get_current_branch(project_dir),
        remote_url=get_remote_url(project_dir),
        rule_count=count_rules(project_dir),
        category_count=count_categories(project_dir),
    )


# =============================================================================
# DISPLAY / BANNERS
# =============================================================================


def print_package_banner(
    ctx: PublishContext, script_version: str,
) -> None:
    """Print package info, changelog, coverage, and roadmap summary."""
    print_header(f"SAROPA LINTS PUBLISHER v{script_version}")
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
    display_full_comment_coverage_report(ctx.project_dir)
    todo_log = display_roadmap_summary(
        ctx.project_dir, bugs_dir=ctx.bugs_dir,
    )
    if todo_log:
        print_info(f"TODO log: {todo_log.relative_to(ctx.project_dir)}")


def print_success_banner(
    package_name: str, version: str, repo_path: str,
    publisher: str, extension_name: str,
    extension_published: bool,
    extension_vsix_relative: str | None = None,
) -> None:
    """Print final success banner with pub.dev, CI, release, and store URLs plus pubspec snippet."""
    print_colored(
        f"  \u2713 PUBLISHED {package_name} v{version}",
        Color.GREEN,
    )
    print()
    if extension_vsix_relative:
        print_colored(
            f"      VSIX:         {extension_vsix_relative}",
            Color.CYAN,
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
    # Item-specific Marketplace / Open VSX links only when the extension
    # was actually published this run — linking to an unpublished item
    # produces a 404 for the developer.
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
    # Publisher management console — always surfaced (not gated on
    # extension_published) because it's the single most useful URL for
    # a developer: it works even when the extension publish was skipped
    # or failed silently, lets the user verify the publish, re-upload a
    # .vsix manually, and inspect download stats. Previously hidden
    # behind extension_published, which meant the developer had to hunt
    # for the URL exactly in the failure case where they needed it most.
    if publisher:
        print_colored(
            f"      Manage:       https://marketplace.visualstudio.com"
            f"/manage/publishers/{publisher}",
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
# VALIDATION
# =============================================================================


def validate_pubspec_changelog(
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


# =============================================================================
# EARLY / ALTERNATIVE MODE HANDLERS
# =============================================================================


def run_analyze_only(mode: str, project_dir: Path) -> int | None:
    """If mode is analyze_only, run analyze-to-log and return exit code; else None."""
    if mode != "analyze_only":
        return None
    ok = run_analyze_to_log(project_dir)
    return ExitCode.SUCCESS.value if ok else ExitCode.ANALYSIS_FAILED.value


def run_dry_run_mode(
    mode: str,
    project_dir: Path,
    timer: StepTimer,
) -> int | None:
    """If mode is dry_run, run the full validation pipeline without publishing.

    Runs dependency resolution, audit, format, analysis, tests, and
    `dart pub publish --dry-run` — every check that doesn't need pub.dev
    credentials or mutate git/version state (no version prompt, no commit,
    no tag, no push, no GitHub release). Intended for CI pre-merge
    validation of a branch before it's mergeable, without the write side
    effects a real publish run has.
    """
    if mode != "dry_run":
        return None

    branch = get_current_branch(project_dir)

    with timer.step("Dependencies"):
        _run_step_with_retry(
            "Dependency resolution (dart pub get)",
            lambda: run_pub_get(project_dir),
            ExitCode.PREREQUISITES_FAILED,
        )

    code = run_audit_step(
        project_dir, skip_audit=False, audit_only=False, timer=timer,
    )
    if code is not None:
        return code

    run_pre_publish_pipeline(project_dir, branch, timer)

    # `dart pub publish --dry-run` needs no credentials and mutates nothing —
    # it's the pub.dev tool's own manifest/package validation, a natural fit
    # for this mode even without a version bump.
    with timer.step("Pre-publish validation"):
        _run_step_with_retry(
            "Pre-publish validation",
            lambda: pre_publish_validation(project_dir),
            ExitCode.VALIDATION_FAILED,
        )

    print_success(
        "Dry run complete — all pre-publish checks passed. "
        "No commit, tag, version bump, or publish was performed."
    )
    return ExitCode.SUCCESS.value


def run_ci_fallback_mode(
    mode: str,
    project_dir: Path,
    pubspec_path: Path,
) -> int | None:
    """If mode is ci_fallback, print manual publish fallback checklist and return.

    This mode is intentionally read-only: it prints exact commands, URLs, and
    file locations so a maintainer can publish when GitHub Actions publish
    fails (for example flaky CI, Actions outage, token/scopes, or runner
    regressions).
    """
    if mode != "ci_fallback":
        return None

    package_name = get_package_name(pubspec_path)
    version = get_version_from_pubspec(pubspec_path)
    repo_path = extract_repo_path(get_remote_url(project_dir))
    tag_name = f"v{version}"
    release_url = f"https://github.com/{repo_path}/releases/tag/{tag_name}"
    actions_url = f"https://github.com/{repo_path}/actions"
    tag_push_url = f"https://github.com/{repo_path}/actions/workflows/publish.yml"
    pub_url = f"https://pub.dev/packages/{package_name}"
    pub_score_url = f"https://pub.dev/packages/{package_name}/score"
    ext_vsix = extension_vsix_path(project_dir, version)

    print_header("CI FALLBACK PLAYBOOK (MANUAL RELEASE)")
    print_warning(
        "Use this when tag-triggered GitHub Actions publish fails."
    )
    print()

    print_colored("  1) Verify local release state", Color.WHITE)
    print_colored("      dart --version", Color.CYAN)
    print_colored("      dart pub get", Color.CYAN)
    print_colored("      dart analyze --fatal-infos", Color.CYAN)
    print_colored("      dart test", Color.CYAN)
    print_colored("      dart pub publish --dry-run", Color.CYAN)
    print()

    print_colored("  2) Publish package directly to pub.dev", Color.WHITE)
    print_colored("      dart pub publish", Color.CYAN)
    print_colored("      Package URL:", Color.DIM)
    print_colored(f"        {pub_url}", Color.CYAN)
    print_colored("      Score URL:", Color.DIM)
    print_colored(f"        {pub_score_url}", Color.CYAN)
    print()

    print_colored("  3) Ensure tag + GitHub release exist", Color.WHITE)
    print_colored(f"      git tag {tag_name}", Color.CYAN)
    print_colored(f"      git push origin {tag_name}", Color.CYAN)
    print_colored(
        f"      gh release create {tag_name} --title \"Release {tag_name}\" --notes-file CHANGELOG.md",
        Color.CYAN,
    )
    print_colored("      Release URL:", Color.DIM)
    print_colored(f"        {release_url}", Color.CYAN)
    print()

    print_colored("  4) Extension fallback (if applicable)", Color.WHITE)
    print_colored(
        "      python scripts/publish.py   # choose: 6) Extension only",
        Color.CYAN,
    )
    print_colored("      OR upload existing VSIX manually in Marketplace UI.", Color.CYAN)
    print_colored("      Required file to upload:", Color.DIM)
    if ext_vsix.is_file():
        print_colored(f"        {ext_vsix}", Color.CYAN)
    else:
        print_colored(
            f"        {ext_vsix}  (missing; run mode 6 to generate)",
            Color.YELLOW,
        )
    print_colored("      Marketplace manage URL:", Color.DIM)
    print_colored(f"        {MARKETPLACE_MANAGE_URL}", Color.CYAN)
    publisher, ext_name = get_extension_identity(project_dir)
    if publisher and ext_name:
        print_colored("      Extension listing URLs:", Color.DIM)
        print_colored(
            f"        https://marketplace.visualstudio.com/items?itemName={publisher}.{ext_name}",
            Color.CYAN,
        )
        print_colored(
            f"        https://open-vsx.org/extension/{publisher}/{ext_name}",
            Color.CYAN,
        )
    print()

    print_colored("  5) CI triage URLs", Color.WHITE)
    print_colored(f"      Actions: {actions_url}", Color.CYAN)
    print_colored(f"      Publish workflow: {tag_push_url}", Color.CYAN)
    print()
    print_info("Fallback playbook printed. No files changed.")
    return ExitCode.SUCCESS.value


def _verify_marketplace_and_ovsx(
    project_dir: Path,
    version: str,
    vsix_path: Path | None,
) -> None:
    """Poll Marketplace and Open VSX until *version* propagates.

    Shared between full-publish, extension-only, and publish-existing-vsix
    modes so every flow that touches the stores ends with a confirmation
    that the published version is actually live. Motivating case: vsce
    returns 0 but the Marketplace silently drops the upload (expired PAT
    or missing scope), leaving the user thinking the publish worked when
    it never propagated.
    """
    publisher, ext_name = get_extension_identity(project_dir)
    if not (publisher and ext_name):
        # Best-effort: if we cannot resolve identity, we can't query stores.
        # Don't fail the run — the publish itself already succeeded.
        print_warning(
            "Could not resolve extension identity; "
            "skipping store publication verification."
        )
        return
    result = verify_extension_store_publication(
        publisher=publisher,
        extension_name=ext_name,
        expected_version=version,
        vsix_path=vsix_path,
        interval_seconds=30,
        timeout_seconds=600,
    )
    # Only the Marketplace failure is loud + auto-opens the manage page;
    # Open VSX failures are surfaced inside verify_extension_store_publication
    # but don't warrant browser launch (different remediation path).
    if not result.marketplace_ok:
        print_warning(
            "ACTION REQUIRED: upload the .vsix manually to "
            "the VS Code Marketplace."
        )
        try:
            webbrowser.open(MARKETPLACE_MANAGE_URL)
        except Exception:
            # Browser launch is best-effort; the warning already shows the URL.
            pass


def _version_from_vsix_filename(vsix_path: Path) -> str | None:
    """Extract version from a .vsix filename like 'saropa-lints-12.4.2.vsix'.

    Used by the publish_existing_vsix mode where we can't trust
    extension/package.json (it may have been auto-bumped after the last
    publish). The filename is the source of truth for what was packaged.
    """
    match = re.search(r"-(\d+\.\d+\.\d+(?:[-+][\w.+-]+)?)\.vsix$", vsix_path.name)
    return match.group(1) if match else None


def run_extension_only_mode(
    mode: str,
    project_dir: Path,
    pubspec_path: Path,
) -> int | None:
    """If mode is extension_only, run workflow and return exit code; else None."""
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
        # Final step: confirm the marketplace actually serves the new
        # version. publish_extension() returning True only means vsce
        # exited 0 — it does NOT mean the Marketplace propagated.
        _verify_marketplace_and_ovsx(project_dir, ext_version, vsix)
    return ExitCode.SUCCESS.value


def run_publish_existing_vsix_mode(
    mode: str,
    project_dir: Path,
) -> int | None:
    """If mode is publish_existing_vsix, skip packaging and publish the newest
    .vsix already in the project root to Marketplace + Open VSX. Returns exit code;
    else None.

    Rationale: publish.py auto-bumps pubspec.yaml / extension/package.json
    after a successful pub.dev publish for the *next* cycle. Running mode 6
    (Extension only) after that packages the *next* version of the .vsix,
    which then drifts from the pub.dev release. This mode lets you publish
    an already-packaged .vsix (e.g. one that matches the live pub.dev
    version) without re-packaging.
    """
    if mode != "publish_existing_vsix":
        return None
    if not extension_exists(project_dir):
        exit_with_error(
            f"Extension directory not found: {project_dir / 'extension'}",
            ExitCode.PREREQUISITES_FAILED,
        )
    # Newest .vsix first so the most recently packaged one is the default.
    vsix_files = sorted(
        project_dir.glob("*.vsix"),
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    if not vsix_files:
        exit_with_error(
            f"No .vsix found in {project_dir}. Run mode 6 to package one first.",
            ExitCode.PREREQUISITES_FAILED,
        )
    print_header("EXTENSION: PUBLISH EXISTING .VSIX")
    if len(vsix_files) > 1:
        print_info(f"Found {len(vsix_files)} .vsix files; newest first:")
        for idx, candidate in enumerate(vsix_files, start=1):
            marker = " <- selected" if idx == 1 else ""
            print_colored(f"      {idx}) {candidate.name}{marker}", Color.CYAN)
    vsix = vsix_files[0]
    print_success(f"Selected: {vsix.name}")
    if _prompt_extension_install_and_publish(vsix):
        if not publish_extension(project_dir, vsix):
            exit_with_error(
                "Extension publish failed",
                ExitCode.PUBLISH_FAILED,
            )
        # Derive version from the vsix filename rather than package.json:
        # in this mode the user is intentionally publishing an older .vsix
        # (e.g. one matching the live pub.dev release) while package.json
        # may already point at the next pre-bumped version. Filename is
        # the source of truth for what was actually published.
        vsix_version = _version_from_vsix_filename(vsix)
        if vsix_version:
            _verify_marketplace_and_ovsx(project_dir, vsix_version, vsix)
        else:
            print_warning(
                f"Could not parse version from {vsix.name}; "
                "skipping store publication verification."
            )
    return ExitCode.SUCCESS.value


def run_fix_docs_mode(mode: str, project_dir: Path) -> int | None:
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


def run_pubdev_only_mode(
    mode: str,
    project_dir: Path,
    pubspec_path: Path,
    changelog_path: Path,
    timer: StepTimer,
) -> int | None:
    """If mode is pubdev_only, run full publish pipeline without any extension steps.

    Identical to run_full_publish except:
    - No extension packaging, install, or store publish
    - No Marketplace / Open VSX verification
    - Success banner omits extension URLs

    Use when the VSIX was already published separately (e.g. via mode 6/7)
    or when CI blocked pub.dev but the extension went through.
    """
    if mode != "pubdev_only":
        return None

    ctx = build_publish_context(project_dir, pubspec_path, changelog_path)

    # Reuse the full publish banner so the user sees version/branch/rules
    from scripts.publish import SCRIPT_VERSION
    print_package_banner(ctx, SCRIPT_VERSION)

    succeeded = False
    version = ctx.pubspec_version

    try:
        # Dependency resolution before any analysis step
        with timer.step("Dependencies"):
            _run_step_with_retry(
                "Dependency resolution (dart pub get)",
                lambda: run_pub_get(ctx.project_dir),
                ExitCode.PREREQUISITES_FAILED,
            )

        # Audit (never skipped in this mode)
        code = run_audit_step(
            ctx.project_dir, skip_audit=False, audit_only=False, timer=timer,
        )
        if code is not None:
            return code

        # Format, analyze, tests
        run_pre_publish_pipeline(ctx.project_dir, ctx.branch, timer)

        # Version prompt
        print_header("VERSION")
        default_version = (
            increment_version(ctx.pubspec_version)
            if has_unreleased_section(ctx.changelog_path)
            else ctx.pubspec_version
        )
        changelog_version = get_latest_changelog_version(ctx.changelog_path)
        if changelog_version and parse_version(changelog_version) > parse_version(
            default_version
        ):
            default_version = changelog_version
        version = prompt_version_until_valid(default_version)
        with timer.step("Version sync"):
            version = sync_version_with_changelog(
                ctx.project_dir,
                ctx.pubspec_path,
                ctx.changelog_path,
                ctx.pubspec_version,
                version,
            )
            # Sync tier yamls even in pub.dev-only mode — consumers resolve
            # against these constraints regardless of the extension state.
            tier_changes = sync_tier_yamls(
                ctx.project_dir / "lib" / "tiers", version,
            )
            for path, (previous, desired) in tier_changes.items():
                rel = path.relative_to(ctx.project_dir)
                print_colored(
                    f"      tier yaml: {rel} {previous} -> {desired}",
                    Color.CYAN,
                )

        print_colored(f"      Publishing: {version}", Color.CYAN)
        print_colored(f"      Tag:        v{version}", Color.CYAN)
        # Keep extension/package.json version in sync even though we
        # skip extension packaging — the preflight check validates it,
        # and a later extension-only publish (mode 6) needs the version
        # to match the pub.dev release.
        if extension_exists(ctx.project_dir):
            set_extension_version(ctx.project_dir, version)
        print()

        # Preflight version check
        with timer.step("Preflight version check"):
            _run_step_with_retry(
                "Preflight version check",
                lambda: run_preflight_version_check(ctx.project_dir, version),
                ExitCode.VALIDATION_FAILED,
            )

        # Badge sync, changelog validation, docs, dry-run
        release_notes = run_badge_validation_docs_dryrun(
            ctx.project_dir, version, ctx.rule_count, timer,
        )

        # Final CI gate
        run_final_ci_gate(ctx.project_dir, timer)

        # Commit, tag, publish to pub.dev, GitHub release — NO extension
        run_commit_tag_publish_release(
            ctx.project_dir, version, ctx.branch, release_notes, timer,
        )
        succeeded = True

        # Verify pub.dev propagation
        with timer.step("pub.dev verification"):
            verify_pubdev_publication(ctx.package_name, version)

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
        # No extension — pub.dev-only mode
        print_success_banner(
            ctx.package_name,
            version,
            repo_path,
            publisher="",
            extension_name="",
            extension_published=False,
        )
    return ExitCode.SUCCESS.value


def _prompt_extension_install_and_publish(
    vsix: Path, skip_publish_msg: str = "Extension NOT published to Marketplace.",
) -> bool:
    """Prompt to install .vsix locally and to publish to Marketplace/Open VSX.

    Returns:
        True if user chose to publish.
    """
    response = input("  Install extension locally? [y/N] ").strip().lower()
    if response.startswith("y"):
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


# =============================================================================
# PIPELINE STEPS (audit, pre-publish, badge/validation, CI gate, commit/release)
# =============================================================================


def run_audit_with_retry(project_dir: Path) -> tuple[bool, object]:
    """Run pre-publish audit; if prefix fix applies, fix and retry.

    On non-auto-fixable failures, prompts Retry / Ignore / Abort
    so the developer can fix blocking issues in another terminal.

    Returns:
        (ok, audit_result) tuple.
    """
    audit_ok, audit_result = run_pre_publish_audits(project_dir)
    while not audit_ok and audit_result:
        rules_dir = project_dir / "lib" / "src" / "rules"
        missing_prefix = getattr(
            audit_result, "rules_missing_prefix", None,
        )
        if missing_prefix:
            from scripts.modules._audit_checks import fix_missing_prefix

            n = fix_missing_prefix(rules_dir)
            if n:
                print_success(
                    f"Added [rule_name] prefix to {n} rule(s)."
                )
                print_info("Re-running audit...")
                audit_ok, audit_result = run_pre_publish_audits(project_dir)
                continue

        # No auto-fix available — prompt the developer
        choice = prompt_step_failure("Pre-publish audit")
        if choice == "retry":
            print_info("Re-running audit...")
            audit_ok, audit_result = run_pre_publish_audits(project_dir)
            continue
        if choice == "ignore":
            print_warning("Ignoring audit failure — continuing.")
            return True, None
        exit_with_error(
            _AUDIT_FAILED_MSG,
            ExitCode.AUDIT_FAILED,
        )
    return audit_ok, audit_result


def run_audit_step(
    project_dir: Path,
    skip_audit: bool,
    audit_only: bool,
    timer: StepTimer,
) -> int | None:
    """Run pre-publish audit. Returns exit code to return from main, or None to continue."""
    if not skip_audit:
        with timer.step("Pre-publish audit"):
            print_header("STEP 1: AUDIT")
            # run_audit_with_retry now handles its own RIA prompt
            # internally, so a False return means user chose abort.
            audit_ok, _ = run_audit_with_retry(project_dir)
            if not audit_ok:
                exit_with_error(
                    _AUDIT_FAILED_MSG, ExitCode.AUDIT_FAILED,
                )

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


def _run_step_with_retry(
    step_name: str,
    run_fn,
    exit_code: ExitCode,
    *,
    allow_ignore: bool = True,
) -> None:
    """Run a pipeline step in a retry/ignore/abort loop.

    On failure the developer is prompted to retry (after fixing the
    issue in another terminal), ignore (proceed despite the failure),
    or abort (hard exit). Replaces bare exit_with_error() calls so
    that no step is an unconditional hard exit.

    Set *allow_ignore* to False for irreversible steps (git push,
    tag, pub.dev publish) where skipping would leave the release in
    an inconsistent state.
    """
    while True:
        if run_fn():
            return
        choice = prompt_step_failure(
            step_name, allow_ignore=allow_ignore,
        )
        if choice == "retry":
            print_info(f"Re-running {step_name}...")
            continue
        if choice == "ignore":
            print_warning(f"Ignoring {step_name} failure — continuing.")
            return
        # abort
        exit_with_error(
            f"{step_name} failed.", exit_code,
        )


def run_pre_publish_pipeline(
    project_dir: Path, branch: str, timer: StepTimer,
) -> None:
    """Run prerequisites, working tree, sync, workflow, format, analysis, tests.

    Each step prompts Retry / Ignore / Abort on failure so the
    developer can fix issues in another terminal without losing
    the publish session.
    """
    with timer.step("Prerequisites"):
        _run_step_with_retry(
            "Prerequisites", check_prerequisites,
            ExitCode.PREREQUISITES_FAILED,
        )
    with timer.step("Working tree"):
        # check_working_tree returns (ok, has_changes); wrap to bool
        _run_step_with_retry(
            "Working tree",
            lambda: check_working_tree(project_dir)[0],
            ExitCode.USER_CANCELED,
        )
    with timer.step("Remote sync"):
        _run_step_with_retry(
            "Remote sync",
            lambda: check_remote_sync(project_dir, branch),
            ExitCode.WORKING_TREE_FAILED,
        )
    with timer.step("Publish workflow"):
        _run_step_with_retry(
            "Publish workflow commit",
            lambda: ensure_publish_workflow_committed(project_dir, branch),
            ExitCode.GIT_FAILED,
        )
    with timer.step("Format"):
        _run_step_with_retry(
            "Formatting",
            lambda: run_format(project_dir),
            ExitCode.VALIDATION_FAILED,
        )
    with timer.step("Analysis"):
        # run_analysis already has its own Ignore/Retry/Abort prompt
        # inside run_analysis_with_prompt, so a bare gate is fine here.
        if not run_analysis(project_dir):
            exit_with_error(
                "Analysis failed.", ExitCode.ANALYSIS_FAILED,
            )
    with timer.step("Tests"):
        # run_tests already has its own Continue/Retry/Abort prompt
        # inside _run_test_pass, so a bare gate is fine here.
        if not run_tests(project_dir):
            exit_with_error("Tests failed.", ExitCode.TEST_FAILED)


def run_badge_validation_docs_dryrun(
    project_dir: Path,
    version: str,
    rule_count: int,
    timer: StepTimer,
) -> str:
    """Badge sync, CHANGELOG validation, docs, pre-publish dry-run.

    Each step prompts Retry / Ignore / Abort on failure.

    Returns:
        Release notes string for GitHub release.
    """
    release_notes = ""
    with timer.step("Badge sync"):
        sync_readme_badges(project_dir, version, rule_count)
    with timer.step("CHANGELOG validation"):
        # validate_changelog returns (ok, notes); retry loop needs
        # to capture the notes on success.
        while True:
            ok, notes = validate_changelog(project_dir, version)
            if ok:
                release_notes = notes
                break
            choice = prompt_step_failure("CHANGELOG validation")
            if choice == "retry":
                print_info("Re-checking CHANGELOG...")
                continue
            if choice == "ignore":
                print_warning(
                    "Ignoring CHANGELOG failure — continuing "
                    "with generic release notes."
                )
                release_notes = f"Release {version}"
                break
            exit_with_error(
                "CHANGELOG failed", ExitCode.CHANGELOG_FAILED,
            )
    with timer.step("Docs"):
        _run_step_with_retry(
            "Docs generation",
            lambda: generate_docs(project_dir),
            ExitCode.VALIDATION_FAILED,
        )
    with timer.step("Pre-publish validation"):
        _run_step_with_retry(
            "Pre-publish validation",
            lambda: pre_publish_validation(project_dir),
            ExitCode.VALIDATION_FAILED,
        )
    return release_notes


def run_final_ci_gate(project_dir: Path, timer: StepTimer) -> None:
    """Re-run analysis after version bump; prompt RIA on failure.

    run_analysis already has its own inner Ignore/Retry/Abort for
    dart analyze, so this outer gate only fires when analysis
    returns False (user chose Abort inside). The outer prompt gives
    one more chance to retry or ignore before hard-exiting.
    """
    with timer.step("Final CI gate"):
        print_header("FINAL CI GATE")
        print_info(
            "Re-running CI checks after version changes to "
            "prevent burning a tag on a broken build..."
        )
        _run_step_with_retry(
            "Final CI gate",
            lambda: run_analysis(project_dir),
            ExitCode.ANALYSIS_FAILED,
        )
        print_success("CI gate passed — safe to create tag")


def run_commit_tag_publish_release(
    project_dir: Path,
    version: str,
    branch: str,
    release_notes: str,
    timer: StepTimer,
) -> None:
    """Commit/push, retrigger CI, tag, publish to pub.dev, GitHub release.

    Each step prompts Retry / Ignore / Abort on failure so the
    developer can fix issues (e.g. auth, network) without losing
    the publish session.
    """
    with timer.step("Git commit & push"):
        # Irreversible: downstream steps assume the commit is on the
        # remote. Ignoring a failed push would create orphan tags.
        _run_step_with_retry(
            "Git commit & push",
            lambda: git_commit_and_push(project_dir, version, branch),
            ExitCode.GIT_FAILED,
            allow_ignore=False,
        )
    with timer.step("CI status"):
        from scripts.modules._retrigger_ci import offer_retrigger_ci

        offer_retrigger_ci(limit=10)
    with timer.step("Git tag"):
        # Irreversible: publishing without a tag breaks release
        # traceability. Retry or abort only.
        _run_step_with_retry(
            "Git tag",
            lambda: create_git_tag(project_dir, version),
            ExitCode.GIT_FAILED,
            allow_ignore=False,
        )
    with timer.step("Publish"):
        # Irreversible: skipping the actual publish would create a
        # GitHub release for a version not on pub.dev.
        _run_step_with_retry(
            "Publish to pub.dev",
            lambda: publish_to_pubdev_step(project_dir, version),
            ExitCode.PUBLISH_FAILED,
            allow_ignore=False,
        )
    with timer.step("GitHub release"):
        # create_github_release returns (ok, error_msg); wrap for the
        # retry helper and surface the error message on failure.
        def _try_gh_release() -> bool:
            ok, err = create_github_release(
                project_dir, version, release_notes,
            )
            if not ok and err:
                print_error(f"GitHub release: {err}")
            return ok

        # Irreversible: the package is already on pub.dev at this
        # point; a missing GitHub release leaves no release notes.
        _run_step_with_retry(
            "GitHub release",
            _try_gh_release,
            ExitCode.GITHUB_RELEASE_FAILED,
            allow_ignore=False,
        )


def run_version_bump(
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


def run_extension_after_publish(
    project_dir: Path, version: str, timer: StepTimer,
) -> tuple[Path | None, bool]:
    """Package extension/saropa-lints-{version}.vsix, optionally install and publish.

    When ``extension/`` exists, full publish **must** leave that exact filename
    on disk before the workflow can succeed; otherwise this exits with an error.

    Returns:
        ``(vsix_path, published_to_stores)``. ``vsix_path`` is ``None`` only when
        there is no extension directory. ``published_to_stores`` is True only if
        Marketplace/Open VSX publish succeeded.
    """
    if not extension_exists(project_dir):
        return None, False
    with timer.step("Extension (install & stores)"):
        # Retry loop: packaging may fail due to compile errors the
        # developer can fix in another terminal window.
        def _try_post_publish_ext() -> bool:
            package_extension(project_dir, version)
            expected_ext = extension_vsix_path(project_dir, version)
            if not expected_ext.is_file():
                print_error(
                    f"Full publish requires extension/{expected_ext.name}. "
                    "Fix compile or packaging errors."
                )
                return False
            return True

        _run_step_with_retry(
            "Extension packaging",
            _try_post_publish_ext,
            ExitCode.VALIDATION_FAILED,
        )
        expected = extension_vsix_path(project_dir, version)
        # Guard: if the developer chose Ignore on a packaging failure,
        # the .vsix does not exist — skip install/publish gracefully
        # instead of crashing downstream.
        if not expected.is_file():
            print_warning(
                f"Extension {expected.name} not found on disk "
                "(packaging was skipped). Run option 6 to publish later."
            )
            return None, False
        if not _prompt_extension_install_and_publish(
            expected,
            skip_publish_msg=(
                "Extension NOT published to Marketplace. "
                "Run option 6 (extension only) to publish later."
            ),
        ):
            return expected, False
        if publish_extension(project_dir, expected):
            return expected, True
        print_warning(
            "Extension publish to Marketplace/Open VSX failed. "
            "Check output above for details."
        )
        return expected, False


# =============================================================================
# FULL PUBLISH WORKFLOW
# =============================================================================


def run_full_publish(
    ctx: PublishContext,
    mode: str,
    timer: StepTimer,
) -> int:
    """Run the complete publish pipeline (audit through extension).

    Orchestrates all pipeline stages in order. Returns exit code (0 = success).
    SystemExit from exit_with_error() is propagated to the caller.
    """
    audit_only = mode == "audit_only"
    skip_audit = mode == "full_skip_audit"
    version = ctx.pubspec_version
    succeeded = False
    extension_published = False
    published_vsix: Path | None = None

    try:
        # Resolve deps in root + every nested package BEFORE anything
        # that invokes `dart analyze` (audit, pre-publish pipeline, or
        # the final CI gate). A stale `.dart_tool/package_config.json`
        # in a nested package surfaces as thousands of phantom
        # `package:test/test.dart` errors against the sub-package's
        # test files; running pub get up front eliminates that whole
        # class of triage regardless of which downstream mode runs.
        with timer.step("Dependencies"):
            _run_step_with_retry(
                "Dependency resolution (dart pub get)",
                lambda: run_pub_get(ctx.project_dir),
                ExitCode.PREREQUISITES_FAILED,
            )

        code = run_audit_step(
            ctx.project_dir, skip_audit, audit_only, timer,
        )
        if code is not None:
            return code

        run_pre_publish_pipeline(
            ctx.project_dir, ctx.branch, timer,
        )

        print_header("VERSION")
        # Default offered to the prompt:
        # - CHANGELOG has [Unreleased] → patch bump from current pubspec
        #   (signals real work pending against the last-published version).
        # - No [Unreleased] → keep current pubspec value (= last published).
        #   This lands a known-bad default for accidental publish runs and
        #   forces an explicit override when the user really means to ship.
        # Replaces the old tag-on-remote heuristic which only made sense
        # alongside the post-publish auto-bump that committed the next
        # patch number into pubspec. That auto-bump was removed because
        # it pre-committed a patch decision the user might later want to
        # be a minor or major; the [Unreleased] signal now bumps only
        # when there is documented work to release.
        default_version = (
            increment_version(ctx.pubspec_version)
            if has_unreleased_section(ctx.changelog_path)
            else ctx.pubspec_version
        )
        # The pubspec-derived default above ignores a release section the
        # author has already written into the CHANGELOG by hand. When the
        # top `## [X.Y.Z]` heading is AHEAD of that default — e.g. a manual
        # major bump that also consumed the [Unreleased] heading (so the
        # has_unreleased branch can't fire) — prefer the documented
        # changelog version. Without this, a pre-written `## [14.0.0]`
        # section was silently ignored and the prompt offered the stale
        # pubspec patch (13.12.7), surprising the author. Only override
        # upward; never let a stale changelog drag the default backward.
        changelog_version = get_latest_changelog_version(ctx.changelog_path)
        if changelog_version and parse_version(changelog_version) > parse_version(
            default_version
        ):
            default_version = changelog_version
        version = prompt_version_until_valid(default_version)
        with timer.step("Version sync"):
            version = sync_version_with_changelog(
                ctx.project_dir,
                ctx.pubspec_path,
                ctx.changelog_path,
                ctx.pubspec_version,
                version,
            )
            # Keep `lib/tiers/*.yaml` plugin-version pins in sync with
            # the publish version so the analyzer's plugin manager
            # resolves a synthetic project against the same major as
            # what's on pub.dev. Without this, the tier yamls froze at
            # ^5.0.0-beta.8 from Feb 2026 and broke pub resolution for
            # any consumer also depending on a riverpod_lint /
            # analyzer_buffer combination — see issue #216.
            tier_changes = sync_tier_yamls(
                ctx.project_dir / "lib" / "tiers", version,
            )
            for path, (previous, desired) in tier_changes.items():
                rel = path.relative_to(ctx.project_dir)
                print_colored(
                    f"      tier yaml: {rel} {previous} -> {desired}",
                    Color.CYAN,
                )

        print_colored(f"      Publishing: {version}", Color.CYAN)
        print_colored(f"      Tag:        v{version}", Color.CYAN)
        if extension_exists(ctx.project_dir):
            set_extension_version(ctx.project_dir, version)
        print()

        # Early pre-flight: verify version files before expensive steps
        # (badge validation, CI gate, extension packaging). Catches the
        # silent-skip bug before any irreversible work begins.
        with timer.step("Preflight version check"):
            _run_step_with_retry(
                "Preflight version check",
                lambda: run_preflight_version_check(
                    ctx.project_dir, version,
                ),
                ExitCode.VALIDATION_FAILED,
            )

        release_notes = run_badge_validation_docs_dryrun(
            ctx.project_dir, version, ctx.rule_count, timer,
        )
        run_final_ci_gate(ctx.project_dir, timer)
        # Package the VSIX before the optional re-run+watch in commit/release, so
        # stopping the watch (or losing the process to a tool timeout) does not
        # mean "no .vsix on disk" when the extension compiles.
        if extension_exists(ctx.project_dir):
            with timer.step("Extension package"):
                # Retry loop: package_extension may fail due to transient
                # compile errors the developer can fix in another terminal.
                def _try_package_extension() -> bool:
                    package_extension(ctx.project_dir, version)
                    expected = extension_vsix_path(ctx.project_dir, version)
                    if not expected.is_file():
                        print_error(
                            f"Release requires extension/{expected.name} "
                            "after package. Fix compile/vsce errors."
                        )
                        return False
                    return True

                _run_step_with_retry(
                    "Extension packaging",
                    _try_package_extension,
                    ExitCode.VALIDATION_FAILED,
                )
        run_commit_tag_publish_release(
            ctx.project_dir, version, ctx.branch, release_notes, timer,
        )
        succeeded = True

        # No post-publish version bump: the next publish run decides the next
        # version at prompt time, driven by has_unreleased_section() above.
        # Auto-bumping pre-committed a patch decision (n.n.n+1) which was
        # wrong any time a minor or major was intended, and left phantom
        # "chore: bump version to X" commits on main for versions that may
        # never ship. See run_version_bump() — function kept for direct use
        # but no longer wired into the publish workflow.
        published_vsix, extension_published = run_extension_after_publish(
            ctx.project_dir, version, timer,
        )

        # FINAL STEP: consolidated store availability check.
        # Runs both pub.dev and (when applicable) Marketplace/Open VSX
        # verifications as the very last thing before the success banner,
        # so the user sees availability confirmation at the end of the
        # workflow instead of spread across earlier pipeline stages.
        # pub.dev verification is non-fatal on timeout — the publish step
        # itself already succeeded; this just confirms propagation.
        with timer.step("pub.dev verification"):
            verify_pubdev_publication(ctx.package_name, version)

        if extension_published:
            with timer.step("Store verification"):
                # Pass vsix_path so that, on Marketplace timeout, the
                # verification step can show the exact file to upload.
                _verify_marketplace_and_ovsx(
                    ctx.project_dir, version, published_vsix,
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
        publisher, ext_name = get_extension_identity(ctx.project_dir)
        vsix_rel: str | None = None
        if published_vsix is not None:
            vsix_rel = str(published_vsix.relative_to(ctx.project_dir))
        print_success_banner(
            ctx.package_name,
            version,
            repo_path,
            publisher,
            ext_name,
            extension_published,
            extension_vsix_relative=vsix_rel,
        )
    return ExitCode.SUCCESS.value
