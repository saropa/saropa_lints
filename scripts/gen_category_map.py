"""Regenerate lib/src/scan/rule_category_map.dart from rule source files.

Parses every *_rule*.dart file under lib/src/rules/, extracts rule names
from `LintCode(\n  'rule_name'` constructor calls, and maps each to its
parent directory name (= category slug). Run whenever a rule file is
added, removed, or moved between category directories — the drift test
in test/scan/rule_tier_index_test.dart fails loudly if this map goes
stale, naming the run of this script as the fix.
"""

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RULES_DIR = REPO_ROOT / "lib" / "src" / "rules"
OUTPUT = REPO_ROOT / "lib" / "src" / "scan" / "rule_category_map.dart"

# Rule names are declared as `LintCode(\n    'rule_name',` — the name is
# on its own line, not on the same line as the constructor call.
LINT_CODE_RE = re.compile(r"LintCode\(\s*\n\s*'([^']+)'")


def main() -> None:
    entries: dict[str, str] = {}

    for dart_file in sorted(RULES_DIR.rglob("*_rule*.dart")):
        if dart_file.name == "all_rules.dart":
            continue

        # Category = parent directory name relative to rules/, e.g.
        # lib/src/rules/security/foo_rule.dart -> 'security'.
        rel = dart_file.relative_to(RULES_DIR)
        category = rel.parts[0]

        content = dart_file.read_text(encoding="utf-8")
        for match in LINT_CODE_RE.finditer(content):
            rule_name = match.group(1)
            if rule_name in entries:
                # First-writer wins — mirrors _buildTierIndex()'s existing
                # defensive handling of the (currently impossible, since
                # rule names are globally unique) duplicate-name case.
                continue
            entries[rule_name] = category

    sorted_entries = sorted(entries.items())

    lines = [
        "/// Auto-generated rule-name → category map.",
        "///",
        "/// Category is derived from the parent directory of each rule's source",
        "/// file under `lib/src/rules/`. Run the generator to regenerate:",
        "///   `python scripts/gen_category_map.py`",
        "///",
        "/// DO NOT EDIT BY HAND — changes will be overwritten on regeneration.",
        "/// A unit test validates that every registered rule appears in this map.",
        "// ignore_for_file: prefer_single_quotes",
        "library;",
        "const Map<String, String> ruleCategoryMap = <String, String>{",
    ]
    for name, cat in sorted_entries:
        lines.append(f"  '{name}': '{cat}',")
    lines.append("};")

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Generated {len(sorted_entries)} entries -> {OUTPUT}")


if __name__ == "__main__":
    main()
