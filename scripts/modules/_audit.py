"""Comprehensive rule audit for saropa_lints.

Provides the main ``run_full_audit()`` entry point and ``AuditResult``
dataclass. Delegates to ``_audit_checks`` for extraction/display and
``_audit_dx`` for DX message quality analysis.

The ``AuditResult.has_blocking_issues`` property is inspected by the
publish workflow to decide whether to proceed.

Version:   3.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from scripts.modules._audit_checks import (
    FileStats,
    OwaspCoverage,
    SeverityStats,
    TierStats,
    SEVERITIES,
    TIERS,
    find_duplicate_rules,
    find_orphan_rules,
    get_file_stats,
    get_implemented_rules,
    get_owasp_coverage,
    get_roadmap_rules,
    get_rules_with_corrections,
    get_severity_stats,
    get_tier_stats,
    print_duplicate_report,
    print_file_health,
    print_owasp_coverage,
    print_orphan_analysis,
    print_quality_metrics,
    print_severity_stats,
    print_tier_stats,
)
from scripts.modules._audit_dx import (
    RuleMessage,
    extract_rule_messages,
    print_dx_audit_report,
)
from scripts.modules._utils import (
    Color,
    get_project_dir,
    print_error,
    print_header,
    print_info,
    print_section,
    print_stat,
    print_subheader,
    print_success,
    print_warning,
)


# =============================================================================
# AUDIT RESULT
# =============================================================================


@dataclass
class AuditResult:
    """Complete audit results for programmatic consumption.

    Returned by ``run_full_audit()``. The publish workflow inspects
    ``has_blocking_issues`` to decide whether to proceed.
    """

    rules: set[str]
    aliases: set[str]
    quick_fixes: int
    file_stats: list[FileStats]
    tier_stats: TierStats | None
    severity_stats: SeverityStats
    owasp_coverage: OwaspCoverage
    orphan_rules: set[str]
    duplicate_report: dict
    dx_messages: list[RuleMessage]
    with_corrections: set[str]
    without_corrections: set[str]
    roadmap_duplicates: set[str] = field(default_factory=set)

    @property
    def has_blocking_issues(self) -> bool:
        """True if any blocking issues were found (duplicates)."""
        return bool(
            self.duplicate_report.get("class_names")
            or self.duplicate_report.get("rule_names")
            or self.duplicate_report.get("aliases")
        )


# =============================================================================
# REPORT EXPORT
# =============================================================================


def export_full_audit_report(
    file_stats: list[FileStats],
    rules: set[str],
    aliases: set[str],
    quick_fixes: int,
    with_corrections: set[str],
    without_corrections: set[str],
    tier_stats: TierStats | None,
    orphan_rules: set[str],
    severity_stats: SeverityStats,
    owasp_coverage: OwaspCoverage,
    dx_messages: list[RuleMessage],
    output_dir: Path,
    project_name: str = "",
) -> Path:
    """Export a full audit report to timestamped markdown file."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    name_part = f"_{project_name}" if project_name else ""
    output_path = output_dir / f"{timestamp}{name_part}_full_audit.md"
    lines: list[str] = []
    lines.append("# Saropa Lints Full Audit Report\n")
    lines.append(
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    )
    lines.append("## Rule Inventory\n")
    lines.append(f"- Implemented rules: {len(rules)}\n")
    lines.append(f"- Documented aliases: {len(aliases)}\n")
    lines.append(f"- Quick fixes: {quick_fixes}\n")
    lines.append(
        f"- Rules with correction messages: {len(with_corrections)}\n"
    )
    lines.append(
        f"- Rules without correction messages: {len(without_corrections)}\n"
    )
    lines.append("")
    lines.append("### Rule Files\n")
    for s in file_stats:
        lines.append(
            f"- {s.name}: {s.rules} rules, {s.fixes} fixes, {s.lines} lines"
        )
    lines.append("")

    if tier_stats:
        lines.append("## Tier Assignment\n")
        for tier in TIERS:
            rules_in_tier = tier_stats.rules[tier]
            lines.append(
                f"### {tier.capitalize()} ({len(rules_in_tier)})\n"
            )
            for rule in sorted(rules_in_tier):
                lines.append(f"- {rule}")
            lines.append("")
        lines.append(f"### Unassigned ({len(orphan_rules)})\n")
        for rule in sorted(orphan_rules):
            lines.append(f"- {rule}")
        lines.append("")

    lines.append("## Severity Distribution\n")
    for severity in SEVERITIES:
        lines.append(
            f"- {severity.capitalize()}: {severity_stats.counts[severity]}"
        )
    lines.append("")

    lines.append("## OWASP Coverage\n")
    lines.append(
        f"Mobile categories covered: "
        f"{owasp_coverage.mobile_covered}/10\n"
    )
    lines.append(
        f"Web categories covered: {owasp_coverage.web_covered}/10\n"
    )
    lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


