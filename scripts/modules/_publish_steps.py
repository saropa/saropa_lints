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


def _try_fix_stale_plugin_cache(
    project_dir: Path,
    combined: str,
) -> bool:
    """Detect and offer to fix a stale analyzer-plugin cache.

    If the dart-analyze output contains a plugin version-resolution
    error, query pub.dev for the latest version, update
    ``analysis_options.yaml``, and clear the plugin-manager cache.

    Returns True if a fix was applied (caller should retry analyze).
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
    # Prompt the user on hits: Retry (rescan after fix) or Ignore
    # (continue publish). This replaces the prior auto-abort so fixes
    # can be applied without restarting the whole audit.
    spelling_ignored = False
    while spelling_hits:
        print_spelling_report(spelling_hits, project_dir)
        choice = _prompt_spelling_failure()
        if choice == "retry":
            print_info("Re-scanning for British spellings...")
            spelling_hits = scan_directory(project_dir)
            continue
        # choice == "ignore": user accepts the hits; continue publish
        print_warning(
            f"Continuing publish with {len(spelling_hits)} "
            f"British spelling(s) (user chose Ignore)."
        )
        spelling_ignored = True
        break

    # Only block the publish if hits remain AND user did not ignore
    spelling_blocks = bool(spelling_hits) and not spelling_ignored

    spelling_check: list[tuple[str, str, list[str]]] = []
    if spelling_hits:
        # "warn" when ignored (visible but non-blocking), "fail" otherwise
        status = "warn" if spelling_ignored else "fail"
        label = f"{len(spelling_hits)} British English spelling(s) found"
        if spelling_ignored:
            label += " — ignored by user"
        spelling_check.append((
            status,
            label,
            [f"{h.file}:{h.line_number} — {h.uk_word} → {h.us_word}"
             for h in spelling_hits[:10]],
        ))
    else:
        spelling_check.append((
            "pass", "No British English spellings found", [],
        ))

    # --- Full audit (includes tier integrity + quality checks) ---
    audit_result = run_full_audit(
        project_dir=project_dir,
        skip_dx=False,
        compact=True,
        extra_checks=spelling_check,
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
    """Return env with TMP/TEMP set to project-local build/test_tmp so test kernel files don't fill system temp.

    Uses build/test_tmp (not .dart_test_tmp) to avoid Windows PathAccessException when tests that create
    temp dirs via Directory.systemTemp run: the dart test runner also uses .dart_test_tmp and can hold
    handles during cleanup, causing "file is being used by another process" on teardown.
    """
    test_tmp = project_dir / "build" / "test_tmp"
    test_tmp.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["TMP"] = str(test_tmp)
    env["TEMP"] = str(test_tmp)
    return env


def _log_shows_windows_file_lock(log_path: Path) -> bool:
    """True if the log indicates a transient Windows file-lock (PathAccessException / errno 32)."""
    if not log_path.exists():
        return False
    try:
        text = log_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return False
    return (
        "PathAccessException" in text
        or "being used by another process" in text
        or "errno = 32" in text
    )


def _run_chain_stack_traces_and_check(
    project_dir: Path, env: dict[str, str] | None
) -> bool:
    """Run dart test --chain-stack-traces, pipe output to a log file, then check for error lines.

    Used in Step 7 when plain 'dart test' fails. Writes to reports/YYYYMMDD/YYYYMMDD_HHMMSS_chain_stack_traces.log.
    Shows a spinner while the subprocess runs. Calls _check_log_for_errors to print failure lines (cap 50).
    On Windows, retries once if the log shows a transient PathAccessException (file in use in .dart_test_tmp).

    Returns:
        True iff the test process exited with code 0. False if non-zero exit or if subprocess/open raised.
    """
    use_shell = get_shell_mode()
    max_attempts = 2
    last_result = None
    last_log_path = None
    last_date_str = None
    last_log_name = None

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
                f"Retrying dart test --chain-stack-traces (output → reports/{date_str}/{log_name})"
            )
        else:
            print_info(
                f"Running dart test --chain-stack-traces (output → reports/{date_str}/{log_name})"
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
                    ["dart", "test", "--chain-stack-traces"],
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
        # Retry once on Windows when log shows transient file lock in .dart_test_tmp
        if attempt == 0 and _log_shows_windows_file_lock(log_path):
            print_warning(
                "Transient Windows file lock detected (.dart_test_tmp). Retrying tests once..."
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


def _run_dart_test_to_file(
    project_dir: Path,
    env: dict[str, str] | None,
    log_path: Path,
) -> int:
    """Run dart test with stdout/stderr piped only to log_path. Returns exit code.

    On non-zero exit, appends a line to the log so the file explicitly records that tests failed.
    """
    use_shell = get_shell_mode()
    with open(log_path, "w", encoding="utf-8", errors="replace") as out:
        result = subprocess.run(
            ["dart", "test"],
            cwd=project_dir,
            stdout=out,
            stderr=subprocess.STDOUT,
            env=env,
            shell=use_shell,
        )
    if result.returncode != 0:
        with open(log_path, "a", encoding="utf-8") as ap:
            ap.write(f"\n[Tests failed — exit code {result.returncode}.]\n")
    return result.returncode


def _prompt_test_failure() -> str:
    """Ask user what to do after tests failed. Returns 'continue' | 'retry' | 'abort'."""
    print_warning("Tests failed. Choose an action:")
    print_colored("  [R]etry (re-run tests after fixing the issue)", Color.CYAN)
    print_colored("  [C]ontinue anyway (proceed with publish)", Color.CYAN)
    print_colored("  [A]bort (stop publish)", Color.CYAN)
    try:
        raw = input("  Choice [r/c/a]: ").strip().lower() or "a"
        if raw.startswith("r"):
            return "retry"
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


def run_tests(project_dir: Path) -> bool:
    """Step 7: Run unit tests.

    All test output is written to a log file only (no test output on terminal).
    On failure, shows log path and a short excerpt, then prompts Continue or Abort.
    Uses a temp dir under the project so the test runner does not fill
    the system temp drive. Full integration tests (dart analyze in example/)
    are skipped during publish; run manually: cd example && dart analyze
    """
    print_header("STEP 7: RUNNING TESTS")

    clear_flutter_lock()

    test_dir = project_dir / "test"
    if not test_dir.exists():
        print_warning("No test directory found, skipping unit tests")
        return True

    env = _dart_test_env(project_dir)
    now = datetime.now()
    date_str = now.strftime("%Y%m%d")
    time_str = now.strftime("%H%M%S")
    reports_dir = project_dir / "reports" / date_str
    reports_dir.mkdir(parents=True, exist_ok=True)
    log_name = f"{date_str}_{time_str}_dart_test.log"
    log_path = reports_dir / log_name

    print_info(f"Running unit tests (output → reports/{date_str}/{log_name})")
    returncode = _run_dart_test_to_file(project_dir, env, log_path)
    if returncode == 0:
        print_success("Tests passed.")
        return True

    print_warning("Retrying tests once...")
    retry_name = f"{date_str}_{time_str}_dart_test_retry.log"
    retry_path = reports_dir / retry_name
    retry_code = _run_dart_test_to_file(project_dir, env, retry_path)
    if retry_code == 0:
        print_success("Tests passed on retry.")
        return True

    # Both runs failed: show log path and short excerpt, then prompt
    last_log = retry_path
    while True:
        print_error("Tests failed. Full output in log file (no test output was printed to this terminal).")
        print_colored(f"  Log: {last_log.relative_to(project_dir)}", Color.CYAN)
        excerpt = _extract_failure_excerpt(last_log, max_lines=10)
        if excerpt:
            print_colored("  Excerpt:", Color.RED)
            for line_no, content in excerpt:
                print_colored(f"    {line_no}: {content}", Color.RED)
        else:
            print_info("  (No failure markers found in log; open the log file to see output.)")

        choice = _prompt_test_failure()
        if choice == "continue":
            print_info("Continuing despite test failure.")
            return True
        if choice == "retry":
            # Re-run tests (user may have fixed the issue in another terminal)
            print_info("Re-running tests...")
            relog_time = datetime.now().strftime("%H%M%S")
            relog_name = f"{date_str}_{relog_time}_dart_test_retry.log"
            last_log = reports_dir / relog_name
            rc = _run_dart_test_to_file(project_dir, env, last_log)
            if rc == 0:
                print_success("Tests passed on retry.")
                return True
            continue
        # Abort: run chain-stack-traces so a detailed log exists, then return False
        print_info("Writing detailed trace to log (output → reports/.../chain_stack_traces.log)")
        _run_chain_stack_traces_and_check(project_dir, env)
        return False


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
        # Check for stale plugin-cache error before reporting failure.
        # If user accepts the fix, retry analyze automatically.
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


def _prompt_spelling_failure() -> str:
    """Ask user what to do after British spellings were found.

    Returns 'retry' | 'ignore'. No auto-abort: the user must choose
    whether to fix-and-rescan (Retry) or proceed with the hits in
    place (Ignore). Ctrl+C still aborts via KeyboardInterrupt.
    Default (empty input) is Retry — the safer choice since
    fixes are usually easy.
    """
    print_warning("British English spelling(s) found. Choose an action:")
    print_colored("  [R]etry (re-scan after fixing)", Color.CYAN)
    print_colored("  [I]gnore and continue (publish with hits)", Color.CYAN)
    try:
        raw = input("  Choice [r/i]: ").strip().lower() or "r"
        if raw.startswith("i"):
            return "ignore"
        # default and any 'r*' → retry
        return "retry"
    except (EOFError, KeyboardInterrupt):
        # Propagate interrupt by returning 'ignore' would be wrong;
        # re-raise so the outer publish workflow can handle abort.
        raise


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
