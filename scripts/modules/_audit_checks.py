"""Extraction functions and display helpers for rule audit checks.

Provides data classes, duplicate detection, file statistics,
tier/severity distribution, OWASP coverage analysis, quality
metrics, and orphan-rule detection. Used by the audit orchestrator
in ``_audit.py``.

Version:   3.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import collections
import re
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_error,
    print_info,
    print_stat,
    print_stat_bar,
    print_subheader,
    print_success,
    print_warning,
)


# =============================================================================
# DATA CLASSES & CONSTANTS
# =============================================================================


class FileStats:
    """Statistics for a single rule file."""

    def __init__(
        self,
        path: Path,
        lines: int,
        rules: int,
        fixes: int,
        rule_names: list[str],
    ):
        self.path = path
        self.name = path.name
        self.lines = lines
        self.rules = rules
        self.fixes = fixes
        self.rule_names = rule_names

    @property
    def fix_coverage(self) -> float:
        """Percentage of rules with quick fixes."""
        return (self.fixes / self.rules * 100) if self.rules > 0 else 0


# OWASP Mobile Top 10 (2024) categories
OWASP_MOBILE = {
    "m1": "Improper Credential Usage",
    "m2": "Inadequate Supply Chain Security",
    "m3": "Insecure Authentication/Authorization",
    "m4": "Insufficient Input/Output Validation",
    "m5": "Insecure Communication",
    "m6": "Inadequate Privacy Controls",
    "m7": "Insufficient Binary Protections",
    "m8": "Security Misconfiguration",
    "m9": "Insecure Data Storage",
    "m10": "Insufficient Cryptography",
}

# OWASP Web Top 10 (2021) categories
OWASP_WEB = {
    "a01": "Broken Access Control",
    "a02": "Cryptographic Failures",
    "a03": "Injection",
    "a04": "Insecure Design",
    "a05": "Security Misconfiguration",
    "a06": "Vulnerable and Outdated Components",
    "a07": "Identification and Authentication Failures",
    "a08": "Software and Data Integrity Failures",
    "a09": "Security Logging and Monitoring Failures",
    "a10": "Server-Side Request Forgery (SSRF)",
}


class OwaspCoverage:
    """OWASP coverage statistics."""

    def __init__(self):
        self.mobile: dict[str, list[str]] = {k: [] for k in OWASP_MOBILE}
        self.web: dict[str, list[str]] = {k: [] for k in OWASP_WEB}

    @property
    def mobile_covered(self) -> int:
        return sum(1 for rules in self.mobile.values() if rules)

    @property
    def web_covered(self) -> int:
        return sum(1 for rules in self.web.values() if rules)

    @property
    def total_mobile_mappings(self) -> int:
        return sum(len(rules) for rules in self.mobile.values())

    @property
    def total_web_mappings(self) -> int:
        return sum(len(rules) for rules in self.web.values())


# Tier names in display order
TIERS = [
    "essential",
    "recommended",
    "professional",
    "comprehensive",
    "insanity",
    "stylistic",
]

# Severity levels
SEVERITIES = ["critical", "high", "medium", "low"]


class TierStats:
    """Statistics about rules per tier."""

    def __init__(self):
        self.counts: dict[str, int] = {tier: 0 for tier in TIERS}
        self.rules: dict[str, set[str]] = {tier: set() for tier in TIERS}
        self.stylistic_rules: set[str] = set()

    @property
    def total(self) -> int:
        return sum(self.counts.values())

    @property
    def all_tier_rules(self) -> set[str]:
        result: set[str] = set()
        for rules in self.rules.values():
            result.update(rules)
        return result


class SeverityStats:
    """Statistics about rules per severity level."""

    def __init__(self):
        self.counts: dict[str, int] = {sev: 0 for sev in SEVERITIES}

    @property
    def total(self) -> int:
        return sum(self.counts.values())


# =============================================================================
# EXTRACTION FUNCTIONS
# =============================================================================


# cspell:ignore dups
def find_duplicate_rules(rules_dir: Path) -> dict:
    """Find duplicate class names, rule names, and aliases across rule files.

    Returns dict with keys 'class_names', 'rule_names', 'aliases'.
    Each value is a dict of name -> list of {file, problem_len} entries,
    only for names appearing in multiple files.
    """
    class_names = collections.defaultdict(list)
    rule_names = collections.defaultdict(list)
    aliases = collections.defaultdict(list)

    class_pattern = re.compile(
        r"class\s+([A-Za-z0-9_]+)\s+extends\s+SaropaLintRule"
    )
    rule_name_pattern = re.compile(r"name:\s*'([a-z0-9_]+)'")
    alias_pattern = re.compile(r"///\s*Alias:\s*([a-zA-Z0-9_,\s]+)")
    lint_code_pattern = re.compile(
        r"name:\s*'([a-z0-9_]+)'.*?problemMessage:\s*(?:'([^']*)'|\"([^\"]*)\")",
        re.DOTALL,
    )

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")

        rule_problem_len = {}
        for match in lint_code_pattern.finditer(content):
            rule = match.group(1)
            msg = match.group(2) or match.group(3) or ""
            rule_problem_len[rule] = len(msg)

        for match in class_pattern.finditer(content):
            class_name = match.group(1)
            problem_len = (
                max(rule_problem_len.values()) if rule_problem_len else 0
            )
            class_names[class_name].append(
                {"file": str(dart_file), "problem_len": problem_len}
            )

        rule_names_in_file = set()
        for match in rule_name_pattern.finditer(content):
            rule_names_in_file.add(match.group(1))
        for rule_name in rule_names_in_file:
            problem_len = rule_problem_len.get(rule_name, 0)
            rule_names[rule_name].append(
                {"file": str(dart_file), "problem_len": problem_len}
            )

        aliases_in_file = set()
        for match in alias_pattern.finditer(content):
            alias_list = match.group(1)
            for alias in [
                a.strip() for a in alias_list.split(",") if a.strip()
            ]:
                aliases_in_file.add(alias)
        for alias in aliases_in_file:
            problem_len = (
                max(rule_problem_len.values()) if rule_problem_len else 0
            )
            aliases[alias].append(
                {"file": str(dart_file), "problem_len": problem_len}
            )

    return {
        "class_names": {
            k: v
            for k, v in class_names.items()
            if len(set(e["file"] for e in v)) > 1
        },
        "rule_names": {
            k: v
            for k, v in rule_names.items()
            if len(set(e["file"] for e in v)) > 1
        },
        "aliases": {
            k: v
            for k, v in aliases.items()
            if len(set(e["file"] for e in v)) > 1
        },
    }


def get_file_stats(rules_dir: Path) -> list[FileStats]:
    """Get per-file statistics for all rule files."""
    name_pattern = re.compile(r"name:\s*'([a-z0-9_]+)'")
    fix_pattern = re.compile(r"class \w+ extends DartFix")
    stats: list[FileStats] = []

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        lines = content.count("\n") + 1
        rule_names = name_pattern.findall(content)
        fixes = len(fix_pattern.findall(content))
        stats.append(
            FileStats(dart_file, lines, len(rule_names), fixes, rule_names)
        )

    return stats


def get_implemented_rules(
    rules_dir: Path,
) -> tuple[set[str], set[str], int]:
    """Extract rule names, aliases, and quick fix count.

    Returns:
        Tuple of (rule_names, aliases, quick_fix_count).
    """
    rules: set[str] = set()
    aliases: set[str] = set()
    fix_count = 0

    lintcode_pattern = re.compile(
        r"static const (?:LintCode )?_code\w* = LintCode\(\s*"
        r"name:\s*'([a-z0-9_]+)',",
        re.DOTALL,
    )
    alias_pattern = re.compile(
        r"^///\s*Alias:\s*([a-zA-Z0-9_,\s]+)", re.MULTILINE
    )
    fix_pattern = re.compile(r"class \w+ extends DartFix")

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        rules.update(lintcode_pattern.findall(content))
        fix_count += len(fix_pattern.findall(content))

        for match in alias_pattern.findall(content):
            for alias in match.split(","):
                alias = alias.strip()
                if alias:
                    aliases.add(alias)

    return rules, aliases, fix_count


def get_roadmap_rules(roadmap_path: Path) -> set[str]:
    """Extract rule names from ROADMAP.md table entries."""
    rules: set[str] = set()
    pattern = re.compile(r"^\|\s*`([a-z0-9_]+)`\s*\|", re.MULTILINE)
    content = roadmap_path.read_text(encoding="utf-8")
    rules.update(pattern.findall(content))
    return rules


def get_rules_with_corrections(
    rules_dir: Path,
) -> tuple[set[str], set[str]]:
    """Find rules with and without correction messages.

    Returns:
        Tuple of (rules_with_correction, rules_without_correction).
    """
    with_correction: set[str] = set()
    without_correction: set[str] = set()

    lint_code_with_correction = re.compile(
        r"name:\s*'([a-z0-9_]+)'.*?correctionMessage:", re.DOTALL
    )
    name_pattern = re.compile(r"name:\s*'([a-z0-9_]+)'")

    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        all_names = set(name_pattern.findall(content))
        names_with_correction = set()
        for match in lint_code_with_correction.finditer(content):
            names_with_correction.add(match.group(1))
        with_correction.update(names_with_correction)
        without_correction.update(all_names - names_with_correction)

    return with_correction, without_correction


def get_owasp_coverage(rules_dir: Path) -> OwaspCoverage:
    """Extract OWASP coverage from rule files."""
    coverage = OwaspCoverage()

    name_pattern = re.compile(r"name:\s*'([a-z0-9_]+)'")
    owasp_block_pattern = re.compile(
        r"OwaspMapping get owasp => const OwaspMapping\(\s*"
        r"mobile:\s*<OwaspMobile>\{([^}]*)\},?\s*"
        r"(?:web:\s*<OwaspWeb>\{([^}]*)\},?)?\s*\);",
        re.DOTALL,
    )
    owasp_block_alt = re.compile(
        r"OwaspMapping get owasp => const OwaspMapping\(\s*"
        r"web:\s*<OwaspWeb>\{([^}]*)\},?\s*"
        r"(?:mobile:\s*<OwaspMobile>\{([^}]*)\},?)?\s*\);",
        re.DOTALL,
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")

        class_pattern = re.compile(
            r"class\s+(\w+)\s+extends\s+SaropaLintRule[^{]*\{",
            re.DOTALL,
        )

        for class_match in class_pattern.finditer(content):
            class_start = class_match.start()
            next_class = class_pattern.search(content, class_match.end())
            class_end = next_class.start() if next_class else len(content)
            class_content = content[class_start:class_end]

            name_match = name_pattern.search(class_content)
            if not name_match:
                continue
            rule_name = name_match.group(1)

            owasp_match = owasp_block_pattern.search(class_content)
            if owasp_match:
                mobile_cats = owasp_match.group(1) or ""
                web_cats = owasp_match.group(2) or ""
            else:
                owasp_match = owasp_block_alt.search(class_content)
                if owasp_match:
                    web_cats = owasp_match.group(1) or ""
                    mobile_cats = owasp_match.group(2) or ""
                else:
                    continue

            for m in re.finditer(r"OwaspMobile\.(\w+)", mobile_cats):
                cat = m.group(1).lower()
                if cat in coverage.mobile:
                    coverage.mobile[cat].append(rule_name)

            for m in re.finditer(r"OwaspWeb\.(\w+)", web_cats):
                cat = m.group(1).lower()
                if cat in coverage.web:
                    coverage.web[cat].append(rule_name)

    return coverage


def get_tier_stats(tiers_path: Path) -> TierStats:
    """Extract tier statistics from tiers.dart."""
    stats = TierStats()
    content = tiers_path.read_text(encoding="utf-8")

    tier_patterns = {
        "essential": r"const Set<String> essentialRules = <String>\{([^}]*)\};",
        "recommended": r"const Set<String> recommendedOnlyRules = <String>\{([^}]*)\};",
        "professional": r"const Set<String> professionalOnlyRules = <String>\{([^}]*)\};",
        "comprehensive": r"const Set<String> comprehensiveOnlyRules = <String>\{([^}]*)\};",
        "insanity": r"const Set<String> insanityOnlyRules = <String>\{([^}]*)\};",
    }

    for tier, pattern in tier_patterns.items():
        match = re.search(pattern, content, re.DOTALL)
        if match:
            set_content = match.group(1)
            set_content = "\n".join(
                line
                for line in set_content.splitlines()
                if not line.strip().startswith("//")
            )
            rule_names = re.findall(r"'([a-z0-9_]+)'", set_content)
            stats.counts[tier] = len(rule_names)
            stats.rules[tier] = set(rule_names)

    # Stylistic rules
    stylistic_pattern = (
        r"const Set<String> stylisticRules = <String>\{([^}]*)\};"
    )
    match = re.search(stylistic_pattern, content, re.DOTALL)
    if match:
        set_content = match.group(1)
        stylistic_rules = set(re.findall(r"'([a-z0-9_]+)'", set_content))
        stats.counts["stylistic"] = len(stylistic_rules)
        stats.rules["stylistic"] = stylistic_rules
        stats.stylistic_rules = stylistic_rules

    return stats


def get_severity_stats(rules_dir: Path) -> SeverityStats:
    """Extract severity statistics from rule files."""
    stats = SeverityStats()
    severity_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.(\w+);"
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        for match in severity_pattern.finditer(content):
            severity = match.group(1).lower()
            if severity in stats.counts:
                stats.counts[severity] += 1

    return stats


def find_orphan_rules(
    implemented_rules: set[str], tier_stats: TierStats
) -> set[str]:
    """Find rules that are implemented but not in any tier."""
    return implemented_rules - tier_stats.all_tier_rules


# =============================================================================
# PRINT FUNCTIONS
# =============================================================================


def print_duplicate_report(duplicates: dict) -> None:
    """Print report of duplicate class names, rule names, and aliases."""
    from scripts.modules._utils import print_section

    print_section("Duplicate Rule/Class/Alias Check")
    any_duplicates = False
    for kind, dups in [
        ("Class names", duplicates["class_names"]),
        ("Rule names", duplicates["rule_names"]),
        ("Aliases", duplicates["aliases"]),
    ]:
        if dups:
            any_duplicates = True
            print_error(f"Duplicate {kind} found:")
            for name, entries in dups.items():
                print(f"    {name}")
                for entry in entries:
                    print(
                        f"      - {entry['file']} "
                        f"(problemMessage length: {entry['problem_len']})"
                    )
        else:
            print_success(f"No duplicate {kind.lower()} detected.")
    if not any_duplicates:
        print_success("No duplicate rules, class names, or aliases found.")


def print_owasp_coverage(coverage: OwaspCoverage) -> None:
    """Print OWASP coverage statistics."""
    print_subheader("OWASP Security Coverage")
    print_stat_bar("Mobile Top 10", coverage.mobile_covered, 10, Color.GREEN)
    print_stat_bar("Web Top 10", coverage.web_covered, 10, Color.CYAN)
    print()
    print_stat(
        "Total mobile rule mappings", coverage.total_mobile_mappings, Color.DIM
    )
    print_stat(
        "Total web rule mappings", coverage.total_web_mappings, Color.DIM
    )

    uncovered_mobile = [k for k, v in coverage.mobile.items() if not v]
    uncovered_web = [k for k, v in coverage.web.items() if not v]

    if uncovered_mobile or uncovered_web:
        print()
        if uncovered_mobile:
            print_warning(
                f"Uncovered Mobile: "
                f"{', '.join(c.upper() for c in uncovered_mobile)}"
            )
        if uncovered_web:
            print_warning(
                f"Uncovered Web: "
                f"{', '.join(c.upper() for c in uncovered_web)}"
            )


def print_tier_stats(stats: TierStats) -> None:
    """Print tier distribution statistics."""
    print_subheader("Rules by Tier")

    cumulative = 0
    tier_colors = {
        "essential": Color.RED,
        "recommended": Color.YELLOW,
        "professional": Color.GREEN,
        "comprehensive": Color.CYAN,
        "insanity": Color.MAGENTA,
        "stylistic": Color.BLUE,
    }

    for tier in TIERS:
        count = stats.counts[tier]
        cumulative += count
        color = tier_colors.get(tier, Color.WHITE)
        bar_width = min(count // 10, 30)
        bar = "█" * bar_width
        print(
            f"    {color.value}{tier.capitalize():<14}{Color.RESET.value} "
            f"{count:>4}  {color.value}{bar}{Color.RESET.value} "
            f"{Color.DIM.value}Σ {cumulative}{Color.RESET.value}"
        )

    print()
    print_stat("Total in tier system", stats.total, Color.CYAN)


def print_severity_stats(stats: SeverityStats) -> None:
    """Print severity distribution statistics."""
    print_subheader("Rules by Severity")

    severity_colors = {
        "critical": Color.RED,
        "high": Color.YELLOW,
        "medium": Color.WHITE,
        "low": Color.DIM,
    }

    for severity in SEVERITIES:
        count = stats.counts[severity]
        color = severity_colors.get(severity, Color.WHITE)
        print_stat_bar(severity.capitalize(), count, stats.total, color)


def print_quality_metrics(
    file_stats: list[FileStats],
    rules: set[str],
    quick_fixes: int,
    with_corrections: set[str],
) -> None:
    """Print code quality metrics."""
    print_subheader("Quality Metrics")

    total_rules = len(rules)
    fix_pct = (quick_fixes / total_rules * 100) if total_rules > 0 else 0
    fix_color = (
        Color.GREEN
        if fix_pct >= 20
        else Color.YELLOW
        if fix_pct >= 10
        else Color.RED
    )
    print_stat_bar("Quick fix coverage", quick_fixes, total_rules, fix_color)

    correction_count = len(with_corrections)
    correction_pct = (
        (correction_count / total_rules * 100) if total_rules > 0 else 0
    )
    correction_color = (
        Color.GREEN
        if correction_pct >= 80
        else Color.YELLOW
        if correction_pct >= 50
        else Color.RED
    )
    print_stat_bar(
        "Correction messages", correction_count, total_rules, correction_color
    )

    total_lines = sum(s.lines for s in file_stats)
    avg_lines = total_lines / total_rules if total_rules > 0 else 0
    print()
    print_stat("Total lines of code", f"{total_lines:,}", Color.CYAN)
    print_stat("Avg lines per rule", f"{avg_lines:.0f}", Color.DIM)


def print_file_health(file_stats: list[FileStats]) -> None:
    """Print file health analysis."""
    print_subheader("File Health")
    if not file_stats:
        return

    sorted_by_rules = sorted(
        file_stats, key=lambda s: s.rules, reverse=True
    )
    print_colored("    Largest files (by rule count):", Color.DIM)
    for s in sorted_by_rules[:5]:
        color = Color.YELLOW if s.rules > 50 else Color.WHITE
        print(
            f"      {color.value}{s.name:<45}{Color.RESET.value} "
            f"{s.rules:>3} rules"
        )

    print()
    empty_files = [s for s in file_stats if s.rules == 0]
    if empty_files:
        print_colored(
            f"    Files with no rules: {len(empty_files)}", Color.DIM
        )

    low_fix = [s for s in file_stats if s.rules >= 5 and s.fix_coverage < 10]
    if low_fix:
        print_colored(
            f"    Files needing quick fixes: {len(low_fix)}", Color.YELLOW
        )


def print_orphan_analysis(
    orphan_rules: set[str],
    tier_stats: TierStats,
) -> None:
    """Print analysis of orphan rules (not in any tier)."""
    if not orphan_rules:
        print_success("All rules are assigned to tiers")
        return

    non_stylistic = [
        r
        for r in sorted(orphan_rules)
        if r not in tier_stats.stylistic_rules
    ]
    if not non_stylistic:
        print_success("All rules are assigned to tiers (including stylistic)")
        return

    print_warning(f"{len(non_stylistic)} rules not assigned to any tier:")
    print()
    for rule in non_stylistic[:10]:
        print(f"      {Color.DIM.value}{rule}{Color.RESET.value}")
    if len(non_stylistic) > 10:
        print(
            f"      {Color.DIM.value}"
            f"... and {len(non_stylistic) - 10} more"
            f"{Color.RESET.value}"
        )
