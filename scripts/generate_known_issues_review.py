#!/usr/bin/env python3
"""Generate a manual-review queue for known_issues.json entries pub.dev has
outgrown, grouped by confidence tier.

``check_known_issues_freshness.py`` auto-detects and warns only about the
narrow class of entry an audit run can safely call wrong (reason directly
falsified by a newer, non-discontinued release). Everything else pub.dev
shows as "moved on since this entry was recorded" — e.g. a caution-status
package with no falsifiable keyword, or a commercial/paid status where a
release doesn't touch the licensing claim at all — still needs a human
decision. This script produces that decision queue as a Markdown report
instead of leaving it as an inert side note (follow-up to the 2026-08-18
known_issues.json cleanup, see
plans/history/2026.08/2026.08.18/known-issues-stale-entries-audit.md).

This does not edit known_issues.json — it only writes a report.

Run from repository root::

    python scripts/generate_known_issues_review.py
    python scripts/generate_known_issues_review.py --write

Exit codes:
    0 - report generated (regardless of whether any entries were found)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_repo_root = str(Path(__file__).resolve().parent.parent)
if _repo_root not in sys.path:
    sys.path.insert(0, _repo_root)

from scripts.modules._known_issues_review_report import (
    build_known_issues_review_report,
    render_markdown,
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write the report to plans/known_issues_review.md instead of stdout.",
    )
    parser.add_argument(
        "--date",
        default=None,
        help="Date stamp for the report header (YYYY-MM-DD). Defaults to "
        "'generation time not tracked by this tool' if omitted, since "
        "shared modules avoid Date.now()-equivalents for reproducibility; "
        "pass explicitly for a dated report.",
    )
    args = parser.parse_args()

    project_dir = Path(__file__).resolve().parent.parent
    report = build_known_issues_review_report(project_dir)
    generated_on = args.date or "(date not specified — pass --date YYYY-MM-DD)"
    markdown = render_markdown(report, generated_on=generated_on)

    if args.write:
        out_path = project_dir / "plans" / "known_issues_review.md"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(markdown, encoding="utf-8")
        print(f"Wrote {out_path} ({len(report.entries)} entrie(s) to review).")
    else:
        print(markdown)

    return 0


if __name__ == "__main__":
    sys.exit(main())
