"""
Run independent publish checks side by side.

A *lane* is a chain of commands that must stay in order; different lanes run at
the same time. Each lane writes to its own log file so output is never
interleaved, a heartbeat names the lanes still running, and after a failure the
developer can retry just the failed lanes (from the failed command) or abort.

One poll loop drives every process, so there are no threads and the accept /
on_failure hooks always run on the main thread (they may print or prompt).

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import subprocess
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from scripts.modules._timing import format_duration
from scripts.modules._utils import (
    HEARTBEAT_S,
    Color,
    _default_timeout,
    get_shell_mode,
    hardened_env,
    is_windows,
    kill_process_tree,
    print_colored,
    print_error,
    print_info,
    print_success,
    print_warning,
    prompt_step_failure,
)

# How often finished processes are noticed.
_POLL_S = 0.2
# Lines of a failed command's output shown on screen; the log keeps everything.
_FAILURE_TAIL_LINES = 40


@dataclass
class Cmd:
    """One command in a lane.

    accept(returncode, output) overrides the plain "exit 0 is success" rule.
    allow_failure lets the lane carry on after a non-zero exit.
    """

    argv: list[str]
    cwd: Path
    env: dict[str, str] | None = None
    accept: Callable[[int, str], bool] | None = None
    allow_failure: bool = False
    timeout: float | None = None


@dataclass
class Lane:
    """Ordered commands. next_index survives a retry, so passed ones are kept.

    on_failure(output) may repair the cause and return True to re-run the
    failed command once without asking.
    """

    name: str
    cmds: list[Cmd]
    on_failure: Callable[[str], bool] | None = None
    next_index: int = 0
    auto_retried: bool = False
    seconds: float = 0.0
    output: str = ""
    log_path: Path | None = None


@dataclass
class _Running:
    """The live process of one lane."""

    lane: Lane
    proc: subprocess.Popen
    log_path: Path
    handle: object = field(repr=False)
    started: float = 0.0


def _start(lane: Lane, log_dir: Path) -> _Running:
    """Launch the lane's next command with output going to its own log."""
    cmd = lane.cmds[lane.next_index]
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    log_path = log_dir / f"{stamp}_parallel_{lane.name}.log"
    handle = open(log_path, "wb")
    print_info(f"[{lane.name}] {' '.join(cmd.argv[:4])} ...")
    # A file, not a pipe: a pipe that nobody drains blocks a chatty process.
    proc = subprocess.Popen(
        cmd.argv,
        cwd=cmd.cwd,
        stdout=handle,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        env=hardened_env(cmd.env),
        shell=get_shell_mode(),
        start_new_session=not is_windows(),
    )
    return _Running(lane, proc, log_path, handle, time.monotonic())


def _finish(run: _Running, returncode: int) -> bool:
    """Record a finished command. Returns True if the lane may continue."""
    run.handle.close()
    lane = run.lane
    cmd = lane.cmds[lane.next_index]
    lane.seconds += time.monotonic() - run.started
    lane.log_path = run.log_path
    lane.output = run.log_path.read_text(encoding="utf-8", errors="replace")
    ok = cmd.accept(returncode, lane.output) if cmd.accept else returncode == 0
    if not ok and cmd.allow_failure:
        print_warning(f"[{lane.name}] non-fatal failure, see {run.log_path}")
        ok = True
    if ok:
        lane.next_index += 1
    else:
        print_error(f"[{lane.name}] failed (exit code {returncode})")
    return ok


def _timed_out(run: _Running) -> bool:
    """Kill a command that has exceeded its ceiling."""
    cmd = run.lane.cmds[run.lane.next_index]
    limit = cmd.timeout or _default_timeout(cmd.argv)
    if time.monotonic() - run.started < limit:
        return False
    print_error(f"[{run.lane.name}] TIMEOUT after {limit:.0f}s")
    kill_process_tree(run.proc)
    return True


def run_lanes(
    lanes: list[Lane], log_dir: Path, max_parallel: int | None = None,
) -> list[Lane]:
    """Run every lane to completion or first failure. Returns failed lanes.

    A failing lane does not stop the others: one pass reports every problem.
    max_parallel=1 runs the lanes one after another (low-memory machines).
    """
    log_dir.mkdir(parents=True, exist_ok=True)
    limit = max_parallel or len(lanes)
    waiting = [lane for lane in lanes if lane.next_index < len(lane.cmds)]
    running: list[_Running] = []
    failed: list[Lane] = []
    began = beat = time.monotonic()
    try:
        while waiting or running:
            while waiting and len(running) < limit:
                running.append(_start(waiting.pop(0), log_dir))
            time.sleep(_POLL_S)
            for run in list(running):
                code = run.proc.poll()
                if code is None:
                    if not _timed_out(run):
                        continue
                    code = run.proc.wait()
                running.remove(run)
                lane = run.lane
                if not _finish(run, code):
                    failed.append(lane)
                elif lane.next_index < len(lane.cmds):
                    running.append(_start(lane, log_dir))
                else:
                    print_success(
                        f"[{lane.name}] passed ({format_duration(lane.seconds)})"
                    )
            if running and time.monotonic() - beat >= HEARTBEAT_S:
                beat = time.monotonic()
                names = ", ".join(run.lane.name for run in running)
                print_info(f"still running: {names} ({beat - began:.0f}s)")
    finally:
        # Ctrl+C or a crash must not leave dart / node processes behind.
        for run in running:
            kill_process_tree(run.proc)
            run.handle.close()
    return failed


def _show_failure(lane: Lane) -> None:
    """Print the tail of one failed lane's output, kept together."""
    print_colored(f"\n  ─── {lane.name}: last output ───", Color.RED)
    for line in lane.output.strip().splitlines()[-_FAILURE_TAIL_LINES:]:
        print_colored(f"    {line}", Color.WHITE)
    print_colored(f"  Full log: {lane.log_path}", Color.DIM)


def run_group(
    title: str,
    lanes: list[Lane],
    log_dir: Path,
    max_parallel: int | None = None,
) -> bool:
    """Run lanes until all pass (True) or the developer aborts (False)."""
    pending = lanes
    began = time.monotonic()
    while True:
        print_info(f"{title}: {', '.join(lane.name for lane in pending)}")
        failed = run_lanes(pending, log_dir, max_parallel)
        if not failed:
            wall = format_duration(time.monotonic() - began)
            total = format_duration(sum(lane.seconds for lane in lanes))
            print_success(f"{title} passed: wall {wall}, step time {total}")
            return True
        # Self-repairable failures re-run once before the developer is asked.
        repaired = [
            lane for lane in failed
            if lane.on_failure and not lane.auto_retried
            and lane.on_failure(lane.output)
        ]
        for lane in repaired:
            lane.auto_retried = True
        if len(repaired) < len(failed):
            for lane in failed:
                _show_failure(lane)
            names = ", ".join(lane.name for lane in failed)
            choice = prompt_step_failure(
                f"{title} ({names})", allow_ignore=False,
            )
            if choice != "retry":
                return False
        pending = failed
