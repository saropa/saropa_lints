"""
Check and fix bugs/roadmap task files for implemented rules.

Task files in bugs/roadmap (task_<rule_name>.md) should exist only for rules
not yet in lib/src/tiers.dart. This module finds task files whose rule is
already implemented and removes them so the roadmap stays accurate.

Used by the publish script (Step 1 auto-fix) and can be run standalone for
audit-only or one-off cleanup.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

# Rule names in tiers.dart are quoted snake_case; exclude common non-rule tokens.
_EXCLUDE_FROM_TIERS = frozenset({
    "library", "show", "android", "dart", "flutter",
})


def get_implemented_rules(project_dir: Path) -> set[str]:
    """Return set of rule names (snake_case) that appear in tiers.dart."""
    tiers_path = project_dir / "lib" / "src" / "tiers.dart"
    if not tiers_path.exists():
        return set()
    text = tiers_path.read_text(encoding="utf-8")
    # Match quoted snake_case identifiers (rule names)
    found = set(re.findall(r"'([a-z][a-z0-9_]+)'", text))
    return found - _EXCLUDE_FROM_TIERS


def get_stale_roadmap_tasks(project_dir: Path) -> list[tuple[str, Path]]:
    """Return list of (rule_name, task_file_path) for tasks whose rule is in tiers.dart."""
    roadmap_dir = project_dir / "bugs" / "roadmap"
    if not roadmap_dir.exists():
        return []
    implemented = get_implemented_rules(project_dir)
    stale: list[tuple[str, Path]] = []
    # Task files may live in nested folders (e.g. bugs/roadmap/open_issues/).
    for path in sorted(roadmap_dir.rglob("task_*.md")):
        rule_name = path.stem.replace("task_", "", 1)
        if rule_name in implemented:
            stale.append((rule_name, path))
    return stale


def remove_stale_roadmap_tasks(
    project_dir: Path,
    *,
    dry_run: bool = False,
) -> list[str]:
    """Remove task files in bugs/roadmap whose rule is already in tiers.dart.

    Returns:
        List of rule names whose task file was removed (or would be removed if dry_run).
    """
    stale = get_stale_roadmap_tasks(project_dir)
    removed: list[str] = []
    for rule_name, path in stale:
        removed.append(rule_name)
        if not dry_run:
            path.unlink()
    return removed


def check_and_fix_roadmap_implemented(
    project_dir: Path,
    *,
    fix: bool = True,
) -> tuple[list[str], bool]:
    """Check for stale roadmap task files and optionally remove them.

    Args:
        project_dir: Project root.
        fix: If True, delete stale task files; if False, only report.

    Returns:
        (list of rule names that were or would be removed, True if any existed).
    """
    stale = get_stale_roadmap_tasks(project_dir)
    if not stale:
        return [], False
    rule_names = [r for r, _ in stale]
    if fix:
        for _, path in stale:
            path.unlink()
    return rule_names, True
