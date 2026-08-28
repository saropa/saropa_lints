"""Report plans/*.md files that don't follow the PLAN_<name>.md convention.

Informational only (always exits 0) — several pre-existing files under
plans/ intentionally use a different naming scheme (design docs, TODO
lists, one-off consolidation notes) and this script does not attempt to
judge which of those are legitimate exceptions vs. drift. It exists so a
human can periodically eyeball the list rather than a plan silently never
getting the PLAN_* phased-checklist treatment.

Usage:
    python scripts/check_plan_naming.py
"""

import re
import sys
from pathlib import Path

PLANS_DIR = Path('plans')

# PLAN_<name>.md, case-sensitive prefix — matches the convention used by
# plans/PLAN_analyzer_13_migration.md and similar phased-checklist plans.
_PLAN_NAME = re.compile(r'^PLAN_.+\.md$')


def main() -> int:
    if not PLANS_DIR.is_dir():
        print(f'ERROR: {PLANS_DIR} not found.')
        return 1

    # Only the top-level plans/*.md files are in scope — plans/history/ is
    # an archive with its own dotted-date convention, not a naming target.
    all_md = sorted(p.name for p in PLANS_DIR.glob('*.md'))
    non_conforming = [name for name in all_md if not _PLAN_NAME.match(name)]

    if not non_conforming:
        print(f'plan naming: all {len(all_md)} files under plans/ match PLAN_*.md.')
        return 0

    print(
        f'plan naming: {len(non_conforming)} of {len(all_md)} files under '
        "plans/ don't match PLAN_<name>.md (informational, not a failure):"
    )
    for name in non_conforming:
        print(f'  - plans/{name}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
