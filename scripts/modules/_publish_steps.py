"""
Publish workflow step functions (steps 1-10).

Extracted from publish.py to keep the main script
focused on orchestration.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import NamedTuple

from scripts.modules._utils import (
    Color,
    OutputLevel,
    clear_flutter_lock,
    command_exists,
    get_output_level,
    get_shell_mode,
    is_windows,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
    run_command,
)
from scripts.modules._pubdev_lint import (
    check_pubdev_lint_issues,
    fix_doc_angle_brackets,
    fix_doc_references,
)
from scripts.modules._version_changelog import (
    check_changelog_overview,
    get_version_from_pubspec,
    validate_changelog_version,
)


class _AnalysisCounts(NamedTuple):
    """Parsed error/warning/info counts from dart analyze output."""

    errors: int
    warnings: int
    infos: int

    @property
    def total(self) -> int:
        return self.errors + self.warnings + self.infos


def _parse_analysis_counts(output: str) -> _AnalysisCounts:
    """Extract error/warning/info counts from dart analyze output.

    Matches both diagnostic lines (  error - ...) and plugin summary
    (Errors:   N, Warnings: N, Info:     N).
    """
    errors = warnings = infos = 0
    for line in output.splitlines():
        stripped = line.strip()
        # Diagnostic line: "error - path:line:col - ..." or "warning - ...", "info - ..."
        if re.match(r"^(error|warning|info)\s+-\s+", stripped, re.IGNORECASE):
            kind = stripped.split("-", 1)[0].strip().lower()
            if kind == "error":
                errors += 1
            elif kind == "warning":
                warnings += 1
            else:
                infos += 1
            continue
        # Plugin summary block: "Errors:   5", "Warnings: 12", "Info:     100"
        m = re.search(r"Errors:\s*(\d+)", stripped, re.IGNORECASE)
        if m:
            errors = int(m.group(1))
        m = re.search(r"Warnings:\s*(\d+)", stripped, re.IGNORECASE)
        if m:
            warnings = int(m.group(1))
        m = re.search(r"Info:\s*(\d+)", stripped, re.IGNORECASE)
        if m:
            infos = int(m.group(1))
    return _AnalysisCounts(errors=errors, warnings=warnings, infos=infos)


# ---------------------------------------------------------------------------
# Stale analyzer-plugin cache detection & repair
# ---------------------------------------------------------------------------

_STALE_PLUGIN_RE = re.compile(
    r"plugin_entrypoint depends on (\S+)\s+(\S+)\s+which doesn't match",
)


def _detect_stale_plugin_version(output: str) -> tuple[str, str] | None:
    """Check analyze output for a stale plugin version error.

    Returns (package_name, stale_version) if found, else None.
    """
    m = _STALE_PLUGIN_RE.search(output)
    if m:
        return m.group(1), m.group(2)
    return None


def get_latest_published_version(package_name: str) -> str | None:
    """Query pub.dev for the latest published version of *package_name*."""
    import json
    import urllib.request
    import urllib.error

    url = f"https://pub.dev/api/packages/{package_name}"
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            return data["latest"]["version"]
    except (urllib.error.URLError, KeyError, json.JSONDecodeError):
        return None


def verify_pubdev_publication(
    package_name: str,
    expected_version: str,
    interval_seconds: int = 30,
    timeout_seconds: int = 300,
) -> bool:
    """Poll pub.dev API until the package reports the expected version.

    Checks every *interval_seconds* for up to *timeout_seconds*.
    Returns True when pub.dev reports *expected_version*, False on timeout.
    """
    # Labeled "FINAL STEP:" so it matches the parallel extension store check.
    # The run_full_publish pipeline calls this at the very end alongside the
    # Marketplace/Open VSX verification so both availability checks are the
    # literal last thing the user sees before the success banner.
    print_header("FINAL STEP: PUB.DEV AVAILABILITY CHECK")
    print_info(
        f"Polling pub.dev every {interval_seconds}s for up to "
        f"{timeout_seconds // 60} minutes..."
    )
    attempts = (timeout_seconds // interval_seconds) + 1

    for attempt in range(1, attempts + 1):
        latest = get_latest_published_version(package_name)
        display = latest or "unavailable"

        if latest == expected_version:
            print_success(
                f"pub.dev reports v{latest} — publication confirmed."
            )
            return True

        print_info(
            f"Attempt {attempt}/{attempts}: pub.dev latest = {display}"
        )
        if attempt < attempts:
            time.sleep(interval_seconds)

    print_warning(
        f"pub.dev did not report v{expected_version} within "
        f"{timeout_seconds // 60} minutes (last seen: {display}). "
        "Check https://pub.dev/packages/"
        f"{package_name} manually."
    )
    return False


def _get_plugin_manager_dir() -> Path | None:
    """Return the Dart analysis-server plugin-manager cache directory."""
    if is_windows():
        local = os.environ.get("LOCALAPPDATA")
        if local:
            return Path(local) / ".dartServer" / ".plugin_manager"
    else:
        home = Path.home()
        return home / ".dartServer" / ".plugin_manager"
    return None


def update_analysis_options_plugin_version(
    project_dir: Path,
    package_name: str,
    new_version: str,
) -> bool:
    """Update the plugin version in analysis_options.yaml.

    Looks for ``version: "X.Y.Z"`` under ``plugins: <package_name>:``
    and replaces it with *new_version*.  Returns True if updated.
    """
    ao_path = project_dir / "analysis_options.yaml"
    if not ao_path.exists():
        return False
    content = ao_path.read_text(encoding="utf-8")
    # Match:  version: "X.Y.Z"  (under the plugin section)
    pattern = re.compile(
        rf"(plugins:\s*\n\s+{re.escape(package_name)}:\s*\n"
        rf'(?:.*\n)*?\s+version:\s*")[^"]+(")',
        re.MULTILINE,
    )
    updated, count = pattern.subn(rf"\g<1>{new_version}\2", content)
    if count == 0:
        # Simpler fallback: just replace the version line directly
        simple = re.compile(r'(\bversion:\s*")[^"]+(")')
        updated, count = simple.subn(
            rf"\g<1>{new_version}\2", content, count=1,
        )
    if count == 0:
        return False
    ao_path.write_text(updated, encoding="utf-8")
    return True


def _is_mid_publish_stale_plugin(
    project_dir: Path,
    combined: str,
) -> bool:
    """True if the analyze failure is the mid-publish matching-version case.

    Mid-publish state: ``analysis_options.yaml``'s plugin version equals
    ``pubspec.yaml``'s version, but pub.dev still has an older latest.
    This is the normal state of a release commit before
    ``dart pub publish`` finishes — there is no actual lint failure, only
    a known transient plugin-resolution error. Treating it as a pass lets
    the audit proceed without an interactive prompt the user can only
    answer one way ([I]gnore).

    The prior fix only suppressed the [F]/[S] downgrade prompt; the
    audit still hit the [I/R/A] prompt because ``dart analyze`` exits
    non-zero. This check lets the caller short-circuit that prompt too.
    """
    stale = _detect_stale_plugin_version(combined)
    if stale is None:
        return False
    pkg_name, stale_ver = stale
    if pkg_name != "saropa_lints":
        return False
    pubspec_path = project_dir / "pubspec.yaml"
    if not pubspec_path.exists():
        return False
    try:
        pubspec_ver = get_version_from_pubspec(pubspec_path)
    except (ValueError, OSError):
        return False
    # The analyze error reports the dependency as a version *constraint*
    # (e.g. "^14.0.0"), while pubspec.yaml holds a bare version
    # ("14.0.0"). Strip any leading constraint operator before comparing
    # so the mid-publish state (local version satisfies the plugin's own
    # caret constraint) is recognized. Without this, the caret made the
    # equality check fail, so the guard fell through to the [F]/[S] fix
    # prompt — which can never resolve when the package dogfoods itself:
    # its analysis_options.yaml has no plugin version pin to edit, so the
    # "fix" clears the cache, retries, and loops on the same prompt
    # forever.
    bare_stale = stale_ver.lstrip("^~>=< ")
    return pubspec_ver == bare_stale


def _try_fix_stale_plugin_cache(
    project_dir: Path,
    combined: str,
) -> bool:
    """Detect and offer to fix a stale analyzer-plugin cache.

    If the dart-analyze output contains a plugin version-resolution
    error, query pub.dev for the latest version, update
    ``analysis_options.yaml``, and clear the plugin-manager cache.

    Returns True if a fix was applied (caller should retry analyze).

    Note: callers should check :func:`_is_mid_publish_stale_plugin` first
    and skip this prompt entirely in that case — offering to "downgrade"
    mid-publish would silently undo the release commit's version bump.
    """
    import shutil

    stale = _detect_stale_plugin_version(combined)
    if stale is None:
        return False

    pkg_name, stale_ver = stale

    print_warning(
        f"Stale analyzer-plugin cache: plugin requires "
        f"{pkg_name} {stale_ver} which is not available."
    )

    latest = get_latest_published_version(pkg_name)
    if latest is None:
        print_error(
            f"Could not query pub.dev for latest {pkg_name} version."
        )
        return False

    print_info(f"Latest published {pkg_name} version: {latest}")
    print_colored(
        f"  [F]ix automatically (update analysis_options.yaml to "
        f"{latest}, clear plugin cache, and retry)",
        Color.CYAN,
    )
    print_colored("  [S]kip (continue with failure)", Color.CYAN)
    try:
        raw = input("  Choice [f/s]: ").strip().lower() or "s"
    except (EOFError, KeyboardInterrupt):
        return False

    if not raw.startswith("f"):
        return False

    # Apply fix: update version in analysis_options.yaml
    if update_analysis_options_plugin_version(
        project_dir, pkg_name, latest,
    ):
        print_success(
            f"Updated analysis_options.yaml plugin version to {latest}"
        )
    else:
        print_warning(
            "Could not update analysis_options.yaml "
            "(version field not found)"
        )

    # Clear plugin-manager cache so the analysis server re-resolves
    pm_dir = _get_plugin_manager_dir()
    if pm_dir and pm_dir.exists():
        shutil.rmtree(pm_dir, ignore_errors=True)
        print_success("Cleared analyzer plugin-manager cache")

    return True


# Limit how many diagnostic lines we print to console (rest are in log)
_MAX_ANALYSIS_REPORT_LINES = 30


def _print_analysis_diagnostics(combined: str) -> None:
    """Print diagnostic lines (error/warning/info) from dart analyze output."""
    lines = []
    for line in combined.splitlines():
        stripped = line.strip()
        if re.match(r"^(error|warning|info)\s+-\s+", stripped, re.IGNORECASE):
            lines.append(stripped)
    if not lines:
        return
    print_colored("  Issues:", Color.BOLD)
    for line in lines[:_MAX_ANALYSIS_REPORT_LINES]:
        if line.lower().startswith("error"):
            print_colored(f"    {line}", Color.RED)
        elif line.lower().startswith("warning"):
            print_colored(f"    {line}", Color.YELLOW)
        else:
            print_colored(f"    {line}", Color.CYAN)
    if len(lines) > _MAX_ANALYSIS_REPORT_LINES:
        print_colored(
            f"    ... and {len(lines) - _MAX_ANALYSIS_REPORT_LINES} more (see log)",
            Color.DIM,
        )


def _spinner_while(running: threading.Event, message: str = "Working") -> None:
    """Print a spinning indicator until running is cleared (daemon thread)."""
    chars = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    idx = 0
    while running.is_set():
        sys.stdout.write(f"\r  {chars[idx % len(chars)]} {message}...   ")
        sys.stdout.flush()
        idx += 1
        time.sleep(0.08)
    sys.stdout.write("\r" + " " * (len(message) + 12) + "\r")
    sys.stdout.flush()


def run_pre_publish_audits(project_dir: Path) -> tuple[bool, object]:
    """Run all audits before publish. Returns (True, None) if publish can proceed.

    On failure returns (False, audit_result) so callers can fix e.g. missing prefix.

    BLOCKING checks (fail = no publish):
      - Tier integrity: orphans, phantoms, multi-tier, misplaced opinionated,
        flutterStylisticRules subset, package rule consistency,
        example pairing
      - Duplicate rule names, class names, or aliases
      - Missing [rule_name] prefix in problemMessage
      - British English spellings (US English required)

    AUTO-FIX (runs first, before blocking checks):
      - Doc comment angle brackets and references
      - Roadmap: remove task files for rules already in tiers.dart

    INFORMATIONAL checks (warn but don't block):
      - DX message quality
      - OWASP coverage gaps
      - ROADMAP sync
      - Quality metrics
    """
    from scripts.modules._audit import run_full_audit

    # --- AUTO-FIX: Doc comment issues (before blocking checks) ---
    pubdev_issues = check_pubdev_lint_issues(project_dir)
    if pubdev_issues:
        print_info(
            f"Found {len(pubdev_issues)} pub.dev doc issue(s), "
            f"auto-fixing..."
        )
        fixed_brackets = fix_doc_angle_brackets(project_dir)
        fixed_refs = fix_doc_references(project_dir)
        total_fixed = fixed_brackets + fixed_refs
        if total_fixed:
            print_success(
                f"Auto-fixed {total_fixed} doc issue(s) "
                f"({fixed_brackets} angle bracket(s), "
                f"{fixed_refs} reference(s))"
            )
        remaining = check_pubdev_lint_issues(project_dir)
        if remaining:
            print_warning(
                f"{len(remaining)} unfixable doc issue(s) remain "
                f"(will be caught by analysis step)"
            )
    else:
        print_success("No pub.dev doc issues found")

    # --- AUTO-FIX: Apply dart fix for auto-fixable lint issues ---
    # shell=get_shell_mode() is required on Windows: `dart` resolves to
    # dart.bat, which CreateProcess cannot launch directly without a shell.
    dart_fix_result = subprocess.run(
        ['dart', 'fix', '--dry-run'],
        capture_output=True, text=True, timeout=300,
        cwd=str(project_dir),
        shell=get_shell_mode(),
    )
    dart_fix_output = dart_fix_result.stdout + dart_fix_result.stderr
    fix_match = re.search(r'(\d+)\s+fix', dart_fix_output)
    if fix_match and int(fix_match.group(1)) > 0:
        print_warning(
            f"{fix_match.group(1)} auto-fixable dart issue(s) found, applying..."
        )
        subprocess.run(
            ['dart', 'fix', '--apply'],
            capture_output=True, text=True, timeout=300,
            cwd=str(project_dir),
            shell=get_shell_mode(),
        )
        print_success("Auto-fixed dart lint issues")
    else:
        print_success("No auto-fixable dart issues")

    # --- AUTO-FIX: Remove roadmap task files for implemented rules ---
    from scripts.modules._roadmap_implemented import check_and_fix_roadmap_implemented

    removed_rules, had_stale = check_and_fix_roadmap_implemented(
        project_dir, fix=True
    )
    if had_stale:
        print_success(
            f"Removed {len(removed_rules)} stale roadmap task(s): "
            f"{', '.join(removed_rules[:8])}"
            + (f" ... +{len(removed_rules) - 8}" if len(removed_rules) > 8 else "")
        )

    # --- US English spelling check (run before audit to feed into checks) ---
    from scripts.modules._us_spelling import (
        print_spelling_report,
        scan_directory,
    )

    spelling_hits = scan_directory(project_dir)
    # British spellings ALWAYS block the publish — there is no "ship with
    # hits" path. A bypassable gate (the old [I]gnore option) is exactly
    # why British spellings kept reaching pub.dev; see
    # bugs/british_english_recurrence_attempts.md. The dev may Retry (fix
    # in place, then re-scan) or Abort; either way the publish stays
    # blocked until the tree is clean. The pre-commit hook should catch
    # these long before here — this gate is the final hard backstop.
    while spelling_hits:
        print_spelling_report(spelling_hits, project_dir)
        if not _prompt_spelling_retry():
            # Abort / non-interactive: leave hits in place so the gate blocks.
            break
        print_info("Re-scanning for British spellings...")
        spelling_hits = scan_directory(project_dir)

    spelling_blocks = bool(spelling_hits)

    spelling_check: list[tuple[str, str, list[str]]] = []
    if spelling_hits:
        spelling_check.append((
            "fail",
            f"{len(spelling_hits)} British English spelling(s) found",
            [f"{h.file}:{h.line_number} — {h.uk_word} → {h.us_word}"
             for h in spelling_hits[:10]],
        ))
    else:
        spelling_check.append((
            "pass", "No British English spellings found", [],
        ))

    # --- Known-issues freshness + manual-review report (known_issues.json vs
    # live pub.dev) ---
    # Non-blocking: both depend on a third-party API, so a pub.dev outage or
    # CI network restriction must not stop a publish. The freshness half
    # surfaces the class of defect fixed 2026-08-18 (timezone flagged
    # "pre-null-safety" long after it shipped a null-safe release) so it's
    # caught before it goes stale for months. The review-report half
    # regenerates plans/known_issues_review.md on every publish instead of
    # only on manual invocation — a standalone-only tool goes stale exactly
    # like the data it's meant to catch going stale.
    #
    # run_known_issues_checks() fetches pub.dev data once for the union of
    # both checks' candidates (the review set is a superset of the freshness
    # set) and derives both results from that single pass, so wiring the
    # broader ~302-entry review scan into publish doesn't roughly double the
    # network cost of the ~70-entry freshness scan that was already here.
    from scripts.modules._known_issues_review_report import (
        render_markdown,
        run_known_issues_checks,
    )

    known_issues_check: list[tuple[str, str, list[str]]] = []
    # timeout=5.0 bounds the worst case (pub.dev fully unreachable) to roughly
    # 4 sequential-batch rounds x 2 requests x 5s ~= 40s added to the publish,
    # instead of the minutes a 15s timeout would allow across ~302 candidates.
    # Any unexpected exception here must not block a publish over third-party
    # API tooling, so it's caught and reported as an inconclusive run rather
    # than raised.
    try:
        freshness_result, review_report = run_known_issues_checks(
            project_dir, timeout=5.0
        )
    except Exception as exc:  # noqa: BLE001 (see comment above)
        known_issues_check.append((
            "warn",
            f"known_issues.json freshness check errored ({exc}); skipped",
            [],
        ))
    else:
        if freshness_result.has_confirmed_stale:
            known_issues_check.append((
                "warn",
                f"{len(freshness_result.confirmed_stale)} known_issues.json "
                f"entrie(s) contradicted by current pub.dev data",
                [f"{s['name']}: {s['reason']}" for s in freshness_result.confirmed_stale[:10]],
            ))
        else:
            known_issues_check.append((
                "pass",
                f"known_issues.json: {freshness_result.checked_count} "
                f"lifecycle claim(s) still consistent with pub.dev",
                [],
            ))

        # Regenerating the review report itself must not block a publish
        # either — a disk-write failure or a report-rendering bug is a
        # tooling defect, not a reason to stop shipping.
        try:
            review_path = project_dir / "plans" / "known_issues_review.md"
            review_path.parent.mkdir(parents=True, exist_ok=True)
            review_path.write_text(
                render_markdown(review_report, generated_on="(regenerated at publish time)"),
                encoding="utf-8",
            )
        except Exception as exc:  # noqa: BLE001 (see comment above)
            known_issues_check.append((
                "warn",
                f"known_issues_review.md regeneration errored ({exc}); skipped",
                [],
            ))
        else:
            if review_report.entries:
                known_issues_check.append((
                    "warn",
                    f"known_issues_review.md: {len(review_report.entries)} "
                    f"entrie(s) queued for manual triage "
                    f"(plans/known_issues_review.md regenerated)",
                    [],
                ))

    # --- Full audit (includes tier integrity + quality checks) ---
    audit_result = run_full_audit(
        project_dir=project_dir,
        skip_dx=False,
        compact=True,
        extra_checks=spelling_check + known_issues_check,
    )

    # --- Run dart analyze as part of audit (fail fast; same as Step 6) ---
    if not audit_result.has_blocking_issues and not spelling_blocks:
        analysis_result = run_analysis_with_prompt(
            project_dir,
            step_header="STEP 1 (cont.): DART ANALYZE",
            do_doc_check=False,
        )
        if analysis_result == "abort":
            audit_result.analysis_passed = False
        elif analysis_result == "ignore":
            audit_result.analysis_passed = True  # Don't block; user chose to continue

    # --- Blocking issues gate ---
    if audit_result.has_blocking_issues or spelling_blocks:
        if audit_result.has_blocking_issues:
            print_error("Blocking audit issues found.")
            # Report which categories are blocking so users know what to fix
            blocking_reasons: list[str] = []
            if not audit_result.tier_integrity_passed:
                blocking_reasons.append("Tier integrity (orphans, phantoms, "
                    "multi-tier, or other tier checks — see ✗ above)")
            dup = audit_result.duplicate_report
            if dup.get("class_names") or dup.get("rule_names") or dup.get("aliases"):
                blocking_reasons.append("Duplicate class names, rule names, or aliases")
            if audit_result.rules_missing_prefix:
                blocking_reasons.append(
                    f"Rules missing [rule_name] prefix ({len(audit_result.rules_missing_prefix)} rule(s))"
                )
            if getattr(audit_result, "contains_audit_over_baseline", False):
                blocking_reasons.append(".contains() counts over baseline (CI would fail)")
            if not audit_result.analysis_passed:
                blocking_reasons.append(
                    "dart analyze failed (--fatal-infos); fix issues in report above"
                )
            if not getattr(audit_result, "stub_guard_passed", True):
                blocking_reasons.append(
                    "Stub-test guard failed: always-pass stub tests present "
                    "(empty-body or tautology) — see test/integrity/stub_test_guard_test.dart"
                )
            for reason in blocking_reasons:
                print_error(f"  • {reason}")
        if spelling_blocks:
            print_spelling_report(
                spelling_hits, project_dir, show_header=False,
            )
        return False, audit_result

    print()
    print_success("Pre-publish audit step complete.")
    return True, None


def check_prerequisites() -> bool:
    """Step 2: Check that required tools are available."""
    print_header("STEP 2: CHECKING PREREQUISITES")

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
    """Step 3: Check working tree status.

    Returns:
        (ok, has_uncommitted_changes)
    """
    print_header("STEP 3: CHECKING WORKING TREE")

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
                "release commit. Continue? [Y/n] "
            )
            .strip()
            .lower()
        )
        if response.startswith("n"):
            return False, True
        return True, True

    print_success("Working tree is clean")
    return True, False


def _ask_remote_sync_recovery(
    project_dir: Path,
    branch: str,
    use_shell: bool,
    behind_count: int,
    *,
    unrelated: bool = False,
) -> bool:
    """When pull fails, ask user how to proceed. Returns True to continue."""
    print()
    print_colored(
        "  Sync failed. What do you want to do?",
        Color.CYAN,
    )
    if unrelated:
        print_colored(
            "  (Reset is recommended when local and remote have unrelated "
            "histories.)",
            Color.CYAN,
        )
    print_colored(
        "    1) Reset local branch to remote (git reset --hard origin/"
        f"{branch})\n"
        "       → Discards local commit history on this branch; "
        "uncommitted changes to tracked files may be lost.\n"
        "    2) Continue without syncing (push may fail later)\n"
        "    3) Abort",
        Color.CYAN,
    )
    try:
        raw = input("  Choice [1]: ").strip() or "1"
    except (KeyboardInterrupt, EOFError):
        print()
        return False
    choice = raw.strip().lower()
    if choice == "2":
        print_warning("Continuing without syncing.")
        return True
    if choice == "3" or choice not in ("1", ""):
        print_info("Aborting. Fix sync manually (e.g. git fetch && git reset --hard origin/main) and re-run publish.")
        return False
    # Choice 1: reset to remote
    print_info(f"Resetting local {branch} to origin/{branch}...")
    reset_result = subprocess.run(
        ["git", "reset", "--hard", f"origin/{branch}"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )
    if reset_result.returncode != 0:
        print_error("Reset failed.")
        if reset_result.stderr:
            print_colored(reset_result.stderr, Color.RED)
        return False
    print_success(f"Local branch reset to remote ({behind_count} commit(s) applied).")
    return True


def check_remote_sync(project_dir: Path, branch: str) -> bool:
    """Step 4: Check if local branch is in sync with remote."""
    print_header("STEP 4: CHECKING REMOTE SYNC")

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
        stderr_text = (result.stderr or "").strip()
        if "couldn't find remote ref" in stderr_text:
            print_info(
                f"Branch {branch} not on remote yet. Trying 'git fetch origin'..."
            )
        else:
            if stderr_text:
                print_colored(stderr_text, Color.RED)
            if result.stdout and result.stdout.strip():
                print_colored(result.stdout.strip(), Color.RED)
            print_info("Trying 'git fetch origin' (all refs)...")
        fallback = subprocess.run(
            ["git", "fetch", "origin"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if fallback.returncode != 0:
            print_warning("Could not fetch from remote. Proceeding anyway.")
            if fallback.stderr:
                print_colored(fallback.stderr.strip(), Color.RED)
            return True
        print_success("Fetched from remote.")

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
                unrelated = "unrelated histories" in (
                    pull_result.stderr or ""
                ).lower()
                if unrelated:
                    print_info(
                        "Local and remote branches have unrelated histories "
                        "(e.g. history was rewritten or repo recreated)."
                    )
                return _ask_remote_sync_recovery(
                    project_dir,
                    branch,
                    use_shell,
                    behind_count,
                    unrelated=unrelated,
                )
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


def _dart_test_env(project_dir: Path) -> dict[str, str]:
    """Return env with TMP/TEMP redirected so test kernel files don't fill system temp.

    Override: set SAROPA_TEST_TMP to an absolute path outside the project tree.
    Default: <system temp>/saropa_dart_test (tempfile.gettempdir(), which
    honors the existing TMP/TEMP on the machine).

    Must NOT be inside the project tree — ScanRunner scans the working directory
    recursively, so kernel-cache .dill files in a project-local temp dir produce
    spurious uri_does_not_exist errors.
    """
    override = os.environ.get("SAROPA_TEST_TMP")
    test_tmp = Path(override) if override else Path(tempfile.gettempdir()) / "saropa_dart_test"
    # Guard: temp dir must not be inside the project tree, or the scanner will
    # pick up kernel-cache .dill files and report uri_does_not_exist errors.
    try:
        resolved = test_tmp.resolve()
        project_resolved = project_dir.resolve()
        if resolved == project_resolved or project_resolved in resolved.parents:
            print_warning(
                f"SAROPA_TEST_TMP ({test_tmp}) is inside the project tree — "
                f"falling back to system temp to avoid scanner interference."
            )
            test_tmp = Path(tempfile.gettempdir()) / "saropa_dart_test"
    except OSError:
        pass
    # Wipe stale contents before every run rather than accumulating .dill
    # kernel-cache files across publish attempts — this dir is exclusively
    # ours (never user data), so a full wipe is safe and prevents the same
    # disk-fill failure mode that motivated moving it out of build/ (root
    # cause 2 of the crash this was originally written to fix).
    if test_tmp.exists():
        import shutil
        shutil.rmtree(test_tmp, ignore_errors=True)
    test_tmp.mkdir(parents=True, exist_ok=True)
    # Verify the directory is actually writable before handing it to dart
    # test — catches permission issues or an unsupported path (e.g. a TMP
    # override on a read-only mount) up front instead of surfacing as an
    # opaque test-runner crash.
    probe_path = test_tmp / ".write_probe"
    try:
        probe_path.write_text("ok", encoding="utf-8")
        probe_path.unlink()
    except OSError as exc:
        print_warning(
            f"Test temp dir {test_tmp} is not writable ({exc}) — "
            f"falling back to system temp."
        )
        test_tmp = Path(tempfile.gettempdir()) / "saropa_dart_test"
        test_tmp.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["TMP"] = str(test_tmp)
    env["TEMP"] = str(test_tmp)
    return env


def _read_log_text(log_path: Path) -> str:
    """Read a log file as UTF-8, returning empty string on missing/unreadable files."""
    if not log_path.exists():
        return ""
    try:
        return log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _log_shows_windows_file_lock(log_path: Path) -> bool:
    """True if the log indicates a transient Windows file-lock (PathAccessException / errno 32)."""
    text = _read_log_text(log_path)
    if not text:
        return False
    return (
        "PathAccessException" in text
        or "being used by another process" in text
        or "errno = 32" in text
    )


def _log_shows_vm_crash(log_path: Path) -> bool:
    """True if the log indicates a Dart VM or compiler crash.

    Covers three crash families:
    1. VM heap corruption — "Corrupt heap", "Invalid cid:", "raw_object.cc"
    2. front_end compiler crash — "Crash when compiling",
       "NamedTypeBuilderImpl", "Cannot remove from a fixed-length list"
    3. Native access violation — the process dies mid-write and the log
       contains null bytes (STATUS_ACCESS_VIOLATION on Windows)

    All three kill the test runner, causing subsequent test files to report
    "Failed to load" with no message. They are transient infrastructure
    failures unrelated to code correctness.
    """
    # Check for native crash: null bytes in the log mean the process died
    # with a native fault (STATUS_ACCESS_VIOLATION) before flushing. The
    # crash leaves unflushed null-filled data at the tail of the log (valid
    # test output precedes it), so read the last 25% (min 8 KB).
    # Require >=16 null bytes to avoid false positives from tests that
    # legitimately print a stray null character in their output.
    if log_path.exists():
        try:
            size = log_path.stat().st_size
            check_size = max(8192, size // 4)
            with open(log_path, "rb") as f:
                f.seek(max(0, size - check_size))
                tail = f.read(check_size)
            if tail.count(b"\x00") >= 16:
                return True
        except OSError:
            pass
    text = _read_log_text(log_path)
    if not text:
        return False
    return (
        # VM heap corruption
        "Corrupt heap" in text
        or "Invalid cid:" in text
        or "EXCEPTION CAUGHT BY VM" in text
        or "raw_object.cc" in text
        # front_end compiler crash (Dart SDK bug in incremental compilation)
        or "Crash when compiling" in text
        or "Cannot remove from a fixed-length list" in text
        or "NamedTypeBuilderImpl" in text
    )


def _log_transient_failure_reason(log_path: Path) -> str | None:
    """Return a human-readable reason if the log only shows transient failures, else None.

    Detects Windows file locks and Dart VM crashes — both are infrastructure
    flakes that disappear on retry and never indicate a code defect.
    """
    has_file_lock = _log_shows_windows_file_lock(log_path)
    has_vm_crash = _log_shows_vm_crash(log_path)
    if not has_file_lock and not has_vm_crash:
        return None
    # Build a combined reason string
    reasons: list[str] = []
    if has_vm_crash:
        reasons.append("Dart VM/compiler crash")
    if has_file_lock:
        reasons.append("Windows file-lock race (PathAccessException)")
    return " + ".join(reasons)


def _run_chain_stack_traces_and_check(
    project_dir: Path,
    env: dict[str, str] | None,
    extra_args: list[str] | None = None,
) -> bool:
    """Run dart test --chain-stack-traces, pipe output to a log file, then check for error lines.

    Used in Step 7 when plain 'dart test' fails. Writes to reports/YYYYMMDD/YYYYMMDD_HHMMSS_chain_stack_traces.log.
    Shows a spinner while the subprocess runs. Calls _check_log_for_errors to print failure lines (cap 50).
    Retries once if the log shows transient failures (VM heap crash or Windows file lock).

    Returns:
        True iff the test process exited with code 0. False if non-zero exit or if subprocess/open raised.
    """
    use_shell = get_shell_mode()
    max_attempts = 2
    last_result = None
    last_log_path = None
    last_date_str = None
    last_log_name = None
    # Track concurrency across attempts so crash retries can halve it.
    diag_j = min(os.cpu_count() or 8, 8)

    for attempt in range(max_attempts):
        now = datetime.now()
        date_str = now.strftime("%Y%m%d")
        time_str = now.strftime("%H%M%S")
        reports_dir = project_dir / "reports" / date_str
        reports_dir.mkdir(parents=True, exist_ok=True)
        log_name = f"{date_str}_{time_str}_chain_stack_traces.log"
        log_path = reports_dir / log_name
        if attempt > 0:
            print_info(
                f"Retrying dart test --chain-stack-traces "
                f"(-j {diag_j}, output → reports/{date_str}/{log_name})"
            )
        else:
            print_info(
                f"Running dart test --chain-stack-traces "
                f"(-j {diag_j}, output → reports/{date_str}/{log_name})"
            )
        running = threading.Event()
        running.set()
        spinner = threading.Thread(
            target=_spinner_while,
            args=(running, "Tests"),
            daemon=True,
        )
        spinner.start()
        result = None
        try:
            with open(log_path, "w", encoding="utf-8") as out:
                result = subprocess.run(
                    [
                        "dart", "test", "--chain-stack-traces",
                        "-j", str(diag_j),
                        *(extra_args or []),
                    ],
                    cwd=project_dir,
                    stdout=out,
                    stderr=subprocess.STDOUT,
                    env=env,
                    shell=use_shell,
                )
        finally:
            running.clear()
            spinner.join(timeout=0.5)
        last_result = result
        last_log_path = log_path
        last_date_str = date_str
        last_log_name = log_name

        if result is not None and result.returncode != 0 and log_path.exists():
            try:
                with open(log_path, "a", encoding="utf-8") as ap:
                    ap.write(f"\n[Tests failed — exit code {result.returncode}.]\n")
            except OSError:
                pass
        if result is not None and result.returncode == 0:
            return True
        # Retry once on transient failures: Windows file locks or Dart VM
        # crashes. Halve concurrency on compiler crash to reduce pressure.
        if attempt == 0:
            transient = _log_transient_failure_reason(log_path)
            if transient:
                if _log_shows_vm_crash(log_path):
                    diag_j = max(1, diag_j // 2)
                print_warning(
                    f"Transient failure detected: {transient}. "
                    f"Retrying with -j {diag_j}..."
                )
                continue
        break

    _check_log_for_errors(last_log_path, last_date_str, last_log_name)
    return (
        last_result.returncode == 0
        if last_result is not None
        else False
    )


# High-signal lines first; avoid matching every compact line after a failure.
_TEST_FAILURE_MARKERS_PRIMARY = (
    "Expected:",
    "Actual:",
    "which was",
    "TestFailure",
    "FAILED",
    "Some tests failed",
    "Error:",
    "Exception",
    "Bad state",
    "Corrupt heap",
    "PathAccessException",
    "Failed to load",
)
# Compact reporter: only useful if primary markers did not capture the real error.
_TEST_FAILURE_MARKERS_COMPACT = (
    " -1: ",  # "00:09 +7332 -1: test\\foo_test.dart: test name"
)


def _extract_failure_excerpt(log_path: Path, max_lines: int = 10) -> list[tuple[int, str]]:
    """Read log file and return up to max_lines (line_no, content) that match failure markers."""
    if not log_path.exists():
        return []
    try:
        text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    lines = text.splitlines()

    def _collect(markers: tuple[str, ...]) -> list[tuple[int, str]]:
        out: list[tuple[int, str]] = []
        for i, line in enumerate(lines):
            for marker in markers:
                if marker in line:
                    out.append((i + 1, line.strip()))
                    break
        return out

    primary = _collect(_TEST_FAILURE_MARKERS_PRIMARY)
    if primary:
        return primary[:max_lines]
    return _collect(_TEST_FAILURE_MARKERS_COMPACT)[:max_lines]


# Dart test compact-reporter progress pattern: "HH:MM +N: ..." or "HH:MM +N -M: ..."
_DART_PROGRESS_RE = re.compile(
    r"^(\d{2}:\d{2})\s+\+(\d+)(?:\s+(?:~(\d+)))?(?:\s+(?:-(\d+)))?\s*:\s*(.*)"
)

def _run_dart_test_to_file(
    project_dir: Path,
    env: dict[str, str] | None,
    log_path: Path,
    extra_args: list[str] | None = None,
    concurrency: int | None = None,
) -> int:
    """Run dart test, streaming a single-line progress bar to the terminal.

    The progress line overwrites itself in-place (carriage return) showing
    elapsed time, pass/skip/fail counts, and the current test name. All
    output goes to log_path for post-mortem; only the progress line and a
    final summary appear on screen.

    extra_args appends tag selectors (e.g. ['-x', 'slow'] or ['-t', 'slow']) so the
    caller can split the suite into a fast pass and a slow pass.
    concurrency overrides -j (default: min(cpu_count, 8)).

    On non-zero exit, appends a line to the log so the file explicitly records that tests failed.
    """
    use_shell = get_shell_mode()
    # Cap at 8 workers by default: the Dart kernel compiler crashes with a
    # native access violation or front_end exception when too many
    # frontend_server compile workers run in parallel on Windows.
    cores = concurrency or min(os.cpu_count() or 8, 8)
    cmd = ["dart", "test", "-j", str(cores)]
    if extra_args:
        cmd.extend(extra_args)

    # Stream output line-by-line: log everything, show only progress on terminal.
    proc = subprocess.Popen(
        cmd,
        cwd=project_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
        shell=use_shell,
    )

    # Track whether we have an active CR-overwritten progress line on screen.
    wrote_progress = False
    # Last parsed counts for the final summary line.
    last_elapsed = ""
    last_passed = "0"
    last_skipped = None
    last_failed = None

    with open(log_path, "w", encoding="utf-8", errors="replace") as log_f:
        for raw_line in proc.stdout:
            line = raw_line.decode("utf-8", errors="replace")
            # Always write full output to the log file.
            log_f.write(line)

            stripped = line.rstrip("\n\r")
            if not stripped:
                continue

            # Parse compact-reporter progress (e.g. "00:12 +42 -1: test name").
            m = _DART_PROGRESS_RE.match(stripped)
            if not m:
                continue

            last_elapsed = m.group(1)
            last_passed = m.group(2)
            last_skipped = m.group(3)
            last_failed = m.group(4)
            test_name = m.group(5)

            # Build compact status: time +pass ~skip -fail: test_name
            parts = [f"{last_elapsed} +{last_passed}"]
            if last_skipped:
                parts.append(f"~{last_skipped}")
            if last_failed and last_failed != "0":
                parts.append(f"-{last_failed}")
            status = " ".join(parts) + f": {test_name}"

            # Truncate to terminal width so the line never wraps.
            try:
                cols = os.get_terminal_size().columns
            except OSError:
                cols = 120
            if len(status) > cols - 1:
                status = status[: cols - 4] + "..."

            # Carriage-return overwrite for single-line progress.
            sys.stdout.write(f"\r{status}\033[K")
            sys.stdout.flush()
            wrote_progress = True

    # Clear the in-place progress line before printing the final summary.
    if wrote_progress:
        sys.stdout.write("\r\033[K")

    # Print a permanent one-line summary with final counts.
    parts = [f"{last_elapsed} +{last_passed}"]
    if last_skipped:
        parts.append(f"~{last_skipped}")
    if last_failed and last_failed != "0":
        parts.append(f"-{last_failed}")
    final = " ".join(parts)
    if last_failed and last_failed != "0":
        print_colored(f"  Result: {final}", Color.RED)
    else:
        print_colored(f"  Result: {final}", Color.GREEN)
    sys.stdout.flush()

    returncode = proc.wait()
    if returncode != 0:
        with open(log_path, "a", encoding="utf-8") as ap:
            ap.write(f"\n[Tests failed — exit code {returncode}.]\n")
    return returncode


def _prompt_test_failure(is_crash: bool = False) -> str:
    """Ask user what to do after tests failed.

    Returns 'continue' | 'retry' | 'retry_fewer' | 'abort'.
    When is_crash is True, offers a "retry with fewer workers" option that
    halves the concurrency to work around compiler crashes.
    """
    print_warning("Tests failed. Choose an action:")
    print_colored("  [R]etry (re-run tests after fixing the issue)", Color.CYAN)
    if is_crash:
        print_colored(
            "  [F]ewer workers (retry with halved concurrency — fixes compiler crashes)",
            Color.CYAN,
        )
    print_colored("  [C]ontinue anyway (proceed with publish)", Color.CYAN)
    print_colored("  [A]bort (stop publish)", Color.CYAN)
    prompt = "  Choice [r/f/c/a]: " if is_crash else "  Choice [r/c/a]: "
    try:
        raw = input(prompt).strip().lower() or "a"
        if raw.startswith("r"):
            return "retry"
        if is_crash and raw.startswith("f"):
            return "retry_fewer"
        if raw.startswith("c"):
            return "continue"
        if raw.startswith("a"):
            return "abort"
    except (EOFError, KeyboardInterrupt):
        return "abort"
    return "abort"


def _check_log_for_errors(log_path: Path, date_str: str, log_name: str) -> None:
    """Open the chain-stack-traces log and print lines that indicate failures.

    Scans for markers: FAILED, Some tests failed, Error:, Exception, Expected:, Actual:, which was, Bad state.
    Prints up to 50 matching lines with line numbers in red; if more, prints a truncation message.
    If no matches, prints an info line directing the user to the full log file.
    """
    if not log_path.exists():
        return
    try:
        text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        print_warning(f"Could not read {log_path}")
        return
    lines = text.splitlines()
    error_markers = (
        "FAILED",
        "Some tests failed",
        "failed",
        "Error:",
        "Exception",
        "Expected:",
        "Actual:",
        "which was",
        "Bad state",
        "Corrupt heap",
        "PathAccessException",
        "Failed to load",
    )
    found = []
    for i, line in enumerate(lines):
        for marker in error_markers:
            if marker in line:
                found.append((i + 1, line.strip()))
                break
    if found:
        print_error(f"Failures in reports/{date_str}/{log_name}:")
        for line_no, content in found[:50]:
            print_colored(f"  {line_no}: {content}", Color.RED)
        if len(found) > 50:
            print_colored(f"  ... and {len(found) - 50} more (see full log)", Color.RED)
    else:
        print_info(
            f"Output saved to reports/{date_str}/{log_name} — no obvious error lines found; check file for full output."
        )


def _run_test_pass(
    project_dir: Path,
    env: dict[str, str] | None,
    reports_dir: Path,
    date_str: str,
    time_str: str,
    label: str,
    extra_args: list[str] | None = None,
    concurrency: int | None = None,
) -> bool:
    """Run one dart test pass (e.g. fast = exclude `slow`, slow = only `slow`).

    Runs once, retries once on failure, then prompts Continue/Retry/Abort exactly
    like the original single-pass flow. The label is woven into the log filename so
    the fast and slow passes write distinct logs under the same timestamp.

    concurrency overrides -j for the initial run (from auto-tune). Crash retries
    still halve it further.

    Returns True to continue the publish (the pass passed, or the user chose
    Continue), False to abort.
    """
    log_name = f"{date_str}_{time_str}_dart_test_{label}.log"
    log_path = reports_dir / log_name

    # Show the concurrency so crashes are diagnosable from the terminal.
    effective_j = concurrency or min(os.cpu_count() or 8, 8)
    print_info(
        f"Running {label} tests (-j {effective_j}, "
        f"output → reports/{date_str}/{log_name})"
    )
    returncode = _run_dart_test_to_file(
        project_dir, env, log_path, extra_args, concurrency=concurrency,
    )
    if returncode == 0:
        print_success(f"{label.capitalize()} tests passed.")
        return True

    # Only auto-retry when the failure looks transient (VM crash or file
    # lock) — a real test failure should go straight to the user instead of
    # silently doubling the wait time on a run that was never going to pass.
    # Also skip the automatic retry for the expensive full-suite ("fast")
    # pass: doubling a multi-minute 337-file compile without asking is the
    # exact behavior the user rejected. Cheap passes (delta, a handful of
    # files) still auto-retry since the cost of doing so is negligible.
    transient_reason = _log_transient_failure_reason(log_path)
    last_log = log_path
    last_j = concurrency or min(os.cpu_count() or 8, 8)
    if transient_reason and label != "fast":
        # On compiler crashes, halve concurrency for the retry — the crash is
        # caused by too many frontend_server workers running in parallel.
        initial_j = concurrency or min(os.cpu_count() or 8, 8)
        retry_j = max(initial_j // 2, 2) if _log_shows_vm_crash(log_path) else None
        print_warning(f"Transient failure detected: {transient_reason}")
        if retry_j:
            print_warning(f"Retrying with reduced concurrency (-j {retry_j})...")
        else:
            print_warning("Retrying tests once...")
        retry_name = f"{date_str}_{time_str}_dart_test_{label}_retry.log"
        retry_path = reports_dir / retry_name
        retry_code = _run_dart_test_to_file(
            project_dir, env, retry_path, extra_args, concurrency=retry_j,
        )
        if retry_code == 0:
            print_success(f"{label.capitalize()} tests passed on retry (confirmed transient).")
            return True
        last_log = retry_path
        last_j = retry_j or last_j

    # Real failure (or transient retry also failed) — enter the interactive
    # retry loop so the user decides whether to spend more time re-running.
    # Track the last concurrency used so "fewer workers" can halve it further.
    while True:
        # Surface transient failure diagnosis so the user knows Retry is safe.
        is_crash = _log_shows_vm_crash(last_log)
        current_transient = _log_transient_failure_reason(last_log)
        if current_transient:
            print_warning(f"⚠ Transient infrastructure failure: {current_transient}")
            print_info("  These failures are unrelated to code — Retry is recommended.")
        print_error(
            f"{label.capitalize()} tests failed (ran with -j {last_j}). "
            "Full output in log file (no test output was printed to this terminal)."
        )
        print_colored(f"  Log: {last_log.relative_to(project_dir)}", Color.CYAN)
        excerpt = _extract_failure_excerpt(last_log, max_lines=10)
        if excerpt:
            print_colored("  Excerpt:", Color.RED)
            for line_no, content in excerpt:
                print_colored(f"    {line_no}: {content}", Color.RED)
        else:
            print_info("  (No failure markers found in log; open the log file to see output.)")

        choice = _prompt_test_failure(is_crash=is_crash)
        if choice == "continue":
            print_info("Continuing despite test failure.")
            return True
        if choice in ("retry", "retry_fewer"):
            # "retry_fewer" halves the concurrency to work around compiler
            # crashes (user-visible option when is_crash is True). Plain
            # "retry" auto-reduces on crash, but keeps the current level
            # if the failure wasn't a crash.
            if choice == "retry_fewer":
                next_j = max(1, last_j // 2)
            elif is_crash:
                next_j = max(1, last_j // 2)
            else:
                next_j = last_j
            # Warn when concurrency can't be reduced further.
            if is_crash and next_j <= 1 and last_j <= 1:
                print_warning(
                    "Already at -j 1 — reducing concurrency further won't help. "
                    "This may be a Dart SDK bug unrelated to parallelism."
                )
            print_info(f"Re-running tests with -j {next_j}...")
            relog_time = datetime.now().strftime("%H%M%S")
            relog_name = f"{date_str}_{relog_time}_dart_test_{label}_retry.log"
            last_log = reports_dir / relog_name
            rc = _run_dart_test_to_file(
                project_dir, env, last_log, extra_args, concurrency=next_j,
            )
            last_j = next_j
            if rc == 0:
                print_success(f"{label.capitalize()} tests passed on retry (-j {next_j}).")
                return True
            continue
        # Abort: run chain-stack-traces so a detailed log exists, then return False
        print_warning("Aborting — capturing one final diagnostic trace (this is NOT a retry)...")
        _run_chain_stack_traces_and_check(project_dir, env, extra_args)
        print_info("Diagnostic trace saved. Aborting publish.")
        return False


def _available_ram_gb() -> float | None:
    """Return currently available (not total) RAM in GB, or None if undetectable.

    Windows-only via ctypes (stdlib, no new dependency). Used to keep the
    auto-tune cache from trusting a concurrency level that was only safe
    because the machine happened to be idle when it was probed — a value
    cached under light load can OOM-crash the compiler on a later run where
    other processes (IDE, browser, another publish) are competing for RAM.
    """
    if not is_windows():
        return None
    try:
        import ctypes

        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [
                ("dwLength", ctypes.c_ulong),
                ("dwMemoryLoad", ctypes.c_ulong),
                ("ullTotalPhys", ctypes.c_ulonglong),
                ("ullAvailPhys", ctypes.c_ulonglong),
                ("ullTotalPageFile", ctypes.c_ulonglong),
                ("ullAvailPageFile", ctypes.c_ulonglong),
                ("ullTotalVirtual", ctypes.c_ulonglong),
                ("ullAvailVirtual", ctypes.c_ulonglong),
                ("sullAvailExtendedVirtual", ctypes.c_ulonglong),
            ]

        stat = MEMORYSTATUSEX()
        stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
        if not ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat)):
            return None
        return stat.ullAvailPhys / (1024 ** 3)
    except (OSError, AttributeError, ValueError):
        return None


def _auto_tune_concurrency(
    project_dir: Path,
    env: dict[str, str] | None,
) -> int:
    """Probe for the highest stable dart-test concurrency on this machine.

    Runs a single lightweight test file at increasing -j levels (4, 6, 8, 10,
    12) and returns the highest level that completed without a native crash.
    Results are cached in build/.dart_test_max_j so the probe only runs once
    per machine/SDK combination.

    The cache key includes a coarse available-RAM bucket (rounded down to the
    nearest 4 GB) alongside SDK version and CPU count: a level probed safe
    while the machine had 20 GB free is not necessarily safe once other
    processes have claimed most of it, so a large drop in available RAM
    invalidates the cache and forces a fresh probe under current conditions.
    This does not fully solve "safe when idle, crashes under load" (RAM at
    cache-write time still isn't RAM at test-run time), but it prevents a
    stale cache from surviving across sessions with materially different
    memory pressure.

    Set SAROPA_TEST_MAX_J to skip the probe and use a fixed value (e.g.
    ``SAROPA_TEST_MAX_J=4`` for CI where the machine profile is known).

    Falls back to 4 if no probe succeeds (extremely conservative).
    """
    # Allow explicit override via env var — skips the probe entirely.
    override = os.environ.get("SAROPA_TEST_MAX_J", "").strip()
    if override:
        try:
            forced_j = max(1, int(override))
            print_info(f"Test concurrency: -j {forced_j} (SAROPA_TEST_MAX_J)")
            return forced_j
        except ValueError:
            print_warning(
                f"SAROPA_TEST_MAX_J={override!r} is not a valid integer — "
                "falling through to auto-tune"
            )
    # Cache key: SDK version + cpu count — a new SDK or different machine
    # invalidates the cached result.
    cache_dir = project_dir / "build"
    cache_dir.mkdir(parents=True, exist_ok=True)
    cache_file = cache_dir / ".dart_test_max_j"
    sdk_version = ""
    try:
        sdk_result = subprocess.run(
            ["dart", "--version"],
            capture_output=True, text=True, timeout=10,
            shell=get_shell_mode(),
        )
        sdk_version = sdk_result.stdout.strip() or sdk_result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired):
        pass
    ram_gb = _available_ram_gb()
    ram_bucket = int(ram_gb // 4) if ram_gb is not None else "unknown"
    cache_key = f"{sdk_version}|{os.cpu_count()}|ram{ram_bucket}"

    # Read cached result if it exists and matches.
    if cache_file.exists():
        try:
            lines = cache_file.read_text(encoding="utf-8").splitlines()
            if len(lines) >= 2 and lines[0] == cache_key:
                cached_j = int(lines[1])
                print_info(f"Test concurrency: -j {cached_j} (cached)")
                return cached_j
        except (ValueError, OSError):
            pass

    # Find a small test file for probing (avoid slow-tagged ones).
    probe_file = None
    test_dir = project_dir / "test"
    for candidate in sorted(test_dir.rglob("*_test.dart")):
        # Pick a small, fast test — skip integration/slow/scan/project_health.
        rel = str(candidate.relative_to(project_dir))
        if any(skip in rel for skip in ("scan", "project_health", "cross_file", "fixture")):
            continue
        # Use the first one found (sorted alphabetically = predictable).
        probe_file = rel
        break

    if not probe_file:
        print_warning("No probe test file found — defaulting to -j 4")
        return 4

    # Probe at increasing concurrency levels.
    levels = [4, 6, 8, 10, 12]
    cpu = os.cpu_count() or 8
    # Don't probe above the CPU count — no point.
    levels = [j for j in levels if j <= cpu]
    if not levels:
        levels = [4]
    # Under memory pressure, each frontend_server worker is more likely to
    # OOM the compiler regardless of CPU headroom — cap the ceiling rather
    # than probing all the way up and risking the crash the probe exists to
    # avoid. Thresholds are conservative estimates (~1.5 GB/worker), not
    # measured; the probe itself is still the authority on what's stable.
    if ram_gb is not None:
        if ram_gb < 4:
            levels = [j for j in levels if j <= 2] or [2]
        elif ram_gb < 8:
            levels = [j for j in levels if j <= 4] or [4]

    print_info(f"Tuning test concurrency (probing {probe_file})...")
    best_j = levels[0]
    use_shell = get_shell_mode()

    for j in levels:
        try:
            result = subprocess.run(
                ["dart", "test", "-j", str(j), probe_file],
                cwd=project_dir,
                capture_output=True,
                env=env,
                timeout=120,
                shell=use_shell,
            )
            # Exit code 9 = native crash (SIGKILL / STATUS_ACCESS_VIOLATION).
            # Also check for null bytes in output (sign of native crash).
            stdout_bytes = result.stdout or b""
            if result.returncode == 9 or b"\x00" in stdout_bytes[:4096]:
                print_info(f"  -j {j}: crash — stopping")
                break
            # Any non-zero exit that looks like a VM crash.
            output_text = stdout_bytes.decode("utf-8", errors="replace")
            if result.returncode != 0 and (
                "Corrupt heap" in output_text
                or "CRASH" in output_text
                or "ExceptionCode=" in output_text
            ):
                print_info(f"  -j {j}: VM crash detected — stopping")
                break
            # Test passed or failed normally (not a crash) — this level is safe.
            best_j = j
            print_info(f"  -j {j}: stable")
        except subprocess.TimeoutExpired:
            print_info(f"  -j {j}: timeout — stopping")
            break

    # Cache the result.
    try:
        cache_file.write_text(f"{cache_key}\n{best_j}\n", encoding="utf-8")
    except OSError:
        pass

    print_success(f"Test concurrency: -j {best_j}")
    return best_j


def _find_delta_test_files(project_dir: Path) -> list[str]:
    """Identify test files affected by uncommitted changes (staged + unstaged).

    Maps changed lib/ source files to their corresponding test/ files by
    mirroring the directory structure:
      lib/src/rules/core/context_rules.dart → test/rules/core/*_test.dart
      lib/src/scan/foo.dart                 → test/scan/*_test.dart
      lib/src/config/bar.dart               → test/config/*_test.dart

    Also includes any directly changed test files. Returns paths relative to
    project_dir, suitable for passing to `dart test <file> <file> ...`.

    Returns an empty list when git is unavailable, the diff is too broad
    (infrastructure files like tiers.dart or all_rules.dart changed), or no
    test files can be mapped — the caller should fall back to the full suite.
    """
    use_shell = get_shell_mode()
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=10,
            shell=use_shell,
        )
        # Also pick up staged-but-not-yet-in-HEAD changes.
        staged = subprocess.run(
            ["git", "diff", "--name-only", "--cached"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=10,
            shell=use_shell,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []

    changed = set()
    for line in (result.stdout + "\n" + staged.stdout).splitlines():
        line = line.strip().replace("\\", "/")
        if line:
            changed.add(line)

    if not changed:
        return []

    # Infrastructure files affect everything — bail to full suite.
    # Changes to tiers, registration, or the plugin entry point can break any test.
    # pubspec.yaml is NOT here: version bumps and metadata don't affect tests.
    _BROAD_IMPACT = (
        "lib/saropa_lints.dart",
        "lib/src/rules/all_rules.dart",
        "lib/src/tiers.dart",
    )
    for broad in _BROAD_IMPACT:
        if broad in changed:
            return []

    test_dir = project_dir / "test"
    delta_files: set[str] = set()

    for path in changed:
        # Directly changed test files — include as-is.
        if path.startswith("test/") and path.endswith("_test.dart"):
            full = project_dir / path.replace("/", os.sep)
            if full.exists():
                delta_files.add(path)
            continue

        # Map lib/src/<subpath>/foo.dart → test/<subpath>/*_test.dart
        # The test dir mirrors lib/src/ but drops the "src/" segment.
        if not path.startswith("lib/src/"):
            continue
        # Strip lib/src/ prefix to get the relative subpath.
        rel = path[len("lib/src/"):]
        # Get the directory portion (e.g. "rules/core" from "rules/core/context_rules.dart").
        parts = rel.replace("\\", "/").rsplit("/", 1)
        if len(parts) < 2:
            # Top-level lib/src/ file — look for test/<stem>*_test.dart.
            stem = Path(parts[0]).stem
            for t in test_dir.glob(f"{stem}*_test.dart"):
                delta_files.add(str(t.relative_to(project_dir)).replace("\\", "/"))
            continue
        subdir = parts[0]
        stem = Path(parts[1]).stem
        # Look for test files in the mirrored directory.
        test_subdir = test_dir / subdir.replace("/", os.sep)
        if not test_subdir.is_dir():
            continue
        # Collect all test files that share the stem prefix or live in the same dir.
        # e.g. context_rules.dart → context_rules_test.dart, context_rules_fp_test.dart
        for t in test_subdir.glob(f"{stem}*_test.dart"):
            delta_files.add(str(t.relative_to(project_dir)).replace("\\", "/"))

    return sorted(delta_files)


def run_tests(project_dir: Path) -> bool:
    """Step 7: Run tests — delta only when possible, full suite as fallback.

    Detects changed files via git diff and runs only their corresponding tests
    (seconds, not minutes). If delta passes, done — CI runs the full suite on
    push. If delta fails, stops immediately. Falls back to the full fast suite
    only when no delta can be computed (broad infrastructure changes or clean
    tree). Slow-tagged integration tests are always deferred to CI.

    Test output streams to both the terminal (live progress bar with pass/skip/fail
    counts) and a log file (full output). Failures print immediately on the terminal.
    On failure, shows log path and a short excerpt, then prompts Continue or Abort.
    Test temp is redirected outside the project tree so the scanner does not pick up
    kernel-cache .dill files. Full integration tests (dart analyze in example/) are
    skipped during publish; run manually: cd example && dart analyze
    """
    print_header("STEP 7: RUNNING TESTS")

    clear_flutter_lock()

    # Clear cached test kernels so tag changes (@Tags) take effect immediately.
    # Without this, dart test reuses stale .dill files that don't reflect new tags.
    test_cache = project_dir / ".dart_tool" / "test"
    if test_cache.is_dir():
        import shutil
        shutil.rmtree(test_cache, ignore_errors=True)
        print_info("Cleared stale test cache (.dart_tool/test)")

    test_dir = project_dir / "test"
    if not test_dir.exists():
        print_warning("No test directory found, skipping unit tests")
        return True

    env = _dart_test_env(project_dir)

    # Auto-tune: probe for the highest safe concurrency on this machine,
    # then pass it through to all test runs in this step.
    tuned_j = _auto_tune_concurrency(project_dir, env)

    now = datetime.now()
    date_str = now.strftime("%Y%m%d")
    time_str = now.strftime("%H%M%S")
    reports_dir = project_dir / "reports" / date_str
    reports_dir.mkdir(parents=True, exist_ok=True)

    # Delta pass: run only tests affected by uncommitted changes.
    # Compiles a handful of files instead of 340+, giving feedback in seconds.
    delta_files = _find_delta_test_files(project_dir)
    if delta_files:
        print_info(f"Delta: {len(delta_files)} test file(s) affected by changes")
        for f in delta_files:
            print_colored(f"    {f}", Color.CYAN)
        # Pass the specific test files — dart test compiles only these.
        # No tag filter: delta runs exactly these files, even if slow-tagged.
        delta_ok = _run_test_pass(
            project_dir, env, reports_dir, date_str, time_str,
            label="delta",
            extra_args=delta_files,
            concurrency=tuned_j,
        )
        if not delta_ok:
            return False
        # Delta passed — CI runs the full suite on push, no need to repeat it here.
        print_success("Delta tests passed. Full suite deferred to CI.")
        return True

    # No delta (broad infrastructure changes or clean tree) — run full suite.
    print_info("No delta (broad changes or clean tree) — running full suite")
    return _run_test_pass(
        project_dir, env, reports_dir, date_str, time_str,
        label="fast", extra_args=["-x", "slow"],
        concurrency=tuned_j,
    )


# Paths passed to ``dart format``. Must match CI (.github/workflows/ci.yml) and
# analysis_options.yaml exclude list: only format what we analyze. Example and
# example_* dirs use experimental syntax (inline-class, digit-separators, etc.)
# that the formatter cannot parse; formatting them would cause exit code 65.
_FORMAT_SCOPE = ("lib", "test")


def _collect_format_paths(project_dir: Path) -> list[str]:
    """Return paths to format: only lib and test (same as CI and analyzer scope).

    Never format example/ or example_*/ — they contain intentional violations
    and experimental language features the formatter cannot parse.
    """
    paths = [p for p in _FORMAT_SCOPE if (project_dir / p).exists()]
    if not paths:
        # Fallback only if both missing (wrong cwd); never use "." (would format examples).
        paths = ["lib"]
    return paths


def run_pub_get(project_dir: Path) -> bool:
    """Resolve dependencies in root + every nested workspace package.

    Why this exists as its own step: without it, a stale or missing
    `.dart_tool/package_config.json` in a nested package (e.g.
    `packages/saropa_lints_api/`) makes `dart analyze` report thousands
    of phantom `uri_does_not_exist` / undefined-function errors against
    `package:test/test.dart` and every symbol in its test files. The
    failure looks catastrophic ("9000+ errors, codebase broken") when
    the true cause is simply "deps haven't been resolved in the
    sub-package". Running pub get here, in every directory containing
    a pubspec.yaml under `packages/`, eliminates that whole class of
    triage. Sub-packages are discovered by glob so adding a new one
    under `packages/` requires no edits to this script.

    Failure mode: a non-zero exit from `dart pub get` in any package
    blocks the publish via PREREQUISITES_FAILED. We still attempt the
    remaining packages so the maintainer sees the full picture in one
    pass instead of fixing-and-retrying for each.
    """
    print_header("STEP 4 (cont.): RESOLVING DEPENDENCIES")

    # Root pubspec first; nested packages discovered by glob so future
    # sub-packages under packages/ are picked up automatically.
    pubspec_dirs: list[Path] = [project_dir]
    pubspec_dirs.extend(
        sorted(
            p.parent
            for p in (project_dir / "packages").glob("*/pubspec.yaml")
        )
    )

    use_shell = get_shell_mode()
    all_ok = True

    for pubspec_dir in pubspec_dirs:
        # Display path as "." for root, relative for sub-packages, so the
        # user can see at a glance which workspace failed.
        rel = (
            Path(".")
            if pubspec_dir == project_dir
            else pubspec_dir.relative_to(project_dir)
        )
        print_info(f"dart pub get  ({rel})")
        result = subprocess.run(
            ["dart", "pub", "get"],
            cwd=pubspec_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if result.returncode != 0:
            # Print both streams so the maintainer can act without
            # re-running the command manually to see the error.
            if result.stdout:
                print_colored(result.stdout.rstrip(), Color.WHITE)
            if result.stderr:
                print_colored(result.stderr.rstrip(), Color.RED)
            print_error(
                f"dart pub get failed in {rel} "
                f"(exit code {result.returncode})"
            )
            all_ok = False
            # Continue with remaining packages so the user sees every
            # failure at once instead of one-per-rerun.
            continue
        print_success(f"resolved  ({rel})")

    return all_ok


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

    format_paths = _collect_format_paths(project_dir)
    cmd = ["dart", "format"] + format_paths

    print_info("Formatting...")
    if get_output_level().value >= OutputLevel.VERBOSE.value:
        print_colored(f"      $ {' '.join(cmd)}", Color.WHITE)

    result = subprocess.run(
        cmd,
        cwd=project_dir,
        capture_output=True,
        text=True,
        shell=use_shell,
    )

    if result.returncode != 0:
        if result.stdout:
            print_colored(result.stdout.rstrip(), Color.WHITE)
        if result.stderr:
            print_colored(result.stderr.rstrip(), Color.RED)
        print_error(
            f"Formatting failed (exit code {result.returncode})"
        )
        if is_windows():
            subprocess.run(
                ["git", "config", "core.autocrlf", "true"],
                cwd=project_dir,
                capture_output=True,
                shell=use_shell,
            )
        return False

    # Show format summary (e.g. "Formatted 2384 files (31 changed)")
    if result.stdout:
        for line in result.stdout.strip().splitlines():
            if line.startswith("Formatted "):
                print_info(f"  {line}")
                break

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


def _strip_progress_lines(text: str) -> str:
    """Remove dart analyze progress bar lines (░█▓▒ blocks) from output."""
    _PROGRESS_CHARS = frozenset("░▒▓█")
    result = []
    for line in text.splitlines():
        stripped = line.strip()
        # Skip progress bar lines: start with block chars and contain │
        if stripped and stripped[0] in _PROGRESS_CHARS and "│" in stripped:
            continue
        # Skip blank/whitespace-only lines that precede/follow progress bars
        if not stripped and len(line) > 40:
            continue
        result.append(line)
    return "\n".join(result)


def _run_dart_analyze_core(project_dir: Path) -> bool:
    """Run dart analyze --fatal-infos, write log, print report. Returns True iff exit 0."""
    now = datetime.now()
    date_prefix = now.strftime("%Y%m%d")
    time_suffix = now.strftime("%H%M%S")
    reports_dir = project_dir / "reports" / date_prefix
    reports_dir.mkdir(parents=True, exist_ok=True)
    log_name = f"{date_prefix}_analysis_violations_{time_suffix}.log"
    log_path = reports_dir / log_name

    print_info(f"Running dart analyze (output → reports/{date_prefix}/{log_name})")
    use_shell = get_shell_mode()

    running = threading.Event()
    running.set()
    spinner = threading.Thread(
        target=_spinner_while,
        args=(running, "Analyzing"),
        daemon=True,
    )
    spinner.start()

    try:
        result = subprocess.run(
            ["dart", "analyze", "--fatal-infos"],
            cwd=project_dir,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            shell=use_shell,
        )
    finally:
        running.clear()
        spinner.join(timeout=0.5)

    raw_combined = (result.stdout or "") + (result.stderr or "")
    combined = _strip_progress_lines(raw_combined)
    log_path.write_text(combined, encoding="utf-8", errors="replace")

    counts = _parse_analysis_counts(combined)

    print()
    print_colored("  ─── Analysis report ───", Color.CYAN)
    if counts.total == 0:
        print_success("No issues found.")
    else:
        if counts.errors > 0:
            print_colored(
                f"  ● Errors:   {counts.errors}",
                Color.RED,
            )
        if counts.warnings > 0:
            print_colored(
                f"  ● Warnings: {counts.warnings}",
                Color.YELLOW,
            )
        if counts.infos > 0:
            print_colored(
                f"  ● Info:     {counts.infos}",
                Color.CYAN,
            )
        print_colored(
            f"  ● Total:    {counts.total}",
            Color.BOLD,
        )
        _print_analysis_diagnostics(combined)
    print_colored(f"  Full log: {log_path}", Color.DIM)
    print()

    if result.returncode != 0:
        # Mid-publish guard: when analysis_options.yaml's plugin pin matches
        # pubspec.yaml's version (the normal state of a release commit), the
        # plugin-resolution error is expected and transient — pub.dev will
        # report the version once `dart pub publish` lands. Treat analyze as
        # passed and skip the failure prompts entirely. This was the second
        # interactive step every release before this guard.
        if _is_mid_publish_stale_plugin(project_dir, combined):
            print_warning(
                "Stale plugin pin matches local pubspec.yaml — pub.dev "
                "will catch up after publish. Treating dart analyze as "
                "passed (no real lint failures, only the unpublished "
                "plugin version)."
            )
            return True

        # Real drift case (pin disagrees with both pubspec and pub.dev):
        # offer the downgrade prompt. If user accepts, retry analyze.
        if _try_fix_stale_plugin_cache(project_dir, combined):
            print_info("Retrying dart analyze after plugin-cache fix...")
            return _run_dart_analyze_core(project_dir)

        print_error(
            f"dart analyze failed (exit code {result.returncode}). "
            f"See report above."
        )
        print_colored(f"  Log: {log_path}", Color.DIM)
        return False

    print_success("dart analyze passed (no errors, warnings, or infos)")
    return True


def _prompt_analysis_failure() -> str:
    """Ask user what to do after analysis failed. Returns 'ignore' | 'retry' | 'abort'."""
    print_warning("dart analyze failed. Choose an action:")
    print_colored("  [I]gnore and continue (issues may be non-blocking)", Color.CYAN)
    print_colored("  [R]etry (re-run dart analyze)", Color.CYAN)
    print_colored("  [A]bort (stop publish)", Color.CYAN)
    try:
        raw = input("  Choice [i/r/a]: ").strip().lower() or "a"
        if raw.startswith("i"):
            return "ignore"
        if raw.startswith("r"):
            return "retry"
        if raw.startswith("a"):
            return "abort"
    except (EOFError, KeyboardInterrupt):
        return "abort"
    return "abort"


def _prompt_spelling_retry() -> bool:
    """Ask whether to re-scan after fixing British spellings.

    Returns True to Retry (the dev fixed the hits and wants a re-scan),
    False to Abort. There is deliberately NO "ignore and ship" option:
    British spellings always block the publish, because a bypassable gate
    is why they kept reaching pub.dev (see
    bugs/british_english_recurrence_attempts.md). Empty input defaults to
    Retry since fixes are usually quick; a non-interactive stream (EOF)
    returns False so an automated run blocks rather than looping forever.
    Ctrl+C propagates so it aborts the whole publish.
    """
    print_warning("British English spelling(s) found. Choose an action:")
    print_colored("  [R]etry (re-scan after fixing)", Color.CYAN)
    print_colored("  [A]bort publish", Color.CYAN)
    try:
        raw = input("  Choice [r/a]: ").strip().lower() or "r"
    except EOFError:
        return False
    return not raw.startswith("a")


def run_analysis_with_prompt(
    project_dir: Path,
    step_header: str | None,
    do_doc_check: bool,
) -> str:
    """Run dart analyze; on failure prompt Ignore/Retry/Abort. Returns 'ok' | 'ignore' | 'abort'."""
    if step_header:
        print_header(step_header)

    if do_doc_check:
        print_info("Checking for pub.dev doc issues...")
        pubdev_issues = check_pubdev_lint_issues(project_dir)
        if pubdev_issues:
            print_warning(f"Found {len(pubdev_issues)} pub.dev lint issue(s):")
            for issue in pubdev_issues:
                print_colored(f"      {issue}", Color.YELLOW)
            print_info("Auto-fixing doc comment issues...")
            fixed_brackets = fix_doc_angle_brackets(project_dir)
            fixed_refs = fix_doc_references(project_dir)
            total_fixed = fixed_brackets + fixed_refs
            if total_fixed:
                print_info(
                    f"Auto-fixed {total_fixed} issue(s) "
                    f"({fixed_brackets} angle bracket(s), "
                    f"{fixed_refs} doc reference(s))."
                )
            remaining = check_pubdev_lint_issues(project_dir)
            if remaining:
                print_warning(
                    f"{len(remaining)} unfixable pub.dev lint issue(s) remain:"
                )
                for issue in remaining:
                    print_colored(f"      {issue}", Color.YELLOW)
                # Let user decide: these may be non-blocking for dart analyze
                choice = _prompt_analysis_failure()
                if choice == "abort":
                    return "abort"
                if choice == "ignore":
                    # Skip dart analyze entirely — user accepted the doc issues
                    return "ignore"
                # choice == "retry": fall through to dart analyze loop below

    while True:
        if _run_dart_analyze_core(project_dir):
            return "ok"
        choice = _prompt_analysis_failure()
        if choice == "abort":
            return "abort"
        if choice == "ignore":
            return "ignore"
        if choice == "retry":
            print_info("Re-running dart analyze...")
            continue
    return "abort"


def run_analysis(project_dir: Path) -> bool:
    """Step 6: Run static analysis only (dart analyze + doc check). Returns True to continue.

    Tests run in Step 7; keeping analysis and tests separate ensures we report
    'Analysis failed' vs 'Tests failed' correctly (e.g. Windows file-lock in .dart_test_tmp).
    """
    result = run_analysis_with_prompt(
        project_dir,
        step_header="STEP 6: RUNNING STATIC ANALYSIS",
        do_doc_check=True,
    )
    return result in ("ok", "ignore")


def run_analyze_to_log(project_dir: Path) -> bool:
    """Standalone: run dart analyze and write results to a log file.

    Replaces the old scripts/analyze_to_log.ps1. Writes to
    reports/YYYYMMDD/<date>_analysis_violations_<time>.log with
    progress bar lines stripped.
    """
    print_header("DART ANALYZE TO LOG")
    return _run_dart_analyze_core(project_dir)


def _gate_changelog_overview(project_dir: Path, version: str) -> bool:
    """Loop-check the Overview intro + [log] link; prompt retry/ignore/abort.

    The expected resolution is editing CHANGELOG.md and re-checking, so the
    prompt defaults to retry (empty input or 'r' re-reads the file). 'ignore'
    proceeds with the known-bad section; 'abort' stops the publish.

    Returns:
        True to continue publishing, False to abort.
    """
    changelog_path = project_dir / "CHANGELOG.md"
    while True:
        problems = check_changelog_overview(changelog_path, version)
        if not problems:
            print_success(
                f"CHANGELOG [{version}] has an Overview intro and a "
                f"matching [log] link."
            )
            return True
        for problem in problems:
            print_warning(problem)
        choice = (
            input(
                "  Overview/log-link check failed. "
                "[R]etry / [i]gnore / [a]bort? [R] "
            )
            .strip()
            .lower()
        )
        if choice.startswith("i"):
            print_warning(
                f"Ignoring CHANGELOG Overview problems for [{version}]."
            )
            return True
        if choice.startswith("a"):
            print_error("Publish aborted at CHANGELOG Overview check.")
            return False
        # Empty input or anything starting with 'r' retries: re-read the file
        # so a fix the author just saved is picked up on the next pass.
        print_info("Re-checking CHANGELOG.md...")


def validate_changelog(
    project_dir: Path, version: str
) -> tuple[bool, str]:
    """Step 9: Validate version in CHANGELOG and get release notes."""
    print_header("STEP 9: VALIDATING CHANGELOG")

    release_notes = validate_changelog_version(project_dir, version)
    if release_notes is None:
        print_error(f"Version {version} not found in CHANGELOG.md")
        return False, ""

    print_success(f"Found version {version} in CHANGELOG.md")

    # Gate on the Overview intro + version-pinned [log] link before the
    # release notes are accepted. Default-to-retry so the author can fix
    # CHANGELOG.md in place and re-check without losing the publish run.
    if not _gate_changelog_overview(project_dir, version):
        return False, ""

    if not release_notes:
        response = (
            input(f"  Use generic message 'Release {version}'? [Y/n] ")
            .strip()
            .lower()
        )
        if response.startswith("n"):
            return False, ""
        release_notes = f"Release {version}"
    else:
        print_colored("  Release notes preview:", Color.CYAN)
        for line in release_notes.split("\n")[:10]:
            print_colored(f"    {line}", Color.WHITE)
        if release_notes.count("\n") > 10:
            print_colored("    ...", Color.WHITE)

    return True, release_notes


def _extract_dart_doc_summary(output: str) -> tuple[str, int, int]:
    """Return (summary_line, warning_count, error_count) from dart doc output."""
    for line in output.splitlines():
        stripped = line.strip()
        m = re.search(
            r"Found\s+(\d+)\s+warnings?\s+and\s+(\d+)\s+errors?",
            stripped,
            re.IGNORECASE,
        )
        if m:
            return stripped, int(m.group(1)), int(m.group(2))
    return "", 0, 0


def _print_dart_doc_summary(summary_line: str, warning_count: int) -> None:
    """Print a one-line summary for dart doc output."""
    if not summary_line:
        print_info("dart doc finished (see log for details).")
        return
    if warning_count > 0:
        print_warning(summary_line)
    else:
        print_info(summary_line)


def _print_dart_doc_failure_tail(output: str) -> None:
    """Print a short tail excerpt for a failed dart doc run."""
    tail_lines = [line for line in output.splitlines() if line.strip()][-10:]
    if not tail_lines:
        return
    print_colored("  Last output lines:", Color.RED)
    for line in tail_lines:
        print_colored(f"    {line}", Color.RED)


def generate_docs(project_dir: Path) -> bool:
    """Step 10: Generate documentation."""
    print_header("STEP 10: GENERATING DOCUMENTATION")
    now = datetime.now()
    date_prefix = now.strftime("%Y%m%d")
    time_suffix = now.strftime("%H%M%S")
    reports_dir = project_dir / "reports" / date_prefix
    reports_dir.mkdir(parents=True, exist_ok=True)
    log_name = f"{date_prefix}_dart_doc_{time_suffix}.log"
    log_path = reports_dir / log_name

    print_info(f"Generating docs (output → reports/{date_prefix}/{log_name})")
    use_shell = get_shell_mode()
    result = subprocess.run(
        ["dart", "doc"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=use_shell,
    )

    combined = (result.stdout or "") + (result.stderr or "")
    log_path.write_text(combined, encoding="utf-8", errors="replace")

    summary_line, warning_count, error_count = _extract_dart_doc_summary(
        combined
    )
    _print_dart_doc_summary(summary_line, warning_count)
    print_colored(f"  Log: {log_path}", Color.DIM)

    if result.returncode != 0:
        print_error(f"Generating docs failed (exit code {result.returncode})")
        _print_dart_doc_failure_tail(combined)
        return False

    print_success("Generating docs completed")
    if warning_count > 0 and error_count == 0:
        print_warning(
            "dart doc reported warnings. Open the log file above for full details."
        )
    return True


def pre_publish_validation(project_dir: Path) -> bool:
    """Step 11: Run dart pub publish --dry-run."""
    print_header("STEP 11: PRE-PUBLISH VALIDATION")

    print_info("Running 'dart pub publish --dry-run'...")
    use_shell = get_shell_mode()
    # Force UTF-8 with replacement: dart pub publish emits non-ASCII bytes
    # (e.g. 0x8f) that crash the subprocess reader thread on Windows where
    # text=True defaults to cp1252. The return code survived the crash, but
    # stdout/stderr were lost — hiding real validation errors on failure.
    result = subprocess.run(
        ["dart", "pub", "publish", "--dry-run"],
        cwd=project_dir,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
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
