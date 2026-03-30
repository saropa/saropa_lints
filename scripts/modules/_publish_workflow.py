"""
Publish pipeline orchestration for saropa_lints.

High-level workflow steps that wire together lower-level modules
(_publish_steps, _git_ops, _version_changelog, _extension_publish,
_rule_metrics, _pubdev_lint) into the publish pipeline. Each function
represents one stage of the publish process.

Also contains the PublishContext dataclass (shared project state) and
display/banner helpers used across stages.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import webbrowser
from dataclasses import dataclass
from pathlib import Path

from scripts.modules._utils import (
    Color,
    ExitCode,
    exit_with_error,
    print_colored,
    print_header,
    print_info,
    print_success,
    print_warning,
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
    tag_exists_on_remote,
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
from scripts.modules._extension_publish import (
    extension_exists,
    get_extension_identity,
    install_extension,
    package_extension,
    publish_extension,
    set_extension_version,
    verify_extension_store_publication,
)
from scripts.modules._timing import StepTimer
from scripts.modules._version_changelog import (
    display_changelog,
    get_package_name,
    get_version_from_pubspec,
    increment_version,
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
    todo_log = display_roadmap_summary(
        ctx.project_dir, bugs_dir=ctx.bugs_dir,
    )
    if todo_log:
        print_info(f"TODO log: {todo_log.relative_to(ctx.project_dir)}")


def print_success_banner(
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


def _prompt_extension_install_and_publish(
    vsix: Path, skip_publish_msg: str = "Extension NOT published to Marketplace.",
) -> bool:
    """Prompt to install .vsix locally and to publish to Marketplace/Open VSX.

    Returns:
        True if user chose to publish.
    """
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


# =============================================================================
# PIPELINE STEPS (audit, pre-publish, badge/validation, CI gate, commit/release)
# =============================================================================


def run_audit_with_retry(project_dir: Path) -> tuple[bool, object]:
    """Run pre-publish audit; if prefix fix applies, fix and retry.

    Returns:
        (ok, audit_result) tuple.
    """
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
            audit_ok, _ = run_audit_with_retry(project_dir)
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


def run_pre_publish_pipeline(
    project_dir: Path, branch: str, timer: StepTimer,
) -> None:
    """Run prerequisites, working tree, sync, workflow, format, analysis, tests.

    Exits on failure via exit_with_error().
    """
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


def run_badge_validation_docs_dryrun(
    project_dir: Path,
    version: str,
    rule_count: int,
    timer: StepTimer,
) -> str:
    """Badge sync, CHANGELOG validation, docs, pre-publish dry-run.

    Returns:
        Release notes string for GitHub release. Exits on failure.
    """
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


def run_final_ci_gate(project_dir: Path, timer: StepTimer) -> None:
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


def run_commit_tag_publish_release(
    project_dir: Path,
    version: str,
    branch: str,
    release_notes: str,
    timer: StepTimer,
) -> None:
    """Commit/push, retrigger CI, tag, publish to pub.dev, GitHub release.

    Exits on failure via exit_with_error().
    """
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
) -> bool:
    """Package .vsix, optionally install and publish.

    Returns:
        True if extension was published to stores.
    """
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

    try:
        code = run_audit_step(
            ctx.project_dir, skip_audit, audit_only, timer,
        )
        if code is not None:
            return code

        run_pre_publish_pipeline(
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
        version = prompt_version_until_valid(default_version)
        with timer.step("Version sync"):
            version = sync_version_with_changelog(
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

        release_notes = run_badge_validation_docs_dryrun(
            ctx.project_dir, version, ctx.rule_count, timer,
        )
        run_final_ci_gate(ctx.project_dir, timer)
        run_commit_tag_publish_release(
            ctx.project_dir, version, ctx.branch, release_notes, timer,
        )
        succeeded = True

        run_version_bump(
            ctx.project_dir,
            ctx.pubspec_path,
            ctx.package_name,
            version,
            ctx.branch,
            timer,
        )
        extension_published = run_extension_after_publish(
            ctx.project_dir, version, timer,
        )
        if extension_published:
            with timer.step("Store verification"):
                publisher, ext_name = get_extension_identity(ctx.project_dir)
                if publisher and ext_name:
                    verify_extension_store_publication(
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
        publisher, ext_name = get_extension_identity(ctx.project_dir)
        print_success_banner(
            ctx.package_name,
            version,
            repo_path,
            publisher,
            ext_name,
            extension_published,
        )
    return ExitCode.SUCCESS.value
