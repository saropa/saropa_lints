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
    get_rules_missing_prefix,
    get_rules_with_corrections,
    get_severity_stats,
    get_tier_stats,
    print_file_health,
    print_owasp_coverage,
    print_quality_metrics,
    print_severity_stats,
    print_tier_stats,
)
from scripts.modules._tier_integrity import (
    check_tier_integrity,
    get_tier_integrity_checks,
)
from scripts.modules._audit_dx import (
    RuleMessage,
    extract_rule_messages,
    print_dx_audit_report,
)
from scripts.modules._utils import (
    Color,
    get_project_dir,
    print_colored,
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
    rules_missing_prefix: list[str] = field(default_factory=list)
    tier_integrity_passed: bool = True

    @property
    def has_blocking_issues(self) -> bool:
        """True if any blocking issues were found.

        Blocks publishing when:
        - Tier integrity checks failed
        - Duplicate class names, rule names, or aliases exist
        - Rules missing ``[rule_name]`` prefix in problemMessage
        """
        return bool(
            not self.tier_integrity_passed
            or self.duplicate_report.get("class_names")
            or self.duplicate_report.get("rule_names")
            or self.duplicate_report.get("aliases")
            or self.rules_missing_prefix
        )


# =============================================================================
# REPORT EXPORT — DX helpers
# =============================================================================


def _dx_impact_table(messages: list[RuleMessage]) -> list[str]:
    """Build DX summary-by-impact markdown table."""
    impacts = ["critical", "high", "medium", "low", "opinionated"]
    by_impact: dict[str, list[RuleMessage]] = {i: [] for i in impacts}
    for m in messages:
        if m.impact in by_impact:
            by_impact[m.impact].append(m)

    lines = [
        "### By Impact\n",
        "| Impact | Passing | Total | Rate |",
        "|--------|---------|-------|------|",
    ]
    for impact in impacts:
        total = len(by_impact[impact])
        failing = sum(1 for m in by_impact[impact] if m.dx_issues)
        passing = total - failing
        rate = (passing / total * 100) if total else 100
        lines.append(
            f"| {impact.capitalize()} | {passing} | {total} | {rate:.1f}% |"
        )
    lines.append("")
    return lines


def _dx_tier_table(
    messages: list[RuleMessage],
    tier_rules: dict[str, set[str]],
) -> list[str]:
    """Build DX summary-by-tier markdown table."""
    lines = [
        "### By Tier\n",
        "| Tier | Passing | Total | Rate |",
        "|------|---------|-------|------|",
    ]
    for tier in TIERS:
        tier_names = tier_rules.get(tier, set())
        tier_msgs = [m for m in messages if m.name in tier_names]
        total = len(tier_msgs)
        if total == 0:
            continue
        failing = sum(1 for m in tier_msgs if m.dx_issues)
        passing = total - failing
        rate = (passing / total * 100) if total else 100
        lines.append(
            f"| {tier.capitalize()} | {passing} | {total} | {rate:.1f}% |"
        )
    lines.append("")
    return lines


def _dx_issues_table(messages: list[RuleMessage]) -> list[str]:
    """Build DX issues-by-type markdown table."""
    issues_to_rules: dict[str, list[RuleMessage]] = {}
    for m in messages:
        if m.dx_issues:
            issues_to_rules.setdefault(m.dx_issues[0], []).append(m)

    if not issues_to_rules:
        return []

    sorted_issues = sorted(
        issues_to_rules.items(), key=lambda x: -len(x[1])
    )
    lines = [
        "### Issues by Type\n",
        "| Count | Issue | Example Rules |",
        "|-------|-------|---------------|",
    ]
    for issue, rules in sorted_issues:
        count = len(rules)
        examples = ", ".join(f"`{r.name}`" for r in rules[:3])
        if count > 3:
            examples += f", ... +{count - 3} more"
        lines.append(f"| {count} | {issue} | {examples} |")
    lines.append("")
    return lines


def _dx_failing_table(
    messages: list[RuleMessage],
    tier_rules: dict[str, set[str]],
) -> list[str]:
    """Build per-rule failing table sorted by tier then impact."""
    rule_to_tier: dict[str, str] = {}
    for tier, rules in tier_rules.items():
        for rule in rules:
            rule_to_tier[rule] = tier

    failing = [m for m in messages if m.dx_issues]
    if not failing:
        return []

    impact_order = {
        "critical": 0, "high": 1, "medium": 2,
        "low": 3, "opinionated": 4,
    }
    tier_order = {t: i for i, t in enumerate(TIERS)}
    failing.sort(key=lambda m: (
        tier_order.get(rule_to_tier.get(m.name, ""), 99),
        impact_order.get(m.impact, 99),
        m.dx_score,
    ))

    lines = [
        "### Failing Rules\n",
        "| Rule | Tier | Impact | Score | Issues |",
        "|------|------|--------|-------|--------|",
    ]
    for m in failing:
        tier = rule_to_tier.get(m.name, "unassigned")
        issues = "; ".join(m.dx_issues)
        lines.append(
            f"| `{m.name}` | {tier.capitalize()} "
            f"| {m.impact} | {m.dx_score} | {issues} |"
        )
    lines.append("")
    return lines


def _build_dx_section(
    dx_messages: list[RuleMessage],
    tier_stats: TierStats | None,
) -> list[str]:
    """Build complete DX Message Quality section for audit report."""
    if not dx_messages:
        return []

    total_failing = sum(1 for m in dx_messages if m.dx_issues)
    lines = ["## DX Message Quality\n"]
    lines.append(f"- **Total rules audited:** {len(dx_messages)}")
    lines.append(f"- **Rules with issues:** {total_failing}")
    lines.append(
        f"- **Rules passing:** {len(dx_messages) - total_failing}"
    )
    lines.append("")
    lines.extend(_dx_impact_table(dx_messages))
    tier_rules = tier_stats.rules if tier_stats else {}
    lines.extend(_dx_tier_table(dx_messages, tier_rules))
    lines.extend(_dx_issues_table(dx_messages))
    lines.extend(_dx_failing_table(dx_messages, tier_rules))
    return lines


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
    date_folder = timestamp[:8]
    dated_dir = output_dir / date_folder
    dated_dir.mkdir(parents=True, exist_ok=True)
    name_part = f"_{project_name}" if project_name else ""
    output_path = dated_dir / f"{timestamp}{name_part}_full_audit.md"
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

    lines.extend(_build_dx_section(dx_messages, tier_stats))

    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


# =============================================================================
# CONSOLIDATED QUALITY CHECKS
# =============================================================================

# Check status constants
_PASS = "pass"
_WARN = "warn"
_FAIL = "fail"

# Type alias: (status, message, detail_lines)
_Check = tuple[str, str, list[str]]


def _print_quality_checks(checks: list[_Check]) -> None:
    """Print consolidated quality check results as a flat list.

    Passes print first, then warnings, then failures.  Each
    warning/failure shows its detail lines indented below.
    """
    passed = [c for c in checks if c[0] == _PASS]
    warnings = [c for c in checks if c[0] == _WARN]
    failed = [c for c in checks if c[0] == _FAIL]

    for _, msg, _ in passed:
        print_success(msg)

    for _, msg, details in warnings:
        print_warning(msg)
        for line in details:
            print(f"      {Color.DIM.value}{line}{Color.RESET.value}")

    for _, msg, details in failed:
        print_error(msg)
        for line in details:
            print(f"      {Color.RED.value}{line}{Color.RESET.value}")

    n_pass, n_warn, n_fail = len(passed), len(warnings), len(failed)
    print()
    if n_fail == 0 and n_warn == 0:
        print_success(f"All {len(checks)} quality checks passed")
    else:
        parts = [f"{n_pass} passed"]
        if n_warn:
            parts.append(f"{n_warn} warning(s)")
        if n_fail:
            parts.append(f"{n_fail} failed")
        color = Color.RED if n_fail else Color.YELLOW
        print_colored(f"    {', '.join(parts)}", color)


# =============================================================================
# MAIN AUDIT ORCHESTRATOR
# =============================================================================


def run_full_audit(
    project_dir: Path | None = None,
    show_dx_all: bool = False,
    skip_dx: bool = False,
    compact: bool = False,
    extra_checks: list[_Check] | None = None,
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
    rules_missing_prefix = get_rules_missing_prefix(rules_dir)

    tier_stats: TierStats | None = None
    orphan_rules: set[str] = set()
    not_implemented: list[str] = []
    tier_checks: list[_Check] = []
    tier_integrity_passed = True
    if tiers_path.exists():
        tier_stats = get_tier_stats(tiers_path)
        not_implemented = sorted(tier_stats.all_tier_rules - rules)
        orphan_rules = find_orphan_rules(rules, tier_stats)
        tier_result = check_tier_integrity(rules_dir, tiers_path)
        tier_checks = get_tier_integrity_checks(tier_result)
        tier_integrity_passed = tier_result.passed

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

    # ===== AUDIT CHECKS (pass/fail — tier integrity + quality) =====

    checks: list[_Check] = list(tier_checks)

    # Duplicate detection
    dup_classes = duplicates.get("class_names", {})
    dup_rule_names = duplicates.get("rule_names", {})
    dup_aliases_found = duplicates.get("aliases", {})
    if dup_classes or dup_rule_names or dup_aliases_found:
        details: list[str] = []
        for kind, dups in [
            ("class", dup_classes),
            ("rule", dup_rule_names),
            ("alias", dup_aliases_found),
        ]:
            for name in sorted(dups)[:5]:
                details.append(f"{name} (duplicate {kind} name)")
        checks.append((
            _FAIL,
            "Duplicate rules, class names, or aliases found",
            details,
        ))
    else:
        checks.append((
            _PASS,
            "No duplicate class names, rule names, or aliases",
            [],
        ))

    # Problem message prefix (BLOCKING)
    if rules_missing_prefix:
        shown = sorted(rules_missing_prefix)[:10]
        detail_line = ", ".join(shown)
        if len(rules_missing_prefix) > 10:
            detail_line += f" +{len(rules_missing_prefix) - 10} more"
        checks.append((
            _FAIL,
            f"{len(rules_missing_prefix)} rule(s) missing "
            f"[rule_name] prefix in problemMessage",
            [detail_line],
        ))
    else:
        checks.append((
            _PASS,
            "All rules have [rule_name] prefix in problemMessage",
            [],
        ))

    # Underscore naming (informational — never blocks publish)
    if rules_with_0:
        checks.append((
            _WARN,
            f"{len(rules_with_0)} rule(s) with ZERO underscores",
            sorted(rules_with_0)[:5],
        ))
    elif rules_with_1:
        checks.append((
            _WARN,
            f"{len(rules_with_1)} rule(s) with only 1 underscore",
            sorted(rules_with_1)[:5],
        ))
    else:
        checks.append((_PASS, "All rules have at least 2 underscores", []))

    # Tier assignment (audit-level: orphans not in stylistic)
    if tier_stats:
        non_stylistic_orphans = [
            r for r in sorted(orphan_rules)
            if r not in tier_stats.stylistic_rules
        ]
        if non_stylistic_orphans:
            checks.append((
                _WARN,
                f"{len(non_stylistic_orphans)} rule(s) not in any tier",
                non_stylistic_orphans[:5],
            ))

        # Rules in tiers.dart not implemented
        if not_implemented:
            truly_missing = [
                r for r in not_implemented if r not in aliases
            ]
            alias_covered = [
                r for r in not_implemented if r in aliases
            ]
            if truly_missing:
                checks.append((
                    _FAIL,
                    f"{len(truly_missing)} tiered rule(s) not implemented",
                    truly_missing[:10],
                ))
            elif alias_covered:
                checks.append((
                    _PASS,
                    f"All tiered rules implemented "
                    f"({len(alias_covered)} via aliases)",
                    [],
                ))
            else:
                checks.append((
                    _PASS, "All tiered rules implemented", [],
                ))

    # ROADMAP sync
    if roadmap_duplicates:
        shown_rules = sorted(roadmap_duplicates)[:5]
        suffix = (
            f" +{len(roadmap_duplicates) - 5} more"
            if len(roadmap_duplicates) > 5 else ""
        )
        checks.append((
            _WARN,
            f"{len(roadmap_duplicates)} implemented rule(s) "
            f"still in ROADMAP",
            [", ".join(shown_rules) + suffix],
        ))
    else:
        checks.append((_PASS, "ROADMAP is clean — no duplicates", []))

    if near_matches:
        match_details = [
            f"{r} → {i}" for r, i in near_matches[:5]
        ]
        if len(near_matches) > 5:
            match_details.append(f"+{len(near_matches) - 5} more")
        checks.append((
            _WARN,
            f"{len(near_matches)} ROADMAP near-match(es) "
            f"may need aliases",
            match_details,
        ))

    # DX message quality
    if not skip_dx:
        dx_failing = sum(1 for m in dx_messages if m.dx_issues)
        if dx_failing:
            checks.append((
                _WARN,
                f"{dx_failing} DX message(s) have quality issues",
                [],
            ))
        else:
            checks.append((
                _PASS,
                "All DX messages meet quality thresholds",
                [],
            ))

    if extra_checks:
        checks.extend(extra_checks)

    _print_quality_checks(checks)

    # ===== METRICS (distribution + coverage + quality) =====
    print_section("METRICS")

    print_subheader("Distribution")
    if tier_stats:
        print_tier_stats(tier_stats, show_header=False)
    print_severity_stats(severity_stats, show_header=False)
    print_owasp_coverage(owasp_coverage, show_header=False)

    print_subheader("Quality")
    print_quality_metrics(
        file_stats, rules, quick_fixes, with_corrections,
        show_header=False,
    )
    print_file_health(file_stats, show_headers=False)

    # DX message detail
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

    # ===== OVERVIEW =====
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
        rules_missing_prefix=rules_missing_prefix,
        tier_integrity_passed=tier_integrity_passed,
    )
