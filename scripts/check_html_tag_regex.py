#!/usr/bin/env python3
r"""Fail if TypeScript files contain HTML tag regexes that would trigger CodeQL.

CodeQL's ``js/bad-tag-filter`` rule flags regexes that attempt to match
``<script>`` or ``<style>`` tags but miss common browser-accepted variants:

- Missing case-insensitive flag (``i``): ``<SCRIPT>`` is valid HTML.
- Closing tag without attribute tolerance: browsers accept ``</script >``
  and ``</script foo="bar">``, so ``<\/script>`` alone is insufficient;
  use ``<\/script[^>]*>`` instead.

This script scans ``extension/src/**/*.ts`` for these patterns so CI catches
them before CodeQL reports them on push.

Run from repository root::

    python scripts/check_html_tag_regex.py

Exit codes:
    0 - no violations found
    1 - one or more violations detected
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Tags that CodeQL's js/bad-tag-filter specifically checks.
_SECURITY_TAGS = ("script", "style")

# Matches a regex literal used in a method call or assignment context.
# The body allows escaped characters (\\.) so that \/ inside the regex
# does not end the match prematurely.
_REGEX_IN_CONTEXT = re.compile(
    r"(?:"
    # .match( / .replace( / .test( / .search( followed by a regex literal
    r"\.(?:match|replace|test|search)\s*\(\s*"
    # or: assignment to a variable
    r"|(?:const|let|var)\s+\w+\s*=\s*"
    r"|=\s*"
    r")"
    r"/"                                 # opening regex delimiter
    r"(?P<body>(?:[^/\\\n]|\\.)+)"       # body: non-slash/non-backslash, or escaped char
    r"/(?P<flags>[gimsuy]*)"             # closing delimiter + flags
)

# Closing-tag pattern that is too restrictive: </tag> or </tag\s*> but
# NOT </tag[^>]*> which handles attributes and whitespace.
_BAD_CLOSE = re.compile(
    r"<\\?/"                            # start of closing tag
    r"\s*(?:script|style)"              # tag name
    r"(?:"
    r"\\?\s*>"                           # bare >, no tolerance
    r"|\\s\*\\?>"                        # \s*> only whitespace, not attributes
    r")"
    , re.IGNORECASE
)


def _check_file(path: Path) -> list[str]:
    """Return a list of violation messages for a single file."""
    violations: list[str] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    rel = path.as_posix()

    for line_no, line in enumerate(text.splitlines(), start=1):
        # Skip comment lines (single-line // and block-comment continuations).
        stripped = line.lstrip()
        if stripped.startswith("//") or stripped.startswith("*"):
            continue

        # Find regex literals in method-call or assignment context.
        for m in _REGEX_IN_CONTEXT.finditer(line):
            body = m.group("body")
            flags = m.group("flags")

            # Only check regexes that reference security-sensitive tags.
            tag_match = re.search(
                r"<\\?/?(?:" + "|".join(_SECURITY_TAGS) + r")\b",
                body,
                re.IGNORECASE,
            )
            if not tag_match:
                continue

            # Check 1: missing case-insensitive flag.
            if "i" not in flags:
                violations.append(
                    f"{rel}:{line_no}: regex matches <script>/<style> "
                    f"without the `i` flag — CodeQL js/bad-tag-filter "
                    f"requires case-insensitive matching"
                )

            # Check 2: closing tag without attribute tolerance.
            if _BAD_CLOSE.search(body):
                violations.append(
                    f"{rel}:{line_no}: closing tag pattern is too "
                    f"restrictive — use `[^>]*>` instead of `\\s*>` or "
                    f"bare `>` to handle `</script foo=\"bar\">`"
                )

    return violations


def main() -> int:
    """Scan extension TypeScript files for bad HTML tag filter regexes."""
    root = Path("extension/src")
    if not root.is_dir():
        print(f"ERROR: {root} not found — run from repository root.",
              file=sys.stderr)
        return 1

    violations: list[str] = []
    for ts_file in sorted(root.rglob("*.ts")):
        violations.extend(_check_file(ts_file))

    if violations:
        print(f"Found {len(violations)} CodeQL js/bad-tag-filter "
              f"violation(s):\n")
        for v in violations:
            print(f"  {v}")
        print(
            "\nFix: add the `i` flag and use `[^>]*>` in closing tags. "
            "See https://codeql.github.com/codeql-query-help/javascript/"
            "js-bad-tag-filter/"
        )
        return 1

    print("No CodeQL js/bad-tag-filter violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
