"""
Lint rule counting, test coverage metrics, roadmap summary, and README badge sync.

Provides rule/category/fixture counts, a visual coverage report,
roadmap remaining items summary, and automatic README.md badge
synchronisation used by the publish workflow.

Version:   2.1
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from pathlib import Path

from collections import defaultdict
from dataclasses import dataclass, field
from typing import NamedTuple

from scripts.modules._utils import (
    Color,
    print_colored,
    print_header,
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
    for dart_file in rules_dir.glob("**/*.dart"):
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
        for f in rules_dir.glob("**/*_rules.dart")
        if f.name != "all_rules.dart"
    )


# Bar chart characters (used by multiple displays)
_BAR_FILLED = "█"
_BAR_EMPTY = "░"
_BAR_WIDTH = 20


def _make_bar(value: int, max_value: int, width: int = _BAR_WIDTH) -> str:
    """Create a proportional bar chart string."""
    if max_value <= 0:
        return _BAR_EMPTY * width
    filled = int((value / max_value) * width)
    filled = min(filled, width)
    return _BAR_FILLED * filled + _BAR_EMPTY * (width - filled)


def _make_progress_bar(
    done: int, total: int, width: int = _BAR_WIDTH
) -> str:
    """Create a progress bar showing done/total as filled/empty."""
    if total <= 0:
        return _BAR_EMPTY * width
    filled = int((done / total) * width)
    filled = min(filled, width)
    return _BAR_FILLED * filled + _BAR_EMPTY * (width - filled)


def display_test_coverage(project_dir: Path) -> None:
    """Display test coverage report with bar chart visualization."""
    rules_dir = project_dir / "lib" / "src" / "rules"
    example_dir = project_dir / "example" / "lib"
    if not rules_dir.exists():
        return

    category_details: list[tuple[str, int, int]] = []
    for dart_file in sorted(rules_dir.glob("**/*_rules.dart")):
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

    # Determine status color
    if coverage_pct < 10:
        status_color, status = Color.RED, "CRITICAL"
    elif coverage_pct < 30:
        status_color, status = Color.YELLOW, "LOW"
    elif coverage_pct < 70:
        status_color, status = Color.CYAN, "MODERATE"
    else:
        status_color, status = Color.GREEN, "GOOD"

    print()
    print_colored("  ▶ Test Coverage", Color.WHITE)
    print()

    # Overall bar
    bar = _make_progress_bar(total_fixtures, total_rules)
    print_colored(
        f"    Overall      {bar}  {total_fixtures:>4d}/{total_rules:<4d} "
        f"({coverage_pct:5.1f}%) {status}",
        status_color,
    )

    # Top 5 worst offenders
    ranked = sorted(
        category_details,
        key=lambda c: c[1] - c[2],
        reverse=True,
    )[:5]

    if ranked and ranked[0][1] - ranked[0][2] > 0:
        print()
        print_colored("    Lowest coverage:", Color.WHITE)
        max_rules = max(c[1] for c in ranked)
        for category, rules, fixtures in ranked:
            untested = rules - fixtures
            if untested <= 0:
                break
            pct = (fixtures / rules * 100) if rules > 0 else 0
            bar = _make_progress_bar(fixtures, rules)
            if pct < 10:
                row_color = Color.RED
            elif pct < 30:
                row_color = Color.YELLOW
            else:
                row_color = Color.CYAN
            print_colored(
                f"    {category:<14s} {bar}  {fixtures:>3d}/{rules:<3d} "
                f"({pct:5.1f}%)",
                row_color,
            )
    print()


# =============================================================================
# ROADMAP SUMMARY
# =============================================================================


# Severity emoji labels and ASCII fallbacks
_SEVERITY_LABELS = {
    "🚨": ("ERROR", "[!]"),
    "⚠️": ("WARNING", "[W]"),
    "ℹ️": ("INFO", "[i]"),
}


@dataclass
class RoadmapSummary:
    """Summary of rules remaining to implement from roadmaps."""

    roadmap_total: int = 0
    deferred_total: int = 0
    roadmap_by_severity: dict[str, int] = field(default_factory=dict)
    deferred_by_severity: dict[str, int] = field(default_factory=dict)

    @property
    def grand_total(self) -> int:
        """Total remaining rules across both roadmaps."""
        return self.roadmap_total + self.deferred_total


# Patterns for parsing roadmap markdown
# Match rule name in backticks, capture the actual rule name
_TABLE_RULE_RE = re.compile(
    r"^\|\s*([^\|]*)`([a-z_]+)`[^\|]*\|",  # Prefix (emojis) + rule name
    re.MULTILINE,
)


def _count_roadmap_rules_by_severity(
    file_path: Path,
) -> tuple[int, dict[str, int]]:
    """Count unique rules in a roadmap file by severity emoji.

    Deduplicates rules that appear multiple times (e.g., with and without
    GitHub issue links) by tracking rule names globally.

    Returns:
        Tuple of (total_count, dict mapping severity emoji to count).
    """
    if not file_path.exists():
        return 0, {}

    content = file_path.read_text(encoding="utf-8")
    lines = content.split("\n")

    # Track unique rule names to avoid double-counting
    seen_rules: set[str] = set()
    severity_counts: dict[str, int] = {"🚨": 0, "⚠️": 0, "ℹ️": 0}

    for line in lines:
        # Check for table row with rule
        if not line.startswith("|") or "`" not in line:
            continue
        # Skip header rows
        if "Rule Name" in line or ("Rule" in line and "Tier" in line):
            continue
        # Skip separator rows
        if "---" in line:
            continue

        # Extract rule name and prefix (which contains severity emoji)
        rule_match = _TABLE_RULE_RE.match(line)
        if rule_match:
            prefix = rule_match.group(1)
            rule_name = rule_match.group(2)

            # Skip if already seen
            if rule_name in seen_rules:
                continue
            seen_rules.add(rule_name)

            # Determine severity from emoji in prefix
            if "🚨" in prefix:
                severity_counts["🚨"] += 1
            elif "⚠️" in prefix:
                severity_counts["⚠️"] += 1
            else:
                # Default to INFO for rules without explicit severity
                severity_counts["ℹ️"] += 1

    total = sum(severity_counts.values())
    return total, severity_counts


def get_roadmap_summary(project_dir: Path) -> RoadmapSummary:
    """Parse ROADMAP.md and ROADMAP_DEFERRED.md to get remaining work summary.

    Returns:
        RoadmapSummary with counts by severity.
    """
    roadmap_path = project_dir / "ROADMAP.md"
    deferred_path = project_dir / "ROADMAP_DEFERRED.md"

    # Count rules by severity in each file
    roadmap_total, roadmap_sev = _count_roadmap_rules_by_severity(roadmap_path)
    deferred_total, deferred_sev = _count_roadmap_rules_by_severity(
        deferred_path
    )

    return RoadmapSummary(
        roadmap_total=roadmap_total,
        deferred_total=deferred_total,
        roadmap_by_severity=roadmap_sev,
        deferred_by_severity=deferred_sev,
    )


def _format_severity_row(
    emoji: str, count: int, total: int, max_count: int
) -> str:
    """Format a severity row with label, bar chart, and stats."""
    label, ascii_fallback = _SEVERITY_LABELS.get(emoji, ("OTHER", "[?]"))
    pct = (count / total * 100) if total > 0 else 0
    bar = _make_bar(count, max_count)
    return f"    {label:<12s} {bar}  {count:>4d} ({pct:5.1f}%)"


def display_roadmap_summary(project_dir: Path) -> None:
    """Display a summary of rules remaining to implement."""
    summary = get_roadmap_summary(project_dir)

    print()
    print_header("ROADMAP SUMMARY")

    # Find max count for bar scaling
    roadmap_max = max(summary.roadmap_by_severity.values(), default=1)
    deferred_max = max(summary.deferred_by_severity.values(), default=1)

    # ROADMAP.md breakdown by severity
    print()
    print_colored(
        f"  ▶ ROADMAP.md ({summary.roadmap_total} implementable rules)",
        Color.WHITE,
    )
    print()
    for emoji in ["🚨", "⚠️", "ℹ️"]:
        count = summary.roadmap_by_severity.get(emoji, 0)
        row = _format_severity_row(emoji, count, summary.roadmap_total, roadmap_max)
        # Color by severity
        if emoji == "🚨":
            color = Color.RED
        elif emoji == "⚠️":
            color = Color.YELLOW
        else:
            color = Color.CYAN
        print_colored(row, color)

    # ROADMAP_DEFERRED.md breakdown by severity
    print()
    print_colored(
        f"  ▶ ROADMAP_DEFERRED.md ({summary.deferred_total} blocked rules)",
        Color.WHITE,
    )
    print()
    for emoji in ["🚨", "⚠️", "ℹ️"]:
        count = summary.deferred_by_severity.get(emoji, 0)
        row = _format_severity_row(
            emoji, count, summary.deferred_total, deferred_max
        )
        # Color by severity
        if emoji == "🚨":
            color = Color.RED
        elif emoji == "⚠️":
            color = Color.YELLOW
        else:
            color = Color.CYAN
        print_colored(row, color)

    # Summary totals
    print()
    print_colored(
        f"    Total remaining: {summary.grand_total} rules",
        Color.WHITE,
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
_TIER_COMP_PEDANTIC_RE = re.compile(r"(`comprehensive`/`pedantic`: )\d+\+")


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
    pedantic = comprehensive + stats.counts.get("pedantic", 0)

    content = _TIER_ESSENTIAL_RE.sub(
        rf"\g<1>{_round_tier_count(essential)}", content
    )
    content = _TIER_RECOMMENDED_RE.sub(
        rf"\g<1>{_round_tier_count(recommended)}", content
    )
    content = _TIER_PROFESSIONAL_RE.sub(
        rf"\g<1>{_round_tier_count(professional)}", content
    )
    content = _TIER_COMP_PEDANTIC_RE.sub(
        rf"\g<1>{pedantic}+", content
    )

    return content
