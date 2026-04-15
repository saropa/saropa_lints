"""List every rule that has no quick fix, grouped by file.

Output is written to reports/<yyyymmdd>/<yyyymmdd_HHmmss>_list_rules_without_fixes.log
"""
from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path

# Project root is one level above this script's directory
PROJECT_ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    rules_dir = PROJECT_ROOT / "lib" / "src" / "rules"
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

    # Build output lines
    lines: list[str] = []
    for fname, rules in results:
        lines.append(f"FILE: {fname}")
        for r in rules:
            lines.append(f"  - [ ] {r}")
        lines.append("")

    output_text = "\n".join(lines)

    # Write to reports/<yyyymmdd>/<yyyymmdd_HHmmss>_list_rules_without_fixes.log
    now = datetime.now()
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    date_folder = timestamp[:8]
    report_dir = PROJECT_ROOT / "reports" / date_folder
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / f"{timestamp}_list_rules_without_fixes.log"

    report_path.write_text(output_text, encoding="utf-8")
    print(f"Report written to: {report_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
