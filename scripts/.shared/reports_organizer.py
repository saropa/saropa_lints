#!/usr/bin/env python3
"""Shared helpers for the top-level reports/ folder layout.

Places files under:
  reports/YYYY.MM/YYYY.MM.DD/<basename>

Uses a date extracted from the filename when possible; otherwise the file's
ctime (consistent with filesystem "created" semantics on supported platforms).

After moves, deletes empty directories under reports/ deepest-first — dated
staging folders become empty once logs are reorganized.

Vendored into saropa_lints so the organizer runs without the contacts repo
present. Keep in sync with contacts/scripts/.shared/reports_organizer.py.

Version:   1.0
Author:    Saropa
Copyright: © 2026 Saropa
"""

from __future__ import annotations

import re
import shutil
import sys
import os
import time
from datetime import datetime
from pathlib import Path

# A report file modified within this window is treated as still being written
# by a running process and is left for a later run. The app's report emitter
# flushes a file incrementally, so moving it mid-write yanks it out from under
# the writer (the FileNotFoundError seen on 2026-06-07). 10s comfortably
# exceeds the gap between successive writes to one file without stranding
# completed files — they organize on the next pass.
_ACTIVE_QUIET_SECONDS = 10.0

# Matches common generator naming already used across repo tooling.
_DATE_PATTERNS: tuple[re.Pattern[str], ...] = (
    # 2026-05-06 / 2026.05.06 / 2026_05_06 — word-boundary guarded.
    re.compile(r"(?<!\d)(\d{4})[-_.](\d{2})[-_.](\d{2})(?!\d)"),
    # 20260506
    re.compile(r"(?<!\d)(\d{4})(\d{2})(\d{2})(?!\d)"),
)


def parse_date_from_name(filename: str) -> datetime | None:
    """Return first plausible calendar date found in ``filename``.

    Parsing stops at the first pattern that yields a valid ``datetime`` —
    callers rely on deterministic left-to-right filename conventions.
    """
    for pattern in _DATE_PATTERNS:
        match = pattern.search(filename)
        if not match:
            continue
        year, month, day = map(int, match.groups())
        try:
            return datetime(year, month, day)
        except ValueError:
            continue
    return None


def _resolve_skip_paths(
    reports_root: Path,
    project_root: Path | None,
    extra_skip_paths: frozenset[Path] | None,
) -> set[Path]:
    """Paths that must stay put (thin CLI entrypoints, explicit overrides).

    Always skip the conventional ``reports/organize_reports.py`` when
    ``project_root`` resolves it — otherwise pipeline runs would relocate the
    committed organizer script alongside generated logs on Windows/Linux.
    """
    skip: set[Path] = {p.resolve() for p in (extra_skip_paths or frozenset())}
    if project_root is None:
        return skip

    launcher = (project_root / "reports" / "organize_reports.py").resolve()
    if launcher.is_file():
        skip.add(launcher)
    return skip


def _should_skip_file(
    file_path: Path,
    reports_root: Path,
    skip_paths: set[Path],
) -> bool:
    if file_path.resolve() in skip_paths:
        return True
    relative = file_path.relative_to(reports_root)
    if any(part.startswith(".") for part in relative.parts):
        return True
    return False


def _resolve_unique_destination(destination: Path) -> Path:
    if not destination.exists():
        return destination

    stem = destination.stem
    suffix = destination.suffix
    counter = 1
    while True:
        candidate = destination.with_name(f"{stem}_{counter}{suffix}")
        if not candidate.exists():
            return candidate
        counter += 1


def _target_path_for_file(reports_root: Path, file_path: Path) -> Path:
    parsed_date = parse_date_from_name(file_path.name)
    # Filename wins; otherwise grouping follows birth time (`st_ctime` on Win32).
    effective_date = parsed_date or datetime.fromtimestamp(file_path.stat().st_ctime)
    month_folder = effective_date.strftime("%Y.%m")
    day_folder = effective_date.strftime("%Y.%m.%d")
    return reports_root / month_folder / day_folder / file_path.name


def _is_actively_written(file_path: Path, quiet_seconds: float) -> bool:
    """Return True when ``file_path`` was modified within the quiet period.

    A freshly-modified file is likely still being appended to by a running
    process; moving it would yank it out from under the writer. A stat failure
    means the file already vanished — report False and let the caller's
    vanished-source guard own that narrower race.
    """
    try:
        mtime = file_path.stat().st_mtime
    except OSError:
        return False
    return (time.time() - mtime) < quiet_seconds


