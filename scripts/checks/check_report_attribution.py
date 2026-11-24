#!/usr/bin/env python3
"""Check that a diagnostic code is actually emitted by a saropa_lints rule.

Why this exists: false-positive reports keep arriving for diagnostics that
saropa_lints does not emit (Dart SDK codes such as `deprecated_member_use` or
`unused_result`, or codes from sibling plugins). Each one costs a fix agent a
round-trip to discover. Running this BEFORE filing (or before starting a fix)
proves attribution in one second.

Usage:
    python scripts/checks/check_report_attribution.py <code> [<code> ...]
    python scripts/checks/check_report_attribution.py --file bugs/<report>.md

Exit code: 0 when every code is defined in lib/src/rules/, 1 when any code has
zero matches (not a saropa_lints rule - do not file or fix here), 2 on usage
errors.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Repo root = two levels above scripts/checks/.
ROOT = Path(__file__).resolve().parents[2]
RULES_DIR = ROOT / "lib" / "src" / "rules"

# Codes that the Dart SDK analyzer owns. A zero-match here is expected, so the
# message can point the reporter upstream instead of just saying "not found".
SDK_CODES = {
    "deprecated_member_use",
    "deprecated_member_use_from_same_package",
    "unused_result",
    "unused_import",
    "unused_local_variable",
    "unused_element",
    "unused_field",
    "unused_catch_clause",
    "unused_shown_name",
    "dead_code",
    "invalid_use_of_protected_member",
    "invalid_use_of_visible_for_testing_member",
}

# snake_case token inside backticks, e.g. `require_disabled_state`.
_BACKTICKED = re.compile(r"`([a-z][a-z0-9_]{3,})`")
# The template's header line, e.g. "Rule: `require_disabled_state`".
_RULE_LINE = re.compile(r"^Rule:\s*`?([a-z][a-z0-9_]+)`?", re.MULTILINE)


def codes_from_report(path: Path) -> list[str]:
    """Extract candidate rule names from a bug report.

    Prefers the template's `Rule:` header (authoritative); falls back to every
    backticked snake_case token in the title/first 15 lines when the header is
    missing, which covers older free-form reports.
    """
    text = path.read_text(encoding="utf-8")
    header = _RULE_LINE.findall(text)
    if header:
        return header
    head = "\n".join(text.splitlines()[:15])
    return sorted(set(_BACKTICKED.findall(head)))


def defined_in_rules(code: str) -> list[str]:
    """Return 'file:line' hits where `'code'` is a quoted string in rules/."""
    needle = f"'{code}'"
    hits: list[str] = []
    for dart in RULES_DIR.rglob("*.dart"):
        for no, line in enumerate(dart.read_text(encoding="utf-8").splitlines(), 1):
            if needle in line:
                hits.append(f"{dart.relative_to(ROOT).as_posix()}:{no}")
    return hits


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "--file":
        codes = codes_from_report(Path(argv[1]))
    else:
        codes = argv
    if not codes:
        print(__doc__)
        return 2

    failed = False
    for code in codes:
        hits = defined_in_rules(code)
        if hits:
            print(f"OK    {code}: defined at {hits[0]}")
        elif code in SDK_CODES:
            print(f"NOT OURS {code}: Dart SDK analyzer diagnostic - report to dart-lang/sdk "
                  "or the owning package, not here.")
            failed = True
        else:
            print(f"NOT OURS {code}: zero matches in lib/src/rules/ - sibling plugin or "
                  "wrong name. See bugs/ISSUE_REPORT_GUIDE.md 'Confirm Attribution'.")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
