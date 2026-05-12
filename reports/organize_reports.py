#!/usr/bin/env python3
"""
Organize loose report files into YYYY.MM/YYYY.MM.DD/ subfolders, then prune
empty directories.

Run:
  python reports/organize_reports.py

Imports the shared organizer from the contacts repo so move/prune logic stays
in one place across all Saropa projects.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

# The shared organizer lives in the contacts repo — single source of truth
# for date parsing, move logic, progress bar, and empty-dir cleanup.
_SHARED_MODULE_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "contacts"
    / "scripts"
    / ".shared"
    / "reports_organizer.py"
)


def _load_shared_organizer():
    if not _SHARED_MODULE_PATH.is_file():
        print(
            f"ERROR: Shared organizer not found at {_SHARED_MODULE_PATH}\n"
            "Make sure the contacts repo is cloned alongside this project.",
            file=sys.stderr,
        )
        sys.exit(1)
    spec = importlib.util.spec_from_file_location(
        "reports_organizer",
        _SHARED_MODULE_PATH,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load shared module from {_SHARED_MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    mod = _load_shared_organizer()
    reports_root = Path(__file__).resolve().parent
    project_root = reports_root.parent

    # _cache holds SDK export caches — not report output, so skip it.
    cache_dir = reports_root / "_cache"
    extra_skip: frozenset[Path] = frozenset()
    if cache_dir.is_dir():
        extra_skip = frozenset(cache_dir.rglob("*"))

    moved, skipped, removed = mod.organize_and_prune_reports(
        reports_root,
        project_root=project_root,
        extra_skip_paths=extra_skip,
        # Keep terminal output readable; detailed moved/skipped entries go
        # to the daily log written by the shared organizer.
        print_moves=False,
        print_removed=False,
    )
    print(
        f"\nDone. Moved {moved} file(s), skipped {skipped} file(s), "
        f"removed {removed} empty folder(s).",
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