# =============================================================================
# MAIN AUDIT ORCHESTRATOR
# =============================================================================


def run_full_audit(
    project_dir: Path | None = None,
    show_dx_all: bool = False,
    skip_dx: bool = False,
    compact: bool = False,
) -> AuditResult:
    """Run all audit checks and return structured results.

    This is the main entry point for the audit module. It runs:
      1. Distribution analysis (tiers, severity)
      2. Security & compliance (OWASP coverage)
      3. Quality metrics (quick fixes, corrections, file health)
      4. Quality checks (duplicates, naming, tier assignment, ROADMAP, DX)

    Args:
        project_dir: Project root. Defaults to auto-detected.
        show_dx_all: Show all DX issues (not just top 25).
        skip_dx: Skip the DX message audit entirely.
        compact: Compact output (skip file table).

    Returns:
        AuditResult with all collected data and blocking status.
    """
    if project_dir is None:
        project_dir = get_project_dir()

    rules_dir = project_dir / "lib" / "src" / "rules"
    tiers_path = project_dir / "lib" / "src" / "tiers.dart"
    roadmap_path = project_dir / "ROADMAP.md"
    pubspec_path = project_dir / "pubspec.yaml"

    # Read project name for report filenames
    project_name = ""
    if pubspec_path.exists():
        content = pubspec_path.read_text(encoding="utf-8")
        match = re.search(r"^name:\s*(.+)$", content, re.MULTILINE)
        if match:
            project_name = match.group(1).strip()

    # ===== GATHER DATA (no printing) =====
    rules, aliases, quick_fixes = get_implemented_rules(rules_dir)
    implemented = rules | aliases
    roadmap = get_roadmap_rules(roadmap_path)
    file_stats = get_file_stats(rules_dir)
    with_corrections, without_corrections = get_rules_with_corrections(
        rules_dir
    )
    duplicates = find_duplicate_rules(rules_dir)
    severity_stats = get_severity_stats(rules_dir)
    owasp_coverage = get_owasp_coverage(rules_dir)

    tier_stats: TierStats | None = None
    orphan_rules: set[str] = set()
    not_implemented: list[str] = []
    if tiers_path.exists():
        tier_stats = get_tier_stats(tiers_path)
        not_implemented = sorted(tier_stats.all_tier_rules - rules)
        orphan_rules = find_orphan_rules(rules, tier_stats)

    # Underscore naming data
    rules_with_0 = [r for r in rules if r.count("_") == 0]
    rules_with_1 = [r for r in rules if r.count("_") == 1]

    # ROADMAP sync data
    roadmap_duplicates = implemented & roadmap
    roadmap_duplicates = {
        r
        for r in roadmap_duplicates
        if not (r.endswith("_test") and r[: -len("_test")] in implemented)
    }
    remaining = roadmap - roadmap_duplicates
    remaining = {
        r
        for r in remaining
        if not (r.endswith("_test") and r[: -len("_test")] in implemented)
    }
    near_matches: list[tuple[str, str]] = []
    for roadmap_rule in sorted(remaining):
        for impl_rule in implemented:
            if (
                roadmap_rule.replace("_", "") == impl_rule.replace("_", "")
                or roadmap_rule + "s" == impl_rule
                or roadmap_rule == impl_rule + "s"
            ):
                near_matches.append((roadmap_rule, impl_rule))
                break

    # DX message data
    dx_messages: list[RuleMessage] = []
    if not skip_dx:
        dx_messages = extract_rule_messages(rules_dir)

    # ===== INFO SECTIONS (first) =====

    # ----- Distribution analysis -----
    print_section("DISTRIBUTION ANALYSIS")
    if tier_stats:
        print_tier_stats(tier_stats)
    print_severity_stats(severity_stats)

    # ----- Security & compliance -----
    print_section("SECURITY & COMPLIANCE")
    print_owasp_coverage(owasp_coverage)

    # ----- Quality metrics -----
    print_section("QUALITY METRICS")
    print_quality_metrics(file_stats, rules, quick_fixes, with_corrections)
    print_file_health(file_stats)

    # ===== QUALITY CHECKS (second) =====
    print_section("QUALITY CHECKS")

    # Duplicate detection (print_duplicate_report uses subheader internally)
    print_duplicate_report(duplicates)

    # Underscore naming audit
    print_subheader("Underscore Naming Audit")
    if not rules_with_1 and not rules_with_0:
        print_success("All rules have at least 2 underscores.")
    else:
        if rules_with_0:
            print_error(
                f"{len(rules_with_0)} rule(s) have ZERO underscores:"
            )
            for rule in rules_with_0:
                print(f"      {Color.RED.value}{rule}{Color.RESET.value}")
        if rules_with_1:
            print_warning(
                f"{len(rules_with_1)} rule(s) have only 1 underscore:"
            )
            for rule in rules_with_1:
                print(f"      {Color.YELLOW.value}{rule}{Color.RESET.value}")

    # Tier assignment check
    if tier_stats:
        print_subheader("Tier Assignment")
        print_orphan_analysis(orphan_rules, tier_stats)

        print_subheader("Rules in tiers.dart NOT implemented")
        if not_implemented:
            alias_covered = [r for r in not_implemented if r in aliases]
            truly_missing = [r for r in not_implemented if r not in aliases]
            print_warning(
                f"{len(not_implemented)} rules in tiers.dart not implemented:"
            )
            if alias_covered:
                print_info(
                    f"Aliases covering missing tiered rules "
                    f"({len(alias_covered)}):"
                )
                for rule in alias_covered:
                    print(
                        f"      {Color.CYAN.value}{rule}{Color.RESET.value}"
                        f" (alias)"
                    )
            if truly_missing:
                print_error(
                    f"Truly missing rules ({len(truly_missing)}):"
                )
                for rule in truly_missing:
                    print(
                        f"      {Color.RED.value}{rule}{Color.RESET.value}"
                    )
            if not truly_missing:
                print_success(
                    "All missing tiered rules are covered by aliases."
                )
        else:
            print_success("All rules in tiers.dart are implemented.")

    # ROADMAP sync
    print_subheader("ROADMAP Sync")
    if roadmap_duplicates:
        print_warning(
            f"{len(roadmap_duplicates)} rule(s) implemented but still in ROADMAP:"
        )
        for rule in sorted(roadmap_duplicates)[:10]:
            source = "alias" if rule in aliases else "rule"
            color = Color.CYAN if source == "alias" else Color.GREEN
            print(
                f"      {color.value}{rule}{Color.RESET.value} "
                f"{Color.DIM.value}({source}){Color.RESET.value}"
            )
        if len(roadmap_duplicates) > 10:
            print(
                f"      {Color.DIM.value}"
                f"... and {len(roadmap_duplicates) - 10} more"
                f"{Color.RESET.value}"
            )
    else:
        print_success("ROADMAP is clean - no duplicates")

    if near_matches:
        print_warning(f"{len(near_matches)} near-match(es) may need aliases:")
        for roadmap_rule, impl_rule in near_matches[:5]:
            print(
                f"      {Color.YELLOW.value}{roadmap_rule}{Color.RESET.value}"
                f" → {Color.GREEN.value}{impl_rule}{Color.RESET.value}"
            )
        if len(near_matches) > 5:
            print(
                f"      {Color.DIM.value}"
                f"... and {len(near_matches) - 5} more"
                f"{Color.RESET.value}"
            )

    # DX message audit
    if not skip_dx:
        print_dx_audit_report(
            dx_messages,
            show_all=show_dx_all,
            tier_rules=tier_stats.rules if tier_stats else None,
        )

        # Export full audit report
        reports_dir = project_dir / "reports"
        reports_dir.mkdir(exist_ok=True)

        full_report = export_full_audit_report(
            file_stats,
            rules,
            aliases,
            quick_fixes,
            with_corrections,
            without_corrections,
            tier_stats,
            orphan_rules,
            severity_stats,
            owasp_coverage,
            dx_messages,
            reports_dir,
            project_name=project_name,
        )
        print()
        print_info(
            f"Report: {full_report.relative_to(project_dir)}"
        )

    # ===== OVERVIEW (at end for terminal readability) =====
    print_subheader("Overview")
    print_stat("Implemented rules", len(rules), Color.GREEN)
    print_stat("Documented aliases", len(aliases), Color.CYAN)
    print_stat("Quick fixes", quick_fixes, Color.MAGENTA)
    print_stat("ROADMAP entries remaining", len(roadmap), Color.YELLOW)

    print()

    return AuditResult(
        rules=rules,
        aliases=aliases,
        quick_fixes=quick_fixes,
        file_stats=file_stats,
        tier_stats=tier_stats,
        severity_stats=severity_stats,
        owasp_coverage=owasp_coverage,
        orphan_rules=orphan_rules,
        duplicate_report=duplicates,
        dx_messages=dx_messages,
        with_corrections=with_corrections,
        without_corrections=without_corrections,
        roadmap_duplicates=roadmap_duplicates,
    )
