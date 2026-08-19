#!/usr/bin/env python3
"""Warn when extension known_issues.json entries are contradicted by pub.dev.

Standalone guard for the class of defect fixed 2026-08-18: seven entries in
``extension/src/vibrancy/data/known_issues.json`` (``timezone``, ``retrofit``,
``sqflite_sqlcipher``, ``intl_translation``, ``window_size``, ``routemaster``,
``flutter_keychain``) claimed a package was dead/abandoned/pre-null-safety
long after it had shipped an active, non-discontinued release. Nothing
re-verified the curated data against pub.dev, so the claim stayed wrong
indefinitely.

Shares the check logic with the publish audit
(``check_known_issues_freshness`` in ``scripts/modules/_known_issues_freshness.py``)
so a manual run and the automated pre-publish audit report identically.

Run from repository root::

    python scripts/check_known_issues_freshness.py
    python scripts/check_known_issues_freshness.py --fail-on-stale

Exit codes:
    0 - no confirmed-stale entries found (or --fail-on-stale not passed)
    1 - confirmed-stale entries found and --fail-on-stale was passed
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_repo_root = str(Path(__file__).resolve().parent.parent)
if _repo_root not in sys.path:
    sys.path.insert(0, _repo_root)

from scripts.modules._known_issues_freshness import check_known_issues_freshness


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fail-on-stale",
        action="store_true",
        help="Exit 1 if any confirmed-stale entry is found (for CI/publish gate use).",
    )
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    result = check_known_issues_freshness(project_dir)

    print(
        f"Checked {result.checked_count} lifecycle-claim entries against pub.dev "
        f"({result.network_error_count} network error(s))."
    )
    if not result.confirmed_stale:
        print("No confirmed-stale entries found.")
        return 0

    print(f"\n{len(result.confirmed_stale)} confirmed-stale entrie(s):\n")
    for s in result.confirmed_stale:
        print(
            f"  {s['name']} [{s['status']}] recorded={s['recorded_lastUpdated']} "
            f"actual={s['actual_latest_published']} (v{s['actual_latest_version']})"
        )
        print(f"    reason: {s['reason']}")

    if args.fail_on_stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
