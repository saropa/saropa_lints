#!/usr/bin/env python3
"""
Organize loose report files into YYYY.MM/YYYY.MM.DD/ subfolders, then prune
empty directories.

Run:
  python reports/organize_reports.py

Loads the organizer vendored in this repo so move/prune logic runs without the
contacts repo present. Falls back to the contacts copy only if the vendored
module is missing.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_PROJECT_ROOT = Path(__file__).resolve().parent.parent

# Primary: the copy vendored into this project — self-contained, no sibling repo
# required. Fallback: the contacts repo, kept only so a stripped checkout that
# lost the vendored file still works when contacts is cloned alongside.
_VENDORED_MODULE_PATH = (
    _PROJECT_ROOT / "scripts" / ".shared" / "reports_organizer.py"
)
_CONTACTS_MODULE_PATH = (
    _PROJECT_ROOT.parent
    / "contacts"
    / "scripts"
    / ".shared"
    / "reports_organizer.py"
)

_CANDIDATE_MODULE_PATHS = (_VENDORED_MODULE_PATH, _CONTACTS_MODULE_PATH)


def _load_shared_organizer():
    module_path = next(
        (path for path in _CANDIDATE_MODULE_PATHS if path.is_file()),
        None,
    )
    if module_path is None:
        searched = "\n  ".join(str(p) for p in _CANDIDATE_MODULE_PATHS)
        print(
            f"ERROR: reports organizer module not found. Searched:\n  {searched}",
            file=sys.stderr,
        )
        sys.exit(1)
    spec = importlib.util.spec_from_file_location(
        "reports_organizer",
        module_path,
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load shared module from {module_path}")
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
