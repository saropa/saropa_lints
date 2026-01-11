#!/usr/bin/env python3
"""Compare implemented lint rules with ROADMAP.md entries."""

import re
from pathlib import Path


def get_implemented_rules(rules_dir: Path) -> set[str]:
    """Extract rule names from LintCode definitions in Dart files."""
    rules = set()
    pattern = re.compile(r"name:\s*'([a-z_]+)'")

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        rules.update(pattern.findall(content))

    return rules


def get_roadmap_rules(roadmap_path: Path) -> set[str]:
    """Extract rule names from ROADMAP.md table entries."""
    rules = set()
    pattern = re.compile(r"^\|\s*`([a-z_]+)`\s*\|", re.MULTILINE)

    content = roadmap_path.read_text(encoding="utf-8")
    rules.update(pattern.findall(content))

    return rules


def main():
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    rules_dir = project_root / "lib" / "src" / "rules"
    roadmap_path = project_root / "ROADMAP.md"

    implemented = get_implemented_rules(rules_dir)
    roadmap = get_roadmap_rules(roadmap_path)

    print(f"Implemented rules: {len(implemented)}")
    print(f"ROADMAP rules: {len(roadmap)}")

    # Find exact matches (implemented AND in roadmap)
    duplicates = implemented & roadmap
    print(f"\n=== RULES TO REMOVE FROM ROADMAP ({len(duplicates)}) ===")
    for rule in sorted(duplicates):
        print(f"  {rule}")

    # Find close matches (off by small differences)
    print(f"\n=== POSSIBLE NEAR-MATCHES ===")
    for roadmap_rule in sorted(roadmap - duplicates):
        for impl_rule in implemented:
            # Check for common variations
            if (roadmap_rule.replace("_", "") == impl_rule.replace("_", "") or
                roadmap_rule + "s" == impl_rule or
                roadmap_rule == impl_rule + "s"):
                print(f"  ROADMAP: {roadmap_rule}  ->  Implemented: {impl_rule}")


if __name__ == "__main__":
    main()
