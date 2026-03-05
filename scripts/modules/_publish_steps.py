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

    # --- Full audit (includes tier integrity + quality checks) ---
    audit_result = run_full_audit(
        project_dir=project_dir,
        skip_dx=False,
        compact=True,
        extra_checks=spelling_check,
    )

    # --- Run dart analyze as part of audit (fail fast; same as Step 6) ---
    if not audit_result.has_blocking_issues and not spelling_hits:
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
    if audit_result.has_blocking_issues or spelling_hits:
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
        if spelling_hits:
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
    """Return env with TMP/TEMP set to project-local .dart_test_tmp so test kernel files don't fill system temp."""
    test_tmp = project_dir / ".dart_test_tmp"
    test_tmp.mkdir(exist_ok=True)
    env = os.environ.copy()
    env["TMP"] = str(test_tmp)
    env["TEMP"] = str(test_tmp)
    return env


def _run_chain_stack_traces_and_check(
    project_dir: Path, env: dict[str, str] | None
) -> bool:
    """Run dart test --chain-stack-traces, pipe to file, open and check for errors. Returns True iff tests passed."""
    now = datetime.now()
    date_str = now.strftime("%Y%m%d")
    time_str = now.strftime("%H%M%S")
    reports_dir = project_dir / "reports" / date_str
    reports_dir.mkdir(parents=True, exist_ok=True)
    log_name = f"{date_str}_{time_str}_chain_stack_traces.log"
    log_path = reports_dir / log_name
    print_info(f"Running dart test --chain-stack-traces (output → reports/{date_str}/{log_name})")
    use_shell = get_shell_mode()
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
    _check_log_for_errors(log_path, date_str, log_name)
    return result.returncode == 0 if result is not None else False


def _check_log_for_errors(log_path: Path, date_str: str, log_name: str) -> None:
    """Open the chain-stack-traces log and print lines that indicate failures (cap 50 lines)."""
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

    Uses a temp dir under the project so the test runner does not fill
    the system temp drive (e.g. C:) when the project is on another drive.
    Note: full integration tests (dart analyze in example/) are skipped
    during publish because 1700+ rules x 1500+ fixture files takes too long.
    Run manually when needed:
        cd example && dart analyze
    """
    print_header("STEP 7: RUNNING TESTS")

    clear_flutter_lock()

    test_dir = project_dir / "test"
    if test_dir.exists():
        # Use project-local temp so dart test kernel files don't fill system
        # temp (e.g. C:\Users\...\AppData\Local\Temp) when project is on D:
        test_tmp = project_dir / ".dart_test_tmp"
        test_tmp.mkdir(exist_ok=True)
        env = os.environ.copy()
        env["TMP"] = str(test_tmp)
        env["TEMP"] = str(test_tmp)
        result = run_command(
            ["dart", "test"],
            project_dir,
            "Running unit tests",
            summarize=True,
            env=env,
        )
        if result.returncode != 0:
            _run_chain_stack_traces_and_check(project_dir, env)
            return False
    else:
        print_warning("No test directory found, skipping unit tests")

    return True


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


def _run_dart_analyze_core(project_dir: Path) -> bool:
    """Run dart analyze --fatal-infos, write log, print report. Returns True iff exit 0."""
    reports_dir = project_dir / "reports"
    reports_dir.mkdir(exist_ok=True)
    now = datetime.now()
    date_prefix = now.strftime("%Y%m%d")
    time_suffix = now.strftime("%H%M%S")
    log_name = f"{date_prefix}_analysis_violations_{time_suffix}.log"
    log_path = reports_dir / log_name

    print_info(f"Running dart analyze (output → reports/{log_name})")
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

    combined = (result.stdout or "") + (result.stderr or "")
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
                print_error(
                    f"{len(remaining)} unfixable pub.dev lint issue(s) remain:"
                )
                for issue in remaining:
                    print_colored(f"      {issue}", Color.YELLOW)
                return "abort"

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
    """Step 6: Run static analysis and tests with chain-stack-traces; log and prompt on failure. Returns True to continue."""
    result = run_analysis_with_prompt(
        project_dir,
        step_header="STEP 6: RUNNING STATIC ANALYSIS",
        do_doc_check=True,
    )
    if result not in ("ok", "ignore"):
        return False
    # Run tests with full traces during analysis so we surface test failures early (no need to wait for Step 7).
    test_dir = project_dir / "test"
    if test_dir.exists():
        env = _dart_test_env(project_dir)
        if not _run_chain_stack_traces_and_check(project_dir, env):
            print_error("dart test --chain-stack-traces failed. See report above.")
            return False
    return True


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
    """Step 10: Generate documentation."""
    print_header("STEP 10: GENERATING DOCUMENTATION")
    result = run_command(["dart", "doc"], project_dir, "Generating docs")
    return result.returncode == 0


def pre_publish_validation(project_dir: Path) -> bool:
    """Step 11: Run dart pub publish --dry-run."""
    print_header("STEP 11: PRE-PUBLISH VALIDATION")

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
