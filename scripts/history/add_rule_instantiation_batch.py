#!/usr/bin/env python3
"""One-off: Add Rule Instantiation group to category test files that lack it.

ARCHIVED: Moved to scripts/history/ after all category test files received
the Rule Instantiation group (2026-03). Kept for reference if new categories
are added later.

Reads lib/src/rules/{category}_rules.dart to get (class_name, code_name),
then inserts the group + testRule calls into test/{category}_rules_test.dart.
"""
from __future__ import annotations

import re
from pathlib import Path


def extract_rules_from_rules_file(path: Path) -> list[tuple[str, str]]:
    """Extract (class_name, code_name) from a *_rules.dart file."""
    text = path.read_text(encoding="utf-8")
    rules: list[tuple[str, str]] = []
    # Match class NameRule extends SaropaLintRule or DartLintRule (no private _)
    for m in re.finditer(
        r"class ([A-Z]\w+?) extends (?:SaropaLintRule|DartLintRule)\b",
        text,
    ):
        class_name = m.group(1)
        # Find next LintCode( in this class (from m.start() to next class or +2000 chars)
        rest = text[m.start() : m.start() + 2500]
        code_match = re.search(
            r"LintCode\s*\(\s*(?:name:\s*)?[\'\"]([a-z0-9_]+)[\'\"]",
            rest,
        )
        if code_match:
            code_name = code_match.group(1)
            rules.append((class_name, code_name))
    return rules


def category_display_name(category: str) -> str:
    """Turn snake_case category into Title Case for group name."""
    return " ".join(w.capitalize() for w in category.split("_"))


def generate_instantiation_group(category: str, rules: list[tuple[str, str]]) -> str:
    """Generate the Dart group and testRule calls."""
    display = category_display_name(category)
    lines = [
        "  group('" + display + " Rules - Rule Instantiation', () {",
        "    void testRule(String name, String codeName, dynamic Function() create) {",
        "      test(name, () {",
        "        final rule = create();",
        "        expect(rule.code.name, codeName);",
        r"        expect(rule.code.problemMessage, contains('[$codeName]'));",
        "        expect(rule.code.problemMessage.length, greaterThan(50));",
        "        expect(rule.code.correctionMessage, isNotNull);",
        "      });",
        "    }",
        "",
    ]
    for class_name, code_name in rules:
        lines.append(f"    testRule(")
        lines.append(f"      '{class_name}',")
        lines.append(f"      '{code_name}',")
        lines.append(f"      () => {class_name}(),")
        lines.append(f"    );")
        lines.append("")
    lines.append("  });")
    lines.append("")
    return "\n".join(lines)


def add_import_if_missing(content: str, import_uri: str) -> str:
    """Add rules import after other imports if missing."""
    import_line = f"import '{import_uri}';"
    if import_line in content:
        return content
    if "package:test/test.dart" in content:
        content = content.replace(
            "import 'package:test/test.dart';",
            "import 'package:test/test.dart';\n\n" + import_line,
            1,
        )
    return content


def add_group_to_main(content: str, group_block: str) -> str:
    """Insert the Rule Instantiation group as first group inside main()."""
    # Insert right after "void main() {" and optional newline
    old = "void main() {\n"
    if old not in content:
        old = "void main() {"
    new_block = "void main() {\n" + group_block + "\n  "
    content = content.replace(old, new_block, 1)
    return content


def _rules_path_and_import(project_dir: Path, category: str) -> tuple[Path | None, str | None]:
    """Return (rules_path, import_uri) for category. Checks top-level, packages/, platforms/."""
    base = project_dir / "lib" / "src" / "rules"
    for subdir, import_prefix in [("", "package:saropa_lints/src/rules"), ("packages", "package:saropa_lints/src/rules/packages"), ("platforms", "package:saropa_lints/src/rules/platforms")]:
        path = base / subdir / f"{category}_rules.dart" if subdir else base / f"{category}_rules.dart"
        if path.exists():
            return path, f"{import_prefix}/{category}_rules.dart"
    return None, None


def process_file(project_dir: Path, category: str) -> bool:
    """Add Rule Instantiation to test file. Returns True if changed."""
    rules_path, import_uri = _rules_path_and_import(project_dir, category)
    test_path = project_dir / "test" / f"{category}_rules_test.dart"
    if rules_path is None or import_uri is None or not test_path.exists():
        return False
    rules = extract_rules_from_rules_file(rules_path)
    if not rules:
        return False
    content = test_path.read_text(encoding="utf-8")
    if "Rule Instantiation" in content:
        return False
    content = add_import_if_missing(content, import_uri)
    group_block = generate_instantiation_group(category, rules)
    content = add_group_to_main(content, group_block)
    test_path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    # Resolve project root (two levels up from scripts/history/)
    project_dir = Path(__file__).resolve().parent.parent.parent
    import sys
    if str(project_dir) not in sys.path:
        sys.path.insert(0, str(project_dir))
    from scripts.modules._rule_metrics import _compute_rule_instantiation_stats

    rules_dir = project_dir / "lib" / "src" / "rules"
    _, _, missing = _compute_rule_instantiation_stats(project_dir, rules_dir)
    done = 0
    for category in missing:
        if process_file(project_dir, category):
            done += 1
            print(f"  Added Rule Instantiation: {category} ({done}/{len(missing)})")
    print(f"Done. Updated {done} test files.")


if __name__ == "__main__":
    main()
