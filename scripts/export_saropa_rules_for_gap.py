#!/usr/bin/env python3
"""
Export saropa_lints rule names and categories to JSON for gap analysis.

Usage (from repo root):
  python scripts/export_saropa_rules_for_gap.py
  python scripts/export_saropa_rules_for_gap.py -o saropa_rules.json

Reads lib/src/rules via scripts.modules._rule_metrics and outputs a JSON array
of {"name": "rule_name", "category": "category"} for comparison with external
Dart rules. See bugs/discussion/GAP_ANALYSIS_EXTERNAL_DART.md.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as `python scripts/export_saropa_rules_for_gap.py` from project root
_project_root = Path(__file__).resolve().parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

from scripts.modules._rule_metrics import _collect_category_rules


def collect_rules(project_root: Path) -> list[dict]:
    """Return list of {"name": str, "category": str} from lib/src/rules.

    Reuses _rule_metrics._collect_category_rules for single source of truth
    (regex and file iteration). Deduplicates by rule name (first category wins).
    """
    rules_dir = project_root / "lib" / "src" / "rules"
    if not rules_dir.exists():
        return []

    category_infos = _collect_category_rules(rules_dir)
    out: list[dict] = []
    seen: set[str] = set()

    for cat_info in category_infos:
        for name in cat_info.rule_names:
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            out.append({"name": key, "category": cat_info.category})

    return sorted(out, key=lambda r: r["name"])


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export saropa_lints rules for gap analysis (JSON)."
    )
    parser.add_argument(
        "-o",
        "--output",
        default="saropa_rules.json",
        help="Output JSON file path (default: saropa_rules.json)",
    )
    parser.add_argument(
        "--project-dir",
        type=Path,
        default=_project_root,
        help="Project root (default: repo root)",
    )
    args = parser.parse_args()
    project_root = Path(args.project_dir)
    rules = collect_rules(project_root)
    out_path = Path(args.output)
    out_path.write_text(json.dumps(rules, indent=2), encoding="utf-8")
    print(f"Exported {len(rules)} rules to {out_path}")


if __name__ == "__main__":
    main()
