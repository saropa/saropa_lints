"""
Lint rule counting, test coverage metrics, and README badge sync.

Provides rule/category/fixture counts, a visual coverage report,
and automatic README.md badge synchronisation used by the publish
workflow.

Version:   2.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_success,
    print_warning,
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


# =============================================================================
# README BADGE SYNC
# =============================================================================

_VERSION_BADGE_RE = re.compile(r"(badge/pub-)[^-]+(-blue)")
_RULES_BADGE_RE = re.compile(r"(badge/rules-)(\d+)(%2B)")
_TIER_ESSENTIAL_RE = re.compile(r"(`essential`: ~)\d+")
_TIER_RECOMMENDED_RE = re.compile(r"(`recommended`: ~)\d+")
_TIER_PROFESSIONAL_RE = re.compile(r"(`professional`: ~)\d+")
_TIER_COMP_INSANITY_RE = re.compile(r"(`comprehensive`/`insanity`: )\d+\+")


def _round_tier_count(count: int) -> int:
    """Round a cumulative tier count for display with ``~`` prefix.

    Provides stable display values that don't change on every publish.
    Counts >= 1000 round to nearest 100; smaller counts round to
    nearest 50.

    Examples::

        _round_tier_count(263)  → 250
        _round_tier_count(797)  → 800
        _round_tier_count(1423) → 1400
    """
    if count >= 1000:
        return round(count / 100) * 100
    return round(count / 50) * 50


def sync_readme_badges(
    project_dir: Path,
    version: str,
    rule_count: int,
) -> bool:
    """Sync version, total rule count, and tier counts in README.md.

    Updates:
    - Version badge (``pub-X.Y.Z-blue``)
    - Rules badge (``rules-NNNN%2B``)
    - Prose references to total rule count (``NNNN+``)
    - Per-tier cumulative counts (``~NNN`` and ``NNN+``)

    Returns:
        True always (warnings logged if README missing).
    """
    readme_path = project_dir / "README.md"
    if not readme_path.exists():
        print_warning("README.md not found, skipping badge sync")
        return True

    content = readme_path.read_text(encoding="utf-8")
    original = content

    # --- Extract old total from rules badge ---
    old_match = _RULES_BADGE_RE.search(content)
    old_count = int(old_match.group(2)) if old_match else None

    # --- Version badge ---
    content = _VERSION_BADGE_RE.sub(rf"\g<1>{version}\g<2>", content)

    # --- Rules badge ---
    content = _RULES_BADGE_RE.sub(
        rf"\g<1>{rule_count}\g<3>", content
    )

    # --- Prose total count (e.g. "1677+" → "1682+") ---
    # Safe as global replace: badge URLs use %2B (not +), and tier
    # counts are different numbers corrected by _sync_tier_counts below.
    if old_count is not None and old_count != rule_count:
        content = content.replace(f"{old_count}+", f"{rule_count}+")

    # --- Per-tier cumulative counts ---
    content = _sync_tier_counts(project_dir, content)

    if content == original:
        print_success("README badges already up to date")
        return True

    readme_path.write_text(content, encoding="utf-8")
    print_success(
        f"Synced README badges (v{version}, {rule_count}+ rules)"
    )
    return True


def _sync_tier_counts(project_dir: Path, content: str) -> str:
    """Replace per-tier cumulative counts in *content*."""
    from scripts.modules._audit_checks import get_tier_stats

    tiers_path = project_dir / "lib" / "src" / "tiers.dart"
    if not tiers_path.exists():
        print_warning("tiers.dart not found, skipping tier sync")
        return content

    stats = get_tier_stats(tiers_path)

    # Cumulative counts (tiers are exclusive; sum them up)
    essential = stats.counts.get("essential", 0)
    recommended = essential + stats.counts.get("recommended", 0)
    professional = recommended + stats.counts.get("professional", 0)
    comprehensive = professional + stats.counts.get("comprehensive", 0)
    insanity = comprehensive + stats.counts.get("insanity", 0)

    content = _TIER_ESSENTIAL_RE.sub(
        rf"\g<1>{_round_tier_count(essential)}", content
    )
    content = _TIER_RECOMMENDED_RE.sub(
        rf"\g<1>{_round_tier_count(recommended)}", content
    )
    content = _TIER_PROFESSIONAL_RE.sub(
        rf"\g<1>{_round_tier_count(professional)}", content
    )
    content = _TIER_COMP_INSANITY_RE.sub(
        rf"\g<1>{insanity}+", content
    )

    return content
