#!/usr/bin/env python3
"""
Update CORE_DART_LINT_NAMES in _tier_integrity.py from the Dart SDK linter.

Fetches the machine-readable rule list from dart-lang/linter on GitHub
and regenerates the CORE_DART_LINT_NAMES frozenset. Run before each
publish to catch new core lints that might collide with saropa_lints
rule names.

Usage:
    python scripts/update_core_lint_names.py          # update in place
    python scripts/update_core_lint_names.py --check  # exit 1 if stale

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import json
import re
import sys
import textwrap
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

# GitHub raw URL for the linter's machine-readable rule metadata.
_RULES_URL = (
    "https://raw.githubusercontent.com/dart-lang/linter"
    "/main/tool/machine/rules.json"
)

# Path to the tier integrity module relative to this script.
_TIER_INTEGRITY = (
    Path(__file__).resolve().parent / "modules" / "_tier_integrity.py"
)

# Regex matching the CORE_DART_LINT_NAMES block in _tier_integrity.py.
_BLOCK_RE = re.compile(
    r"(CORE_DART_LINT_NAMES: frozenset\[str\] = frozenset\(\{)"
    r"(.*?)"
    r"(\}\))",
    re.DOTALL,
)


def fetch_rule_names() -> list[str]:
    """Fetch all rule names from the dart-lang/linter GitHub repo."""
    try:
        with urlopen(_RULES_URL, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (URLError, OSError) as exc:
        print(f"ERROR: Failed to fetch {_RULES_URL}: {exc}", file=sys.stderr)
        sys.exit(1)

    # rules.json is an array of objects, each with a "name" field.
    names = sorted({entry["name"] for entry in data if "name" in entry})
    if not names:
        print("ERROR: No rule names found in fetched data.", file=sys.stderr)
        sys.exit(1)
    return names


def format_frozenset_body(names: list[str]) -> str:
    """Format rule names as indented quoted strings for the frozenset."""
    lines = [f'    "{name}",' for name in names]
    return "\n" + "\n".join(lines) + "\n"


def update_file(names: list[str], *, check_only: bool) -> bool:
    """Update or check the CORE_DART_LINT_NAMES block. Returns True if changed."""
    content = _TIER_INTEGRITY.read_text(encoding="utf-8")
    match = _BLOCK_RE.search(content)
    if not match:
        print(
            "ERROR: Could not find CORE_DART_LINT_NAMES block in "
            f"{_TIER_INTEGRITY}",
            file=sys.stderr,
        )
        sys.exit(1)

    new_body = format_frozenset_body(names)
    old_body = match.group(2)

    if old_body == new_body:
        print(f"CORE_DART_LINT_NAMES is up to date ({len(names)} rules).")
        return False

    if check_only:
        # Compute diff for reporting.
        old_names = set(re.findall(r'"(\w+)"', old_body))
        new_names = set(names)
        added = sorted(new_names - old_names)
        removed = sorted(old_names - new_names)
        print(
            f"CORE_DART_LINT_NAMES is STALE. "
            f"{len(added)} new, {len(removed)} removed.",
        )
        if added:
            print(f"  Added:   {', '.join(added[:10])}")
        if removed:
            print(f"  Removed: {', '.join(removed[:10])}")
        return True

    # Replace in place.
    new_content = (
        content[: match.start()]
        + match.group(1)
        + new_body
        + match.group(3)
        + content[match.end() :]
    )
    _TIER_INTEGRITY.write_text(new_content, encoding="utf-8")
    print(
        f"Updated CORE_DART_LINT_NAMES: {len(names)} rules "
        f"(was {len(re.findall(chr(34) + r'(\w+)' + chr(34), old_body))}).",
    )
    return True


def main() -> None:
    """Entry point."""
    check_only = "--check" in sys.argv

    names = fetch_rule_names()
    changed = update_file(names, check_only=check_only)

    if check_only and changed:
        print(
            "\nRun `python scripts/update_core_lint_names.py` to update.",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
