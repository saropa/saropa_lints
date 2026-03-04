"""List every rule that has no quick fix, grouped by file. One-off for QUICK_FIX_PLAN.md."""
from __future__ import annotations

import re
from pathlib import Path


def main() -> None:
    rules_dir = Path(__file__).resolve().parent.parent / "lib" / "src" / "rules"
    name_pat = re.compile(r"LintCode\(\s*(?:name:\s*)?'([a-z0-9_]+)'")
    fix_pat = re.compile(r"get fixGenerators =>\s*\[")

    results: list[tuple[str, list[str]]] = []

    for dart_file in sorted(rules_dir.glob("**/*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        class_starts = [m.start() for m in re.finditer(r"class\s+\w+\s+extends\s+", content)]
        if not class_starts:
            continue
        rule_without_fix: list[str] = []
        for m in name_pat.finditer(content):
            rule_name = m.group(1)
            pos = m.start()
            # find which class we're in: last class start before pos
            class_idx = -1
            for i, cstart in enumerate(class_starts):
                if cstart < pos:
                    class_idx = i
                else:
                    break
            if class_idx < 0:
                continue
            class_start = class_starts[class_idx]
            next_class = class_starts[class_idx + 1] if class_idx + 1 < len(class_starts) else len(content)
            block = content[class_start:next_class]
            if not fix_pat.search(block):
                rule_without_fix.append(rule_name)
        if rule_without_fix:
            results.append((dart_file.name, sorted(set(rule_without_fix))))

    for fname, rules in results:
        print("FILE:", fname)
        for r in rules:
            print("  - [ ]", r)
        print()


if __name__ == "__main__":
    main()
