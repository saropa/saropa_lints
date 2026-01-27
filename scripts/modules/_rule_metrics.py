"""
Lint rule counting and test coverage metrics.

Provides rule/category/fixture counts and a visual coverage report
used by the publish workflow's summary output.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
)

_RULE_CLASS_RE = re.compile(
    r"class \w+ extends (?:SaropaLintRule|DartLintRule)"
)


def count_rules(project_dir: Path) -> int:
    """Count the number of lint rules defined in the project."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    if not rules_dir.exists():
        return 0

    count = 0
    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        count += len(_RULE_CLASS_RE.findall(content))
    return count


def count_categories(project_dir: Path) -> int:
    """Count the number of rule category files."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    if not rules_dir.exists():
        return 0
    return sum(
        1
        for f in rules_dir.glob("*_rules.dart")
        if f.name != "all_rules.dart"
    )


def display_test_coverage(project_dir: Path) -> None:
    """Display test coverage report with emphasis on low coverage."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    example_dir = project_dir / "example" / "lib"
    if not rules_dir.exists():
        return

    category_details: list[tuple[str, int, int]] = []
    for dart_file in sorted(rules_dir.glob("*_rules.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        category = dart_file.stem.replace("_rules", "")
        content = dart_file.read_text(encoding="utf-8")
        rule_count = len(_RULE_CLASS_RE.findall(content))

        fixture_count = 0
        for suffix in [category, f"{category}s"]:
            fixture_dir = example_dir / suffix
            if fixture_dir.exists():
                fixture_count = len(
                    list(fixture_dir.glob("*_fixture.dart"))
                )
                if fixture_count > 0:
                    break

        category_details.append((category, rule_count, fixture_count))

    total_rules = sum(c[1] for c in category_details)
    total_fixtures = sum(c[2] for c in category_details)
    coverage_pct = (
        (total_fixtures / total_rules * 100) if total_rules > 0 else 0
    )

    print()
    print_colored("  Test Coverage Report:", Color.WHITE)
    print_colored("  " + "-" * 50, Color.CYAN)

    if coverage_pct < 10:
        color, status = Color.RED, "CRITICAL"
    elif coverage_pct < 30:
        color, status = Color.YELLOW, "LOW"
    elif coverage_pct < 70:
        color, status = Color.CYAN, "MODERATE"
    else:
        color, status = Color.GREEN, "GOOD"

    print_colored(
        f"      Overall: {total_fixtures}/{total_rules} "
        f"({coverage_pct:.1f}%) - {status}",
        color,
    )
    print_colored("  " + "-" * 50, Color.CYAN)

    # Top 10 worst offenders ranked by untested rule count
    ranked = sorted(
        category_details,
        key=lambda c: c[1] - c[2],
        reverse=True,
    )[:10]

    if ranked and ranked[0][1] - ranked[0][2] > 0:
        print()
        print_colored("  Top offenders (by untested rules):", Color.WHITE)
        print()
        for category, rules, fixtures in ranked:
            untested = rules - fixtures
            if untested <= 0:
                break
            pct = (fixtures / rules * 100) if rules > 0 else 0
            if pct < 10:
                row_color = Color.RED
            elif pct < 30:
                row_color = Color.YELLOW
            else:
                row_color = Color.CYAN
            print_colored(
                f"      {category:<30s} "
                f"{untested:>4d} untested / {rules:>4d} "
                f"({pct:5.1f}% covered)",
                row_color,
            )
        print()
