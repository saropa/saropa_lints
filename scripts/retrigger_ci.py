"""
Re-trigger failed GitHub Actions workflows.

Lists recent failed workflow runs and re-runs them. Optionally
watches until all re-triggered runs complete.

Usage:
    python scripts/retrigger_ci.py              # prompt before re-running
    python scripts/retrigger_ci.py --all        # re-run all without prompt
    python scripts/retrigger_ci.py --watch      # re-run and wait for results
    python scripts/retrigger_ci.py --limit 20   # check last 20 runs

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import json
import subprocess
import sys
import time

from scripts.modules._utils import (
    Color,
    ExitCode,
    command_exists,
    enable_ansi_support,
    exit_with_error,
    get_project_dir,
    get_shell_mode,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_success,
    print_warning,
)


def _parse_args() -> tuple[bool, bool, int]:
    """Parse CLI arguments.

    Returns:
        (auto_rerun, watch, limit) tuple.
    """
    auto_rerun = "--all" in sys.argv
    watch = "--watch" in sys.argv
    limit = 10
    for i, arg in enumerate(sys.argv):
        if arg == "--limit" and i + 1 < len(sys.argv):
            try:
                limit = int(sys.argv[i + 1])
            except ValueError:
                exit_with_error(
                    f"Invalid --limit value: {sys.argv[i + 1]}",
                    ExitCode.PREREQUISITES_FAILED,
                )
    return auto_rerun, watch, limit


def _check_gh_cli() -> None:
    """Verify gh CLI is installed and authenticated."""
    if not command_exists("gh"):
        exit_with_error(
            "GitHub CLI (gh) not found. Install: https://cli.github.com",
            ExitCode.PREREQUISITES_FAILED,
        )
    result = subprocess.run(
        ["gh", "auth", "status"],
        capture_output=True,
        text=True,
        shell=get_shell_mode(),
    )
    if result.returncode != 0:
        exit_with_error(
            "GitHub CLI not authenticated. Run: gh auth login",
            ExitCode.PREREQUISITES_FAILED,
        )


def _get_failed_runs(limit: int) -> list[dict]:
    """Fetch recent failed workflow runs."""
    result = subprocess.run(
        [
            "gh", "run", "list",
            "--limit", str(limit),
            "--json", "databaseId,name,status,conclusion,event,headBranch,createdAt,workflowName",
        ],
        cwd=get_project_dir(),
        capture_output=True,
        text=True,
        shell=get_shell_mode(),
    )
    if result.returncode != 0:
        exit_with_error(
            f"Failed to list runs: {result.stderr.strip()}",
            ExitCode.PREREQUISITES_FAILED,
        )
    runs = json.loads(result.stdout)
    return [r for r in runs if r.get("conclusion") == "failure"]


def _display_failed_runs(runs: list[dict]) -> None:
    """Print a table of failed runs."""
    print_colored(
        f"  {'ID':<15} {'Workflow':<35} {'Branch':<15} {'Event':<10}",
        Color.WHITE,
    )
    print_colored(f"  {'─' * 75}", Color.DIM)
    for run in runs:
        run_id = str(run["databaseId"])
        workflow = run.get("workflowName") or run.get("name", "?")
        branch = run.get("headBranch", "?")
        event = run.get("event", "?")
        print_colored(
            f"  {run_id:<15} {workflow:<35} {branch:<15} {event:<10}",
            Color.YELLOW,
        )


def _rerun(runs: list[dict]) -> list[int]:
    """Re-run each failed workflow. Returns list of re-triggered run IDs."""
    project_dir = get_project_dir()
    use_shell = get_shell_mode()
    triggered: list[int] = []

    for run in runs:
        run_id = run["databaseId"]
        name = run.get("workflowName") or run.get("name", "?")
        result = subprocess.run(
            ["gh", "run", "rerun", str(run_id)],
            cwd=project_dir,
            capture_output=True,
            text=True,
            shell=use_shell,
        )
        if result.returncode == 0:
            print_success(f"Re-triggered: {name} (#{run_id})")
            triggered.append(run_id)
        else:
            print_error(
                f"Failed to re-run {name} (#{run_id}): "
                f"{result.stderr.strip()}"
            )
    return triggered


def _watch_runs(run_ids: list[int]) -> bool:
    """Poll until all runs complete. Returns True if all succeeded."""
    project_dir = get_project_dir()
    use_shell = get_shell_mode()
    pending = set(run_ids)
    failed: list[int] = []

    print_info("Watching runs for completion...")
    while pending:
        time.sleep(5)
        for run_id in list(pending):
            result = subprocess.run(
                [
                    "gh", "run", "view", str(run_id),
                    "--json", "status,conclusion,workflowName",
                ],
                cwd=project_dir,
                capture_output=True,
                text=True,
                shell=use_shell,
            )
            if result.returncode != 0:
                continue
            data = json.loads(result.stdout)
            if data.get("status") != "completed":
                continue
            name = data.get("workflowName", run_id)
            pending.discard(run_id)
            if data.get("conclusion") == "success":
                print_success(f"{name} (#{run_id}) passed")
            else:
                conclusion = data.get("conclusion", "unknown")
                print_error(f"{name} (#{run_id}) {conclusion}")
                failed.append(run_id)
        if pending:
            print_colored(
                f"  ... {len(pending)} run(s) still in progress",
                Color.DIM,
            )
    return len(failed) == 0


def main() -> None:
    """Entry point."""
    enable_ansi_support()
    auto_rerun, watch, limit = _parse_args()
    print_header("RETRIGGER FAILED CI RUNS")

    _check_gh_cli()

    print_info(f"Checking last {limit} workflow runs...")
    failed_runs = _get_failed_runs(limit)

    if not failed_runs:
        print_success("No failed runs found.")
        sys.exit(ExitCode.SUCCESS.value)

    print_warning(f"Found {len(failed_runs)} failed run(s):")
    print()
    _display_failed_runs(failed_runs)
    print()

    if not auto_rerun:
        answer = input("  Re-run all failed workflows? [y/N] ").strip().lower()
        if answer != "y":
            print_info("Cancelled.")
            sys.exit(ExitCode.USER_CANCELLED.value)

    triggered = _rerun(failed_runs)
    if not triggered:
        exit_with_error("No runs were re-triggered.", ExitCode.PREREQUISITES_FAILED)

    print()
    print_success(f"Re-triggered {len(triggered)} run(s).")

    if watch:
        print()
        all_passed = _watch_runs(triggered)
        if all_passed:
            print()
            print_success("All runs passed.")
            sys.exit(ExitCode.SUCCESS.value)
        else:
            print()
            exit_with_error("Some runs failed again.", ExitCode.PREREQUISITES_FAILED)


if __name__ == "__main__":
    main()
