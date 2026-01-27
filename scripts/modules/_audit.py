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
    export_dx_report,
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
) -> Path:
    """Export a full audit report to timestamped markdown file."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = output_dir / f"{timestamp}_full_audit.md"
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
      1. Duplicate detection
      2. Rule inventory and underscore naming audit
      3. Tier distribution analysis
      4. Severity distribution
      5. OWASP security coverage
      6. Quality metrics (quick fixes, corrections, file health)
      7. Orphan rules analysis
      8. ROADMAP sync
      9. DX message audit (optional, skip with skip_dx=True)

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

    # ----- Duplicate detection -----
    duplicates = find_duplicate_rules(rules_dir)
    print_duplicate_report(duplicates)

    # ----- Rule inventory -----
    print_section("RULE INVENTORY")
    rules, aliases, quick_fixes = get_implemented_rules(rules_dir)
    implemented = rules | aliases
    roadmap = get_roadmap_rules(roadmap_path)
    file_stats = get_file_stats(rules_dir)
    with_corrections, without_corrections = get_rules_with_corrections(
        rules_dir
    )

    # Underscore naming audit
    rules_with_0 = [r for r in rules if r.count("_") == 0]
    rules_with_1 = [r for r in rules if r.count("_") == 1]

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

    print_subheader("Overview")
    print_stat("Implemented rules", len(rules), Color.GREEN)
    print_stat("Documented aliases", len(aliases), Color.CYAN)
    print_stat("Quick fixes", quick_fixes, Color.MAGENTA)
    print_stat("ROADMAP entries remaining", len(roadmap), Color.YELLOW)

    # ----- Distribution analysis -----
    print_section("DISTRIBUTION ANALYSIS")

    tier_stats: TierStats | None = None
    orphan_rules: set[str] = set()
    if tiers_path.exists():
        tier_stats = get_tier_stats(tiers_path)
        print_tier_stats(tier_stats)

        # Rules in tiers.dart but not implemented
        not_implemented = sorted(tier_stats.all_tier_rules - rules)
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

    severity_stats = get_severity_stats(rules_dir)
    print_severity_stats(severity_stats)

    # ----- Security & compliance -----
    print_section("SECURITY & COMPLIANCE")
    owasp_coverage = get_owasp_coverage(rules_dir)
    print_owasp_coverage(owasp_coverage)

    # ----- Quality metrics -----
    print_section("QUALITY METRICS")
    print_quality_metrics(file_stats, rules, quick_fixes, with_corrections)

    if tier_stats:
        print_subheader("Tier Assignment")
        orphan_rules = find_orphan_rules(rules, tier_stats)
        print_orphan_analysis(orphan_rules, tier_stats)

    print_file_health(file_stats)

    # ----- ROADMAP sync -----
    print_section("ROADMAP SYNC")
    roadmap_duplicates = implemented & roadmap

    # Exclude _test variant rules whose base rule is also implemented
    # (e.g. require_https_only_test is an intentional test-file variant of
    # require_https_only, documented in ROADMAP for discoverability).
    roadmap_duplicates = {
        r
        for r in roadmap_duplicates
        if not (r.endswith("_test") and r[: -len("_test")] in implemented)
    }

    if roadmap_duplicates:
        print_subheader(f"Duplicates Found ({len(roadmap_duplicates)})")
        print_warning(
            "These rules are already implemented but still in ROADMAP:"
        )
        print()
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

    # Near matches
    remaining = roadmap - roadmap_duplicates
    # Also exclude _test variant rules (handled by _test exclusion above)
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

    if near_matches:
        print_subheader(f"Near-Matches ({len(near_matches)})")
        print_warning("These may need aliases:")
        print()
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

    # ----- DX message audit -----
    dx_messages: list[RuleMessage] = []
    if not skip_dx:
        print_section("DX MESSAGE AUDIT")
        dx_messages = extract_rule_messages(rules_dir)
        print_dx_audit_report(dx_messages, show_all=show_dx_all)

        # Export reports
        reports_dir = project_dir / "reports"
        reports_dir.mkdir(exist_ok=True)

        dx_issues = [m for m in dx_messages if m.dx_issues]
        if dx_issues:
            report_path = export_dx_report(dx_messages, reports_dir)
            print()
            print_info(
                f"Report: {report_path.relative_to(project_dir)}"
            )

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
        )
        print_info(
            f"Full report: {full_report.relative_to(project_dir)}"
        )

    # ----- Summary -----
    print_header("SUMMARY")
    print_stat("Total rules", len(rules), Color.GREEN)
    print_stat(
        "ROADMAP remaining", len(remaining), Color.YELLOW
    )
    print_stat(
        "OWASP Mobile",
        f"{owasp_coverage.mobile_covered}/10",
        Color.GREEN if owasp_coverage.mobile_covered >= 8 else Color.YELLOW,
    )
    print_stat(
        "OWASP Web",
        f"{owasp_coverage.web_covered}/10",
        Color.GREEN if owasp_coverage.web_covered >= 8 else Color.YELLOW,
    )
    if len(rules) > 0:
        fix_pct = quick_fixes / len(rules) * 100
        print_stat(
            "Quick fix coverage",
            f"{quick_fixes}/{len(rules)} ({fix_pct:.0f}%)",
            Color.GREEN if fix_pct > 15 else Color.YELLOW,
        )

    if not skip_dx:
        dx_count = sum(
            1
            for m in dx_messages
            if m.impact in ("critical", "high") and m.dx_issues
        )
        dx_color = (
            Color.RED
            if dx_count > 50
            else Color.YELLOW
            if dx_count > 0
            else Color.GREEN
        )
        print_stat("DX issues", dx_count, dx_color)

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