def _is_already_organized(file_path: Path, reports_root: Path) -> bool:
    """Detect files already under reports/YYYY.MM/YYYY.MM.DD/."""
    try:
        relative = file_path.relative_to(reports_root)
    except ValueError:
        return False
    if len(relative.parts) < 3:
        return False
    month, day = relative.parts[0], relative.parts[1]
    # Skip-only behavior avoids noisy no-op output for already organized files.
    return bool(re.fullmatch(r"\d{4}\.\d{2}", month)) and bool(
        re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", day),
    )


def _iter_source_files(source_roots: tuple[Path, ...]) -> list[Path]:
    files: list[Path] = []
    for root in source_roots:
        if not root.is_dir():
            continue
        files.extend(candidate.resolve() for candidate in root.rglob("*") if candidate.is_file())
    return files


def _supports_color() -> bool:
    """Use ANSI colors only when writing to an interactive terminal."""
    return sys.stdout.isatty() and not bool(os.environ.get("NO_COLOR"))


def _print_progress(
    processed: int,
    total: int,
    moved_count: int,
    skipped_count: int,
    *,
    use_color: bool,
) -> None:
    if total <= 0:
        return
    width = 28
    filled = int((processed / total) * width)
    bar = "#" * filled + "-" * (width - filled)
    percent = (processed / total) * 100
    if use_color:
        cyan = "\033[96m"
        green = "\033[92m"
        yellow = "\033[93m"
        reset = "\033[0m"
        line = (
            f"\r{cyan}[{bar}] {percent:6.2f}%{reset} "
            f"{green}moved={moved_count}{reset} "
            f"{yellow}skipped={skipped_count}{reset}"
        )
    else:
        line = f"\r[{bar}] {percent:6.2f}% moved={moved_count} skipped={skipped_count}"
    print(line, end="", flush=True)
    if processed == total:
        print()


def _daily_log_path(reports_root: Path) -> Path:
    now = datetime.now()
    day_folder = reports_root / now.strftime("%Y.%m") / now.strftime("%Y.%m.%d")
    day_folder.mkdir(parents=True, exist_ok=True)
    return day_folder / f"{now.strftime('%Y%m%d_%H%M%S')}_organize_reports.log"


