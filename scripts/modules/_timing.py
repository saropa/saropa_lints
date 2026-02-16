"""
Step timing tracker for publish workflow.

Records duration and pass/fail status for each workflow step,
then renders a timing summary table with proportional bar charts.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import time
from contextlib import contextmanager
from dataclasses import dataclass

from scripts.modules._utils import (
    Color,
    OutputLevel,
    get_output_level,
    print_colored,
)


def format_duration(seconds: float) -> str:
    """Format seconds as a human-readable duration string.

    Returns:
        <1s  -> "XXXms"
        1-60s -> "X.Xs"
        >=60s -> "Xm XXs"
    """
    if seconds < 1.0:
        return f"{int(seconds * 1000)}ms"
    if seconds < 60.0:
        return f"{seconds:.1f}s"
    minutes = int(seconds // 60)
    secs = int(seconds % 60)
    return f"{minutes}m {secs:02d}s"


def _print_timing_row(
    name: str,
    duration: float,
    max_duration: float,
    success: bool,
) -> None:
    """Print one row of the timing summary table.

    Uses raw print() with inline ANSI codes for mixed-color output
    (same pattern as _utils.print_stat_bar).
    """
    g = Color.GREEN.value
    r = Color.RED.value
    d = Color.DIM.value
    x = Color.RESET.value

    icon_color = g if success else r
    icon = "\u2713" if success else "\u2717"
    duration_str = format_duration(duration)

    bar = ""
    if duration >= 0.5 and max_duration > 0:
        bar_len = max(1, int(duration / max_duration * 15))
        bar = f"  {d}{'\u2588' * bar_len}{x}"

    print(f"  {icon_color}{icon}{x}  {name:<28}{duration_str:>8}{bar}")


@dataclass
class _StepRecord:
    """A single timed step result."""

    name: str
    duration: float
    success: bool


class StepTimer:
    """Tracks timing for sequential workflow steps.

    Usage::

        timer = StepTimer()
        with timer.step("Tests"):
            run_tests()
        timer.print_summary()
    """

    def __init__(self) -> None:
        self._steps: list[_StepRecord] = []
        self._start: float = time.monotonic()

    @contextmanager
    def step(self, name: str):
        """Time a named step.

        Records success on normal exit, failure on any exception.
        Always re-raises exceptions.
        """
        start = time.monotonic()
        success = True
        try:
            yield
        except BaseException:
            success = False
            raise
        finally:
            elapsed = time.monotonic() - start
            self._steps.append(_StepRecord(name, elapsed, success))

    def print_summary(self) -> None:
        """Render the timing summary table."""
        if not self._steps:
            return
        if get_output_level() == OutputLevel.SILENT:
            return

        total = time.monotonic() - self._start
        max_dur = max(s.duration for s in self._steps)

        print()
        print_colored("=" * 60, Color.CYAN)
        print_colored("  Timing", Color.CYAN)
        print_colored("=" * 60, Color.CYAN)

        for s in self._steps:
            _print_timing_row(s.name, s.duration, max_dur, s.success)

        x = Color.RESET.value
        d = Color.DIM.value
        print(f"  {d}{'\u2500' * 49}{x}")
        print(f"    {'Total':<28}{format_duration(total):>8}")
        print()
