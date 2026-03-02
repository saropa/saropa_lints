#!/usr/bin/env python3
"""Find duplicated text in LintCode problemMessage/correctionMessage across rules."""

import re
from pathlib import Path

RULES_DIR = Path(__file__).resolve().parent.parent / "lib" / "src" / "rules"
VERIFY_PHRASE = "Verify the change works correctly with existing tests and add coverage for the new behavior"


def extract_message_strings(content: str) -> list[tuple[int, str, str]]:
    """Extract (line_no, field, full_message) for problemMessage and correctionMessage."""
    results = []
    # Match problemMessage: or correctionMessage: then capture following string literal(s)
    pattern = re.compile(
        r"(problemMessage|correctionMessage)\s*:\s*\n\s*"
        r"((?:'[^']*'(?:\s*\n\s*'[^']*')*))",
        re.MULTILINE,
    )
    for m in pattern.finditer(content):
        field = m.group(1)
        raw = m.group(2)
        # Line number of start of this match
        line_no = content[: m.start()].count("\n") + 1
        # Split into individual string literals and strip quotes
        parts = re.findall(r"'([^']*)'", raw)
        full = "".join(parts)
        results.append((line_no, field, full, parts))
    return results


def find_duplications():
    """Scan all rule files for message duplications."""
    dup_inline = []  # same phrase twice in one message
    dup_multiline = []  # second string part duplicates substring of first
    verify_twice = []  # VERIFY_PHRASE appears twice in one message
    missing_space = []  # two parts concatenated without space (behavior.'Disable)

    for path in sorted(RULES_DIR.rglob("*.dart")):
        if path.name == "all_rules.dart":
            continue
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(RULES_DIR)
        for line_no, field, full, parts in extract_message_strings(text):
            # Inline: VERIFY_PHRASE twice
            if full.count(VERIFY_PHRASE) >= 2:
                verify_twice.append((str(rel), line_no, field, full[:120] + "..."))

            # Inline: any phrase of 20+ chars repeated (simple check)
            for length in (80, 60, 40):
                for i in range(len(full) - length):
                    sub = full[i : i + length]
                    if full.count(sub) >= 2 and " " in sub:
                        dup_inline.append((str(rel), line_no, field, sub[:60] + "..."))
                        break
                else:
                    continue
                break

            # Multiline: second part is substring of first (or first of second)
            if len(parts) >= 2:
                first = parts[0].strip()
                second = parts[1].strip()
                if len(second) >= 15 and (second in first or first in second):
                    dup_multiline.append((str(rel), line_no, field, first[:50], second[:50]))
                # Missing space: first ends with "behavior." and second starts with "Disable"
                if first.endswith("behavior.") and second.startswith("Disable"):
                    missing_space.append((str(rel), line_no))

    return {
        "verify_twice": verify_twice,
        "dup_inline": dup_inline,
        "dup_multiline": dup_multiline,
        "missing_space": missing_space,
    }


def main():
    d = find_duplications()
    print("=== VERIFY_PHRASE appears twice in one message ===")
    for item in d["verify_twice"]:
        print(f"  {item[0]}:{item[1]} ({item[2]})")
    print("\n=== Multiline: second part duplicates first (or vice versa) ===")
    for item in d["dup_multiline"]:
        print(f"  {item[0]}:{item[1]} ({item[2]}) | {item[3]!r} | {item[4]!r}")
    print("\n=== Missing space before 'Disable with:' (behavior.'Disable) ===")
    for item in d["missing_space"]:
        print(f"  {item[0]}:{item[1]}")
    print("\n=== Inline repeated phrase (20+ chars) ===")
    seen = set()
    for item in d["dup_inline"]:
        key = (item[0], item[1])
        if key not in seen:
            seen.add(key)
            print(f"  {item[0]}:{item[1]} ({item[2]}) ... {item[3]}")


if __name__ == "__main__":
    main()