def organize_reports(
    reports_root: Path,
    project_root: Path | None = None,
    *,
    extra_skip_paths: frozenset[Path] | None = None,
    print_moves: bool = True,
    active_quiet_seconds: float = _ACTIVE_QUIET_SECONDS,
) -> tuple[int, int]:
    """Move loose report files into month/day folders under ``reports_root``.

    Returns ``(moved_count, skipped_count)``.
    """
    reports_root_r = reports_root.resolve()
    legacy_report_root = reports_root_r.parent / "report"
    source_roots: tuple[Path, ...] = (
        reports_root_r,
        legacy_report_root.resolve(),
    )
    skip_paths = _resolve_skip_paths(
        reports_root_r,
        project_root,
        extra_skip_paths,
    )
    moved_count = 0
    skipped_count = 0
    activity_log_path = _daily_log_path(reports_root_r)
    activity_lines: list[str] = []
    all_files = _iter_source_files(source_roots)
    total_files = len(all_files)
    use_color = _supports_color()
    if total_files:
        _print_progress(0, total_files, moved_count, skipped_count, use_color=use_color)

    for index, file_path_r in enumerate(all_files, start=1):
        try:
            if _should_skip_file(file_path_r, reports_root_r, skip_paths):
                skipped_count += 1
                activity_lines.append(f"Skipped (protected/hidden): {file_path_r}")
                _print_progress(
                    index,
                    total_files,
                    moved_count,
                    skipped_count,
                    use_color=use_color,
                )
                continue
        except ValueError:
            # Files under /report are valid inputs; only skip non-report paths.
            if not any(file_path_r.is_relative_to(root) for root in source_roots):
                skipped_count += 1
                activity_lines.append(f"Skipped (outside roots): {file_path_r}")
                _print_progress(
                    index,
                    total_files,
                    moved_count,
                    skipped_count,
                    use_color=use_color,
                )
                continue

        if _is_already_organized(file_path_r, reports_root_r):
            skipped_count += 1
            activity_lines.append(f"Skipped (already organized): {file_path_r}")
            _print_progress(
                index,
                total_files,
                moved_count,
                skipped_count,
                use_color=use_color,
            )
            continue

        # Proactively leave in-flight files for the next run. The file list is
        # captured once up front, so a file the app is still writing would
        # otherwise be moved (or vanish) mid-write. Checked here, just before
        # the move, so the mtime reflects the latest write — not the stale
        # value from when the scan started.
        if _is_actively_written(file_path_r, active_quiet_seconds):
            skipped_count += 1
            activity_lines.append(f"Skipped (active/being written): {file_path_r}")
            _print_progress(
                index,
                total_files,
                moved_count,
                skipped_count,
                use_color=use_color,
            )
            continue

        destination = _target_path_for_file(reports_root_r, file_path_r)
        destination = _resolve_unique_destination(destination)
        if file_path_r == destination.resolve():
            skipped_count += 1
            activity_lines.append(f"Skipped (already destination): {file_path_r}")
            _print_progress(
                index,
                total_files,
                moved_count,
                skipped_count,
                use_color=use_color,
            )
            continue

        destination.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.move(str(file_path_r), str(destination))
        except PermissionError:
            # Skip files locked by another process (e.g. log still being written)
            skipped_count += 1
            activity_lines.append(f"Skipped (locked): {file_path_r}")
            _print_progress(
                index,
                total_files,
                moved_count,
                skipped_count,
                use_color=use_color,
            )
            continue
        except FileNotFoundError:
            # The source file list is captured once up front (_iter_source_files);
            # a still-running app can rotate or delete a report file in the gap
            # before this move runs. A vanished source is a benign TOCTOU race,
            # not a fatal error — skip it instead of aborting the whole run.
            skipped_count += 1
            activity_lines.append(f"Skipped (vanished): {file_path_r}")
            _print_progress(
                index,
                total_files,
                moved_count,
                skipped_count,
                use_color=use_color,
            )
            continue
        moved_count += 1
        activity_lines.append(f"Moved: {file_path_r} -> {destination}")
        if print_moves:
            print(f"Moved: {file_path_r} -> {destination}")
        _print_progress(
            index,
            total_files,
            moved_count,
            skipped_count,
            use_color=use_color,
        )

    summary = (
        f"Done. Moved {moved_count} file(s), skipped {skipped_count} file(s)."
    )
    activity_log_path.write_text(
        "\n".join(
            [
                f"Run started: {datetime.now().isoformat(timespec='seconds')}",
                f"Reports root: {reports_root_r}",
                f"Legacy report root: {legacy_report_root}",
                *activity_lines,
                summary,
            ],
        )
        + "\n",
        encoding="utf-8",
    )

    return moved_count, skipped_count


def remove_empty_directories(
    reports_root: Path,
    *,
    extra_roots: tuple[Path, ...] = (),
    print_removed: bool = False,
) -> int:
    """Remove directories under ``reports_root`` that have no entries.

    Walks deepest paths first so parents become removable after children.
    """
    roots = tuple(root.resolve() for root in (reports_root, *extra_roots) if root.exists())
    if not roots:
        return 0

    dirs_found: list[Path] = []
    for root in roots:
        dirs_found.extend(p for p in root.rglob("*") if p.is_dir())
    dirs_found = sorted(dirs_found, key=lambda p: len(p.parts), reverse=True)

    protected_names = {"organize_reports.py"}
    removed = 0
    for folder in dirs_found:
        try:
            if any(folder.resolve() == root for root in roots):
                continue
            # Keep folders that still contain the launcher script.
            if any(
                child.is_file() and child.name in protected_names
                for child in folder.iterdir()
            ):
                continue
            if not any(folder.iterdir()):
                folder.rmdir()
                removed += 1
                if print_removed:
                    print(f"Removed empty: {folder}")
        except OSError:
            continue
    return removed


def organize_and_prune_reports(
    reports_root: Path,
    project_root: Path | None = None,
    *,
    extra_skip_paths: frozenset[Path] | None = None,
    print_moves: bool = True,
    print_removed: bool = False,
    active_quiet_seconds: float = _ACTIVE_QUIET_SECONDS,
) -> tuple[int, int, int]:
    """Organize filenames then prune empty dirs. Returns moved, skipped, removed."""
    moved, skipped = organize_reports(
        reports_root,
        project_root,
        extra_skip_paths=extra_skip_paths,
        print_moves=print_moves,
        active_quiet_seconds=active_quiet_seconds,
    )
    removed = remove_empty_directories(
        reports_root,
        extra_roots=((reports_root.resolve().parent / "report"),),
        print_removed=print_removed,
    )
    return moved, skipped, removed
