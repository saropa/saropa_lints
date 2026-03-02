#!/usr/bin/env python3
"""ARCHIVED: Logic moved to scripts/modules/_roadmap_implemented.py and runs as part of publish.

Find task_*.md in bugs/roadmap whose rule is already in tiers.dart; optionally delete them.
Run from project root: python scripts/history/check_roadmap_implemented.py
"""

import re
from pathlib import Path

_root = Path(__file__).resolve().parent.parent.parent
TIERS = _root / "lib" / "src" / "tiers.dart"
BUGS_ROADMAP = _root / "bugs" / "roadmap"


def main() -> None:
    tiers_text = TIERS.read_text(encoding="utf-8")
    # Every 'rule_name' in tiers.dart (rule names are snake_case)
    implemented = set(re.findall(r"'([a-z][a-z0-9_]+)'", tiers_text))
    # Exclude non-rule strings that can appear in the file
    for s in ("library", "show", "android", "dart", "flutter"):
        implemented.discard(s)

    task_files = list(BUGS_ROADMAP.glob("task_*.md"))
    task_rules = {f.stem.replace("task_", "", 1): f for f in task_files}

    already_implemented = [name for name in task_rules if name in implemented]
    already_implemented.sort()

    print(f"Implemented rules (tiers.dart): {len(implemented)}")
    print(f"Task files (bugs/roadmap): {len(task_rules)}")

    if not already_implemented:
        print("No task files correspond to already-implemented rules.")
        return

    print(f"Found {len(already_implemented)} task files for rules already in tiers.dart:")
    for name in already_implemented:
        print(f"  {name} -> task_{name}.md")

    # Delete the task files
    for name in already_implemented:
        task_rules[name].unlink()
        print(f"Deleted {task_rules[name]}")
    print(f"Deleted {len(already_implemented)} task files.")


if __name__ == "__main__":
    main()
