#!/usr/bin/env python3
"""
Print the roadmap/bugs/proposals work report outside the full publish pipeline.

Wraps scripts/modules/_rule_metrics.py's display_roadmap_summary() - the same
"WORK REPORT" banner publish.py prints during its audit steps - as a
standalone command, so a contributor can check outstanding work without
running the interactive publish menu.

By default it shows everything (roadmap rules, deferred rules, fixture
TODOs, unsolved bugs, and open proposals), matching the publish banner.
--bugs-only / --proposals-only narrow the report to just bugs/*.md issues
of that kind and skip the roadmap/TODO scan entirely, for a faster,
focused check.

Usage (from repository root):

    python scripts/roadmap_status.py
    python scripts/roadmap_status.py --bugs-only
    python scripts/roadmap_status.py --proposals-only

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Exit Codes:
    0  - Success
    1  - project_dir is not a saropa_lints checkout (no bugs/ directory)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Same sys.path setup as publish.py / run_extension_local.py: __file__ lives
# under scripts/, parent.parent is the repo root — insert it first so
# `from scripts.modules...` resolves the same way regardless of cwd.
_SCRIPTS_PARENT = str(Path(__file__).resolve().parent.parent)
if _SCRIPTS_PARENT not in sys.path:
    sys.path.insert(0, _SCRIPTS_PARENT)

from scripts.modules._rule_metrics import display_roadmap_summary  # noqa: E402
from scripts.modules._utils import enable_ansi_support, print_error  # noqa: E402

SCRIPT_VERSION = "1.0"


def _parse_args(argv: list[str]) -> argparse.Namespace:
    """Define CLI; ``epilog`` pulls in the module docstring for ``--help``."""
    p = argparse.ArgumentParser(
        description="Print the roadmap/bugs/proposals work report.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument(
        "--bugs-only",
        action="store_true",
        help="Show only unsolved bugs/*.md issues; skip roadmap and TODO rows.",
    )
    p.add_argument(
        "--proposals-only",
        action="store_true",
        help="Show only open bugs/proposal_*.md feature requests; skip roadmap and TODO rows.",
    )
    p.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {SCRIPT_VERSION}",
    )
    ns = p.parse_args(argv)
    if ns.bugs_only and ns.proposals_only:
        p.error("--bugs-only and --proposals-only are mutually exclusive.")
    return ns


def main(argv: list[str] | None = None) -> int:
    """Entry: parse args, resolve the repo root, print the filtered report."""
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    # Sets up ANSI color escapes on Windows consoles and reconfigures stdout
    # to UTF-8 — without it, the bar-chart glyphs in the report crash with
    # UnicodeEncodeError on the default Windows cp1252 console.
    enable_ansi_support()

    project_dir = Path(_SCRIPTS_PARENT)
    bugs_dir = project_dir / "bugs"
    if not bugs_dir.is_dir():
        print_error(f"No bugs/ directory found under {project_dir} — not a saropa_lints checkout?")
        return 1

    issue_filter: str | None = None
    if args.bugs_only:
        issue_filter = "bugs"
    elif args.proposals_only:
        issue_filter = "proposals"

    display_roadmap_summary(
        project_dir, bugs_dir=bugs_dir, issue_filter=issue_filter,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
