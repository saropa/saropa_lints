"""
Per-file comment coverage scan for publish banner (worst offenders + progress).

Builds on _code_comment_metrics heuristics: same roots, same comment detection.
Progress uses an ASCII bar (no extra dependencies).

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

from scripts.modules._code_comment_metrics import (
    _dart_comment_lines,
    _iter_files,
    _physical_line_count,
    _python_comment_lines,
    _skip_dart_artifact,
    _ts_comment_lines,
)
from scripts.modules._utils import Color, print_colored


@dataclass(frozen=True)
class FileCommentStat:
    """One source file's line counts for comment coverage ranking."""

    rel_path: str
    physical_lines: int
    comment_line_count: int

    @property
    def ratio(self) -> float:
        if self.physical_lines <= 0:
            return 0.0
        return self.comment_line_count / self.physical_lines


def _format_progress_bar(done: int, total: int, width: int = 28) -> str:
    """ASCII progress bar like [########------------] 40%."""
    if total <= 0:
        return "[" + (" " * width) + "] 0%"
    filled = int(round(width * done / total))
    filled = min(max(filled, 0), width)
    bar = "#" * filled + "-" * (width - filled)
    pct = 100.0 * done / total
    return f"[{bar}] {pct:5.1f}%"


def collect_per_file_comment_stats(
    project_dir: Path,
    *,
    min_physical_lines: int = 15,
    exclude_fixture_subdir: bool = True,
    progress_to_stderr: bool = False,
) -> list[FileCommentStat]:
    """Scan primary trees; return one stat per file (sorted ascending by ratio)."""
    paths_jobs: list[tuple[Path, bool, bool]] = []
    # (absolute path, use_ts_templates, is_python)

    for p in sorted(
        x for x in _iter_files(project_dir / "lib", ".dart")
        if not _skip_dart_artifact(x)
    ):
        paths_jobs.append((p, False, False))
    for p in sorted(_iter_files(project_dir / "test", ".dart")):
        paths_jobs.append((p, False, False))
    for p in sorted(_iter_files(project_dir / "bin", ".dart")):
        paths_jobs.append((p, False, False))

    packages_dir = project_dir / "packages"
    if packages_dir.is_dir():
        for pkg in sorted(packages_dir.iterdir()):
            if not pkg.is_dir():
                continue
            for p in sorted(
                x for x in _iter_files(pkg / "lib", ".dart")
                if not _skip_dart_artifact(x)
            ):
                paths_jobs.append((p, False, False))

    for p in sorted(_iter_files(project_dir / "extension" / "src", ".ts")):
        paths_jobs.append((p, True, False))

    for p in sorted(_iter_files(project_dir / "scripts", ".py")):
        paths_jobs.append((p, False, True))

    filtered: list[tuple[Path, bool, bool]] = []
    for path, templates, is_py in paths_jobs:
        rel = path.relative_to(project_dir).as_posix()
        if exclude_fixture_subdir and "test/fixtures/" in rel:
            continue
        filtered.append((path, templates, is_py))

    out: list[FileCommentStat] = []
    total = len(filtered)
    for i, (path, templates, is_py) in enumerate(filtered, start=1):
        rel = path.relative_to(project_dir).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        phys = _physical_line_count(text)
        if phys < min_physical_lines:
            continue
        if is_py:
            n = len(_python_comment_lines(text))
        elif templates:
            n = len(_ts_comment_lines(text))
        else:
            n = len(_dart_comment_lines(text))
        out.append(FileCommentStat(rel_path=rel, physical_lines=phys, comment_line_count=n))

        if progress_to_stderr and total > 0:
            # Update same line for compact progress (files scanned includes skipped)
            bar = _format_progress_bar(i, total)
            sys.stderr.write(f"\r  Comment scan {bar} {i}/{total} ")
            sys.stderr.flush()

    if progress_to_stderr and total > 0:
        sys.stderr.write("\n")
        sys.stderr.flush()

    out.sort(key=lambda s: (s.ratio, -s.physical_lines, s.rel_path))
    return out


def display_comment_coverage_worst_files(
    project_dir: Path,
    *,
    top_n: int = 25,
    min_physical_lines: int = 15,
    show_progress_bar: bool = True,
) -> None:
    """Print lowest comment-density files (token heuristic; not semantic quality)."""
    stats = collect_per_file_comment_stats(
        project_dir,
        min_physical_lines=min_physical_lines,
        exclude_fixture_subdir=True,
        progress_to_stderr=show_progress_bar,
    )
    if not stats:
        return

    worst = stats[: min(top_n, len(stats))]
    zero_ct = sum(1 for s in stats if s.comment_line_count == 0)

    print()
    print_colored(
        "  > Comment coverage -- worst files (by comment-line / physical-line)",
        Color.WHITE,
    )
    print()
    print_colored(
        f"    Files scanned (>={min_physical_lines} lines, excl. test/fixtures): {len(stats):,}  "
        f"|  zero comment lines: {zero_ct:,}",
        Color.CYAN,
    )
    print_colored(
        "    (Heuristic only: //, /* */, outside strings; Python: # tokens. "
        "Does not measure doc quality - see plan/COMMENT_COVERAGE_PLAN.md.)",
        Color.DIM,
    )
    print()
    w = 52
    print_colored(f"    {'Path':<{w}s} {'Lines':>6} {'Cmnt':>5} {'Ratio':>7}", Color.DIM)
    for s in worst:
        r = 100.0 * s.ratio
        tail = s.rel_path if len(s.rel_path) <= w else "..." + s.rel_path[-(w - 3) :]
        print_colored(
            f"    {tail:<{w}s} {s.physical_lines:>6,} {s.comment_line_count:>5} {r:>6.2f}%",
            Color.WHITE,
        )
    print()


def display_full_comment_coverage_report(project_dir: Path) -> None:
    """Banner section: aggregate buckets + worst-file table + scan progress."""
    # Re-use bucket summary from existing module (no second full read of bodies).
    from scripts.modules._code_comment_metrics import display_code_comment_metrics

    display_code_comment_metrics(project_dir)
    display_comment_coverage_worst_files(
        project_dir, top_n=25, min_physical_lines=15, show_progress_bar=True,
    )
