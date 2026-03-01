#!/usr/bin/env python3
"""Remove from ROADMAP.md every rule that has a dedicated file in bugs/roadmap or bugs/github_open_issues."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROADMAP = ROOT / "ROADMAP.md"
BUGS_ROADMAP = ROOT / "bugs" / "roadmap"
BUGS_ISSUES = ROOT / "bugs" / "github_open_issues"

# Rule names from bugs/roadmap/task_*.md
def rule_names_from_roadmap() -> set[str]:
    names = set()
    for f in BUGS_ROADMAP.glob("task_*.md"):
        names.add(f.stem.replace("task_", "", 1))
    return names

# Slugs from bugs/github_open_issues/issue_*.md (rule-like: snake_case)
def rule_names_from_issues() -> set[str]:
    names = set()
    for f in BUGS_ISSUES.glob("issue_*.md"):
        slug = f.stem
        if re.match(r"issue_\d+_", slug):
            slug = re.sub(r"^issue_\d+_", "", slug)
        if re.match(r"^[a-z][a-z0-9_]+$", slug) and slug not in ("readme", "bug_max_issues_setting_has_no_effect"):
            names.add(slug)
        # Normalize: prefer_custom_finder_over_find_patrol_tests -> prefer_custom_finder_over_find
        if "prefer_custom_finder_over_find" in slug:
            names.add("prefer_custom_finder_over_find")
    return names

def main() -> None:
    remove = rule_names_from_roadmap() | rule_names_from_issues()
    text = ROADMAP.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    rule_row_re = re.compile(r"^\|.*?`([a-z0-9_]+)`", re.UNICODE)
    out = []
    removed = 0
    for line in lines:
        m = rule_row_re.match(line)
        if m and m.group(1) in remove:
            removed += 1
            continue
        out.append(line)
    ROADMAP.write_text("".join(out), encoding="utf-8")
    print(f"Removed {removed} rule rows from ROADMAP.md (rules with files in bugs/roadmap or bugs/github_open_issues).")


if __name__ == "__main__":
    main()
