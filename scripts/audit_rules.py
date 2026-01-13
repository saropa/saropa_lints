#!/usr/bin/env python3
"""
Audit implemented lint rules against ROADMAP.md entries.

This script identifies:
  - Rules in ROADMAP.md that are already implemented (as rules or aliases)
  - Near-matches that may indicate naming inconsistencies
  - Quick fixes (classes extending DartFix)
  - OWASP security coverage
  - Tier and severity distribution
  - Rules missing from tier assignments (orphan rules)
  - Rules missing correction messages
  - File-level statistics and health indicators

Version:   2.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa

Usage:
    python scripts/audit_rules.py [options]

Options:
    --dx-all    Show all DX issues (not just top 3)
    --no-dx     Skip DX message audit
    --compact   Compact output (skip file table)
"""

from __future__ import annotations

import os
import re
import sys
from datetime import datetime
from enum import Enum
from pathlib import Path


SCRIPT_VERSION = "2.0"

# cspell:ignore refreshindicator searchdelegate didchangedependencies initstate


# =============================================================================
# COLOR AND PRINTING
# =============================================================================
# NOTE: These utilities are duplicated across scripts. Consider extracting to
# scripts/utils.py if adding more scripts that need colored output.

class Color(Enum):
    """ANSI color codes."""
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    CYAN = "\033[96m"
    MAGENTA = "\033[95m"
    WHITE = "\033[97m"
    RESET = "\033[0m"
    DIM = "\033[2m"
    BOLD = "\033[1m"
    BLUE = "\033[94m"


def enable_ansi_support() -> None:
    """Enable ANSI escape sequence support on Windows (CMD and PowerShell)."""
    if sys.platform == "win32":
        try:
            import ctypes
            from ctypes import wintypes
            kernel32 = ctypes.windll.kernel32
            STD_OUTPUT_HANDLE = -11
            ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
            handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
            mode = wintypes.DWORD()
            kernel32.GetConsoleMode(handle, ctypes.byref(mode))
            kernel32.SetConsoleMode(
                handle, mode.value | ENABLE_VIRTUAL_TERMINAL_PROCESSING
            )
        except Exception:
            pass

        if "TERM" not in os.environ:
            os.environ["TERM"] = "xterm-256color"

        # Set UTF-8 encoding for stdout
        try:
            sys.stdout.reconfigure(encoding='utf-8')  # type: ignore[attr-defined]
        except (AttributeError, OSError):
            pass


# cspell: disable
def show_saropa_logo() -> None:
    """Display the Saropa 'S' logo in ASCII art."""
    logo = """
\033[38;5;208m                               ....\033[0m
\033[38;5;208m                       `-+shdmNMMMMNmdhs+-\033[0m
\033[38;5;209m                    -odMMMNyo/-..````.++:+o+/-\033[0m
\033[38;5;215m                 `/dMMMMMM/`          ``````````\033[0m
\033[38;5;220m                `dMMMMMMMMNdhhhdddmmmNmmddhs+-\033[0m
\033[38;5;226m                /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/\033[0m
\033[38;5;190m              . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+\033[0m
\033[38;5;154m              o     `..~~~::~+==+~:/+sdNMMMMMMMMMMMo\033[0m
\033[38;5;118m              m                        .+NMMMMMMMMMN\033[0m
\033[38;5;123m              m+                         :MMMMMMMMMm\033[0m
\033[38;5;87m              /N:                        :MMMMMMMMM/\033[0m
\033[38;5;51m               oNs.                    `+NMMMMMMMMo\033[0m
\033[38;5;45m                :dNy/.              ./smMMMMMMMMm:\033[0m
\033[38;5;39m                 `/dMNmhyso+++oosydNNMMMMMMMMMd/\033[0m
\033[38;5;33m                    .odMMMMMMMMMMMMMMMMMMMMdo-\033[0m
\033[38;5;57m                       `-+shdNNMMMMNNdhs+-\033[0m
\033[38;5;57m                               ````\033[0m
"""
    print(logo)
    current_year = datetime.now().year
    copyright_year = f"2024-{current_year}" if current_year > 2024 else "2024"
    print(f"\033[38;5;195m(c) {copyright_year} Saropa. All rights reserved.\033[0m")
    print("\033[38;5;117mhttps://saropa.com\033[0m")
    print()
# cspell: enable


def print_colored(message: str, color: Color) -> None:
    """Print a message with ANSI color codes."""
    print(f"{color.value}{message}{Color.RESET.value}")


def print_header(text: str) -> None:
    """Print a major section header."""
    print()
    print_colored("=" * 70, Color.CYAN)
    print_colored(f"  {text}", Color.CYAN)
    print_colored("=" * 70, Color.CYAN)
    print()


def print_section(text: str) -> None:
    """Print a section header with visual separation."""
    print()
    print_colored(f"{'─' * 70}", Color.DIM)
    print_colored(f"  {text}", Color.BOLD)
    print_colored(f"{'─' * 70}", Color.DIM)
    print()


def print_subheader(text: str) -> None:
    """Print a subsection header."""
    print()
    print_colored(f"▶ {text}", Color.YELLOW)
    print()


def print_success(message: str) -> None:
    """Print a success message."""
    print_colored(f"  ✓ {message}", Color.GREEN)


def print_warning(message: str) -> None:
    """Print a warning message."""
    print_colored(f"  ⚠ {message}", Color.YELLOW)


def print_error(message: str) -> None:
    """Print an error message."""
    print_colored(f"  ✗ {message}", Color.RED)


def print_info(message: str) -> None:
    """Print an info message."""
    print_colored(f"  ℹ {message}", Color.CYAN)


def print_stat(label: str, value: int | str, color: Color = Color.WHITE) -> None:
    """Print a statistic with label."""
    print(f"    {Color.DIM.value}{label}:{Color.RESET.value} "
          f"{color.value}{value}{Color.RESET.value}")


def print_stat_bar(
    label: str,
    value: int,
    total: int,
    color: Color = Color.GREEN,
    width: int = 20
) -> None:
    """Print a statistic with a visual progress bar."""
    pct = (value / total * 100) if total > 0 else 0
    filled = int(pct / 100 * width)
    bar = "█" * filled + "░" * (width - filled)
    print(f"    {label:<20} {color.value}{bar}{Color.RESET.value} "
          f"{value:>4}/{total:<4} ({pct:>5.1f}%)")


def print_file_stats_table(stats: list["FileStats"], compact: bool = False) -> None:
    """Print a table of per-file statistics."""
    if not stats:
        print("  No rule files found.")
        return

    if compact:
        # Just show summary in compact mode
        total_rules = sum(s.rules for s in stats)
        total_fixes = sum(s.fixes for s in stats)
        files_with_rules = sum(1 for s in stats if s.rules > 0)
        print_stat("Rule files", f"{files_with_rules} files with {total_rules} rules")
        print_stat("Quick fixes", total_fixes, Color.MAGENTA)
        return

    # Calculate column widths
    max_name_len = max(len(s.name) for s in stats)
    name_width = max(max_name_len, 20)

    # Header
    header = (f"  {'File':<{name_width}}  "
              f"{'Lines':>6}  {'Rules':>5}  {'Fixes':>5}")
    print_colored(header, Color.BOLD)
    print_colored("  " + "─" * (name_width + 22), Color.DIM)

    # Data rows
    total_lines = 0
    total_rules = 0
    total_fixes = 0

    for s in stats:
        total_lines += s.lines
        total_rules += s.rules
        total_fixes += s.fixes

        # Color based on rule count
        if s.rules == 0:
            color = Color.DIM
        elif s.rules >= 5:
            color = Color.GREEN
        else:
            color = Color.WHITE

        print(f"  {color.value}{s.name:<{name_width}}{Color.RESET.value}  "
              f"{s.lines:>6}  {s.rules:>5}  {s.fixes:>5}")

    # Footer
    print_colored("  " + "─" * (name_width + 22), Color.DIM)
    print(f"  {Color.BOLD.value}{'TOTAL':<{name_width}}{Color.RESET.value}  "
          f"{Color.CYAN.value}{total_lines:>6}{Color.RESET.value}  "
          f"{Color.GREEN.value}{total_rules:>5}{Color.RESET.value}  "
          f"{Color.MAGENTA.value}{total_fixes:>5}{Color.RESET.value}")


# =============================================================================
# RULE EXTRACTION
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


def get_file_stats(rules_dir: Path) -> list[FileStats]:
    """Get per-file statistics for all rule files.

    Returns:
        List of FileStats for each Dart file (excluding all_rules.dart).
    """
    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    fix_pattern = re.compile(r"class \w+ extends DartFix")
    stats: list[FileStats] = []

    for dart_file in sorted(rules_dir.glob("*.dart")):
        # Skip the aggregator file
        if dart_file.name == "all_rules.dart":
            continue

        content = dart_file.read_text(encoding="utf-8")
        lines = content.count("\n") + 1
        rule_names = name_pattern.findall(content)
        fixes = len(fix_pattern.findall(content))

        stats.append(FileStats(dart_file, lines, len(rule_names), fixes, rule_names))

    return stats


def get_implemented_rules(rules_dir: Path) -> tuple[set[str], set[str], int]:
    """Extract rule names, aliases, and quick fix count from Dart files.

    Returns:
        Tuple of (rule_names, aliases, quick_fix_count)
    """
    rules: set[str] = set()
    aliases: set[str] = set()
    fix_count = 0

    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    # Match: /// Alias: name1, name2, name3
    alias_pattern = re.compile(r"///\s*Alias:\s*([a-z_,\s]+)")
    # Match: class _SomeFix extends DartFix
    fix_pattern = re.compile(r"class \w+ extends DartFix")

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        rules.update(name_pattern.findall(content))
        fix_count += len(fix_pattern.findall(content))

        # Extract aliases
        for match in alias_pattern.findall(content):
            for alias in match.split(","):
                alias = alias.strip()
                if alias:
                    aliases.add(alias)

    return rules, aliases, fix_count


def get_roadmap_rules(roadmap_path: Path) -> set[str]:
    """Extract rule names from ROADMAP.md table entries."""
    rules: set[str] = set()
    pattern = re.compile(r"^\|\s*`([a-z_]+)`\s*\|", re.MULTILINE)

    content = roadmap_path.read_text(encoding="utf-8")
    rules.update(pattern.findall(content))

    return rules


def get_rules_with_corrections(rules_dir: Path) -> tuple[set[str], set[str]]:
    """Find rules with and without correction messages.

    Returns:
        Tuple of (rules_with_correction, rules_without_correction)
    """
    with_correction: set[str] = set()
    without_correction: set[str] = set()

    # Pattern to match LintCode with or without correctionMessage
    lint_code_with_correction = re.compile(
        r"name:\s*'([a-z_]+)'.*?correctionMessage:",
        re.DOTALL
    )
    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")

    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue

        content = dart_file.read_text(encoding="utf-8")

        # Get all rule names
        all_names = set(name_pattern.findall(content))

        # Get rules with corrections
        names_with_correction = set()
        for match in lint_code_with_correction.finditer(content):
            names_with_correction.add(match.group(1))

        with_correction.update(names_with_correction)
        without_correction.update(all_names - names_with_correction)

    return with_correction, without_correction


def get_opinionated_rules(rules_dir: Path) -> set[str]:
    """Extract all rules with LintImpact.opinionated from Dart rule files."""
    opinionated_rules: set[str] = set()
    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    impact_pattern = re.compile(r"LintImpact get impact => LintImpact.opinionated;")
    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        # Find all rule classes with opinionated impact
        for match in impact_pattern.finditer(content):
            # Search backwards for the nearest rule name
            pre_content = content[:match.start()]
            name_matches = list(name_pattern.finditer(pre_content))
            if name_matches:
                rule_name = name_matches[-1].group(1)
                opinionated_rules.add(rule_name)
    return opinionated_rules


# =============================================================================
# OWASP COVERAGE
# =============================================================================

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
        """Number of mobile categories with at least one rule."""
        return sum(1 for rules in self.mobile.values() if rules)

    @property
    def web_covered(self) -> int:
        """Number of web categories with at least one rule."""
        return sum(1 for rules in self.web.values() if rules)

    @property
    def total_mobile_mappings(self) -> int:
        """Total number of rule-to-mobile-category mappings."""
        return sum(len(rules) for rules in self.mobile.values())

    @property
    def total_web_mappings(self) -> int:
        """Total number of rule-to-web-category mappings."""
        return sum(len(rules) for rules in self.web.values())


def get_owasp_coverage(rules_dir: Path) -> OwaspCoverage:
    """Extract OWASP coverage from rule files.

    Parses the owasp getter patterns in Dart files to build coverage stats.
    """
    coverage = OwaspCoverage()

    # Pattern to match rule name
    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    # Pattern to match OWASP mapping block
    owasp_block_pattern = re.compile(
        r"OwaspMapping get owasp => const OwaspMapping\(\s*"
        r"mobile:\s*<OwaspMobile>\{([^}]*)\},?\s*"
        r"(?:web:\s*<OwaspWeb>\{([^}]*)\},?)?\s*\);",
        re.DOTALL
    )
    # Alternative pattern for web-only or different ordering
    owasp_block_alt = re.compile(
        r"OwaspMapping get owasp => const OwaspMapping\(\s*"
        r"web:\s*<OwaspWeb>\{([^}]*)\},?\s*"
        r"(?:mobile:\s*<OwaspMobile>\{([^}]*)\},?)?\s*\);",
        re.DOTALL
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue

        content = dart_file.read_text(encoding="utf-8")

        # Find all rule classes with their OWASP mappings
        # Split content by class definitions
        class_pattern = re.compile(
            r"class\s+(\w+)\s+extends\s+SaropaLintRule[^{]*\{",
            re.DOTALL
        )

        for class_match in class_pattern.finditer(content):
            class_start = class_match.start()
            # Find end of class (next class or end of file)
            next_class = class_pattern.search(content, class_match.end())
            class_end = next_class.start() if next_class else len(content)
            class_content = content[class_start:class_end]

            # Find rule name in this class
            name_match = name_pattern.search(class_content)
            if not name_match:
                continue
            rule_name = name_match.group(1)

            # Find OWASP mapping in this class
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

            # Parse mobile categories (e.g., "OwaspMobile.m1, OwaspMobile.m10")
            for m in re.finditer(r"OwaspMobile\.(\w+)", mobile_cats):
                cat = m.group(1).lower()
                if cat in coverage.mobile:
                    coverage.mobile[cat].append(rule_name)

            # Parse web categories (e.g., "OwaspWeb.a02, OwaspWeb.a07")
            for m in re.finditer(r"OwaspWeb\.(\w+)", web_cats):
                cat = m.group(1).lower()
                if cat in coverage.web:
                    coverage.web[cat].append(rule_name)

    return coverage


def print_owasp_coverage(coverage: OwaspCoverage) -> None:
    """Print OWASP coverage statistics."""
    print_subheader("OWASP Security Coverage")

    # Visual bars for coverage
    print_stat_bar("Mobile Top 10", coverage.mobile_covered, 10, Color.GREEN)
    print_stat_bar("Web Top 10", coverage.web_covered, 10, Color.CYAN)
    print()
    print_stat("Total mobile rule mappings", coverage.total_mobile_mappings, Color.DIM)
    print_stat("Total web rule mappings", coverage.total_web_mappings, Color.DIM)

    # Show uncovered categories
    uncovered_mobile = [k for k, v in coverage.mobile.items() if not v]
    uncovered_web = [k for k, v in coverage.web.items() if not v]

    if uncovered_mobile or uncovered_web:
        print()
        if uncovered_mobile:
            print_warning(f"Uncovered Mobile: {', '.join(c.upper() for c in uncovered_mobile)}")
        if uncovered_web:
            print_warning(f"Uncovered Web: {', '.join(c.upper() for c in uncovered_web)}")


# =============================================================================
# TIER AND SEVERITY STATISTICS
# =============================================================================

# Tier names in order
TIERS = ["essential", "recommended", "professional", "comprehensive", "insanity", "stylistic"]

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
        """Total rules across all tiers."""
        return sum(self.counts.values())

    @property
    def all_tier_rules(self) -> set[str]:
        """All rules that are assigned to a tier."""
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
        """Total rules with severity."""
        return sum(self.counts.values())


def get_tier_stats(tiers_path: Path) -> TierStats:
    """Extract tier statistics from tiers.dart, including stylistic rules as a pseudo-tier."""
    stats = TierStats()

    content = tiers_path.read_text(encoding="utf-8")

    # Pattern to match tier set definitions
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
            # Extract quoted rule names (not comments)
            rule_names = re.findall(r"'([a-z_]+)'", set_content)
            stats.counts[tier] = len(rule_names)
            stats.rules[tier] = set(rule_names)

    # Stylistic rules: parse from README_STYLISTIC.md
    stylistic_path = tiers_path.parent.parent.parent / "README_STYLISTIC.md"
    stylistic_rules = set()
    if stylistic_path.exists():
        md = stylistic_path.read_text(encoding="utf-8")
        stylistic_rules.update(re.findall(r"\| [`]?([a-z_]+)[`]?\s*\|", md))
    # Add all opinionated rules from Dart files
    rules_dir = tiers_path.parent / "rules"
    stylistic_rules.update(get_opinionated_rules(rules_dir))
    stats.counts["stylistic"] = len(stylistic_rules)
    stats.rules["stylistic"] = stylistic_rules
    stats.stylistic_rules = stylistic_rules
    return stats


def get_severity_stats(rules_dir: Path) -> SeverityStats:
    """Extract severity statistics from rule files."""
    stats = SeverityStats()

    # Pattern to match severity definitions
    severity_pattern = re.compile(r"LintImpact get impact => LintImpact\.(\w+);")

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue

        content = dart_file.read_text(encoding="utf-8")
        for match in severity_pattern.finditer(content):
            severity = match.group(1).lower()
            if severity in stats.counts:
                stats.counts[severity] += 1

    return stats


def print_tier_stats(stats: TierStats) -> None:
    """Print tier distribution statistics, including stylistic rules."""
    print_subheader("Rules by Tier")

    # Calculate cumulative totals for reference
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

        # Visual bar
        bar_width = min(count // 10, 30)
        bar = "█" * bar_width

        print(f"    {color.value}{tier.capitalize():<14}{Color.RESET.value} "
              f"{count:>4}  {color.value}{bar}{Color.RESET.value} "
              f"{Color.DIM.value}Σ {cumulative}{Color.RESET.value}")

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


# =============================================================================
# ADDITIONAL ANALYSIS
# =============================================================================

def find_orphan_rules(
    implemented_rules: set[str],
    tier_stats: TierStats
) -> set[str]:
    """Find rules that are implemented but not assigned to any tier (excluding stylistic)."""
    return implemented_rules - tier_stats.all_tier_rules - tier_stats.stylistic_rules


def print_quality_metrics(
    file_stats: list[FileStats],
    rules: set[str],
    quick_fixes: int,
    with_corrections: set[str],
    without_corrections: set[str],
) -> None:
    """Print code quality metrics."""
    print_subheader("Quality Metrics")

    total_rules = len(rules)

    # Quick fix coverage
    fix_pct = (quick_fixes / total_rules * 100) if total_rules > 0 else 0
    fix_color = Color.GREEN if fix_pct >= 20 else Color.YELLOW if fix_pct >= 10 else Color.RED
    print_stat_bar("Quick fix coverage", quick_fixes, total_rules, fix_color)

    # Correction message coverage
    correction_count = len(with_corrections)
    correction_pct = (correction_count / total_rules * 100) if total_rules > 0 else 0
    correction_color = Color.GREEN if correction_pct >= 80 else Color.YELLOW if correction_pct >= 50 else Color.RED
    print_stat_bar("Correction messages", correction_count, total_rules, correction_color)

    # Lines of code stats
    total_lines = sum(s.lines for s in file_stats)
    avg_lines_per_rule = total_lines / total_rules if total_rules > 0 else 0
    print()
    print_stat("Total lines of code", f"{total_lines:,}", Color.CYAN)
    print_stat("Avg lines per rule", f"{avg_lines_per_rule:.0f}", Color.DIM)


def print_file_health(file_stats: list[FileStats]) -> None:
    """Print file health analysis - files with most/least rules."""
    print_subheader("File Health")

    if not file_stats:
        return

    # Sort by rule count
    sorted_by_rules = sorted(file_stats, key=lambda s: s.rules, reverse=True)

    # Top 5 files with most rules
    print_colored("    Largest files (by rule count):", Color.DIM)
    for s in sorted_by_rules[:5]:
        color = Color.YELLOW if s.rules > 50 else Color.WHITE
        print(f"      {color.value}{s.name:<45}{Color.RESET.value} {s.rules:>3} rules")

    print()

    # Files with 0 rules (might be utility files)
    empty_files = [s for s in file_stats if s.rules == 0]
    if empty_files:
        print_colored(f"    Files with no rules: {len(empty_files)}", Color.DIM)

    # Files with low fix coverage
    low_fix_coverage = [s for s in file_stats if s.rules >= 5 and s.fix_coverage < 10]
    if low_fix_coverage:
        print_colored(f"    Files needing quick fixes: {len(low_fix_coverage)}", Color.YELLOW)


def print_orphan_analysis(
    orphan_rules: set[str],
    tier_stats: TierStats,
    implemented_rules: set[str],
) -> None:
    """Print analysis of orphan rules (not in any tier)."""
    if not orphan_rules:
        print_success("All rules are assigned to tiers")
        return

    print_warning(f"{len(orphan_rules)} rules not assigned to any tier:")
    print()

    # Show first 10
    for rule in sorted(orphan_rules)[:10]:
        print(f"      {Color.DIM.value}{rule}{Color.RESET.value}")

    if len(orphan_rules) > 10:
        print(f"      {Color.DIM.value}... and {len(orphan_rules) - 10} more{Color.RESET.value}")


# =============================================================================
# DX MESSAGE AUDIT
# =============================================================================

class RuleMessage:
    """A rule's problem message with metadata."""

    def __init__(
        self,
        name: str,
        impact: str,
        problem_message: str,
        correction_message: str,
        file_path: Path,
    ):
        self.name = name
        self.impact = impact
        self.problem_message = problem_message
        self.correction_message = correction_message
        self.file_path = file_path
        self.dx_issues: list[str] = []
        self.dx_score: int = 100  # Start at 100, deduct for issues

    def audit_dx(self) -> None:
        """Audit this message against DX criteria.

        Scoring:
        - Start at 100, deduct for issues
        - Vague language: -20 each
        - Missing consequence: -30
        - Generic types: -15
        - Starts with "Avoid": -10
        - Too short: -25
        - Missing specific type: -15
        - No actionable context: -20
        - Bonus for standards reference: +10
        """
        msg = self.problem_message.lower()
        content = re.sub(r"^\[[a-z_]+\]\s*", "", self.problem_message)

        # =================================================================
        # VAGUE LANGUAGE CHECKS (-20 each)
        # =================================================================
        vague_patterns = [
            ("should be", "Vague 'should be' - state consequence"),
            ("should have", "Vague 'should have' - state consequence"),
            ("consider ", "Vague 'consider' - be direct"),
            ("may want to", "Vague 'may want' - be direct"),
            ("might cause", "Vague 'might' - state definite consequence"),
            ("could lead to", "Vague 'could' - state definite consequence"),
            ("is not recommended", "Passive 'not recommended' - say why"),
            ("prefer to", "Vague 'prefer to' - explain why"),
            ("it is better", "Vague 'better' - quantify the benefit"),
            ("for better", "Vague 'better' - quantify the benefit"),
            ("best practice", "Vague 'best practice' - explain the risk"),
            ("not ideal", "Vague 'not ideal' - state consequence"),
            ("suboptimal", "Vague 'suboptimal' - state consequence"),
        ]
        for pattern, issue in vague_patterns:
            if pattern in msg:
                self.dx_issues.append(issue)
                self.dx_score -= 20
                break  # Only count once for vague language

        # =================================================================
        # CONSEQUENCE CHECK (-30 if missing for high/critical)
        # =================================================================
        consequence_indicators = [
            # Memory issues
            "leak", "memory", "gc", "garbage", "retain", "hold",
            # Crashes/errors
            "crash", "error", "exception", "fail", "throw", "break",
            "invalid", "corrupt", "undefined",
            # Performance
            "slow", "performance", "expensive", "overhead", "block",
            "hang", "freeze", "jank", "stutter",
            # Resource issues
            "waste", "drain", "battery", "bandwidth", "resource",
            # Security
            "expose", "vulnerable", "security", "attack", "inject",
            "leak", "breach",
            # State issues
            "stale", "inconsistent", "race", "deadlock", "lost",
            # User impact
            "user", "screen reader", "accessibility", "colorblind",
        ]
        has_consequence = any(w in msg for w in consequence_indicators)
        if not has_consequence and self.impact in ("critical", "high"):
            self.dx_issues.append("Missing consequence (why it matters)")
            self.dx_score -= 30

        # =================================================================
        # SPECIFIC TYPE CHECK (-15 if generic)
        # =================================================================
        if self.impact in ("critical", "high"):
            # Check for generic "controller" without specific type
            if "controller" in msg:
                specific_controllers = [
                    "animation", "text", "scroll", "page", "tab",
                    "video", "audio", "media", "stream", "timer",
                    "socket", "websocket", "navigation", "focus",
                    "draggable", "refreshindicator", "searchdelegate",
                ]
                if not any(t in msg for t in specific_controllers):
                    self.dx_issues.append("Generic 'controller' - specify type")
                    self.dx_score -= 15

            # Check for generic "widget" without context
            if "widget" in msg and "stateful" not in msg and "stateless" not in msg:
                if not any(w in msg for w in ["build", "tree", "parent", "child"]):
                    self.dx_issues.append("Generic 'widget' - add context")
                    self.dx_score -= 10

            # Check for generic "resource" without specification
            if "resource" in msg and not any(r in msg for r in [
                "file", "socket", "stream", "connection", "database",
                "memory", "handle", "port", "channel",
            ]):
                self.dx_issues.append("Generic 'resource' - specify type")
                self.dx_score -= 10

        # =================================================================
        # AVOID PREFIX CHECK (-10)
        # Problem message should state what IS wrong, not what to avoid
        # =================================================================
        if "] Avoid" in self.problem_message or "] avoid" in self.problem_message:
            self.dx_issues.append("Starts with 'Avoid' - state what's detected")
            self.dx_score -= 10

        # =================================================================
        # MESSAGE LENGTH CHECK (-25 if too short)
        # =================================================================
        if len(content) < 200 and self.impact in ("critical", "high"):
            self.dx_issues.append(f"Too short ({len(content)} chars) - add context (min 200)")
            self.dx_score -= 25
        elif len(content) < 150 and self.impact == "medium":
            self.dx_issues.append(f"Very short ({len(content)} chars) - add context (min 150)")
            self.dx_score -= 15

        # =================================================================
        # AI COPILOT COMPATIBILITY CHECKS (-15 each)
        # =================================================================
        # Check for missing technical specifics that AI needs
        if self.impact in ("critical", "high"):
            # Disposal rules should mention what needs disposing
            if "dispose" in self.name and "dispose" not in msg:
                self.dx_issues.append("Disposal rule missing 'dispose' in message")
                self.dx_score -= 15

            # Rules about methods should mention the method name
            method_keywords = ["build", "initstate", "didchangedependencies"]
            if any(k in self.name for k in method_keywords):
                if not any(k in msg for k in method_keywords):
                    self.dx_issues.append("Method rule should name the method")
                    self.dx_score -= 10

        # =================================================================
        # PASSIVE VOICE CHECK (-10)
        # =================================================================
        passive_patterns = [
            "is required", "are required", "must be used",
            "needs to be", "has to be",
        ]
        if any(p in msg for p in passive_patterns):
            self.dx_issues.append("Passive voice - use active")
            self.dx_score -= 10

        # =================================================================
        # BONUS: Standards references (+10)
        # =================================================================
        standards = ["owasp", "wcag", "material", "guideline", "m1", "m2",
                     "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10",
                     "a01", "a02", "a03", "a04", "a05", "2.4", "1.4"]
        if any(s in msg for s in standards):
            self.dx_score = min(100, self.dx_score + 10)

        # =================================================================
        # BONUS: Specific error messages (+5)
        # =================================================================
        if "'" in self.problem_message and "error" in msg:
            # Contains quoted error message - helpful for AI
            self.dx_score = min(100, self.dx_score + 5)

        self.dx_score = max(0, self.dx_score)


def extract_rule_messages(rules_dir: Path) -> list[RuleMessage]:
    """Extract all rule messages with their impact levels."""
    messages: list[RuleMessage] = []

    # Pattern to match a complete LintCode block
    lint_code_pattern = re.compile(
        r"static const (?:LintCode )?_code = LintCode\(\s*"
        r"name:\s*'([a-z_]+)',\s*"
        r"problemMessage:\s*"
        r"(?:'([^']*)'|\"([^\"]*)\"),\s*"
        r"(?:correctionMessage:\s*(?:'([^']*)'|\"([^\"]*)\"),?\s*)?"
        r"[^)]*\);",
        re.DOTALL
    )

    # Pattern to match impact level (appears before _code usually)
    impact_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.(\w+);"
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue

        content = dart_file.read_text(encoding="utf-8")

        # Find all LintCode blocks
        for match in lint_code_pattern.finditer(content):
            name = match.group(1)
            problem_msg = match.group(2) or match.group(3) or ""
            correction_msg = match.group(4) or match.group(5) or ""

            # Find impact level - search backwards from this match
            pre_content = content[:match.start()]
            impact_matches = list(impact_pattern.finditer(pre_content))
            impact = impact_matches[-1].group(1) if impact_matches else "medium"

            rule_msg = RuleMessage(
                name=name,
                impact=impact,
                problem_message=problem_msg,
                correction_message=correction_msg,
                file_path=dart_file,
            )
            rule_msg.audit_dx()
            messages.append(rule_msg)

    return messages


def print_dx_audit_report(messages: list[RuleMessage], show_all: bool = False) -> int:
    """Print DX audit report for messages.

    Returns:
        Number of rules needing improvement.
    """
    # Count all rules by impact level
    all_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": []
    }
    needs_work_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": []
    }

    for m in messages:
        if m.impact in all_by_impact:
            all_by_impact[m.impact].append(m)
            if m.dx_issues:
                needs_work_by_impact[m.impact].append(m)

    # Filter to high/critical for detailed report
    needs_work = [
        m for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]

    # Sort by score (worst first), then by impact
    impact_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    needs_work.sort(key=lambda m: (m.dx_score, impact_order.get(m.impact, 4)))

    total_needs_work = sum(len(v) for v in needs_work_by_impact.values())
    print_subheader(f"DX Message Quality ({total_needs_work} total issues)")

    # Show coverage by impact level with percentages
    impact_colors = {
        "critical": Color.RED,
        "high": Color.YELLOW,
        "medium": Color.WHITE,
        "low": Color.DIM,
    }

    for impact in ["critical", "high", "medium", "low"]:
        total = len(all_by_impact[impact])
        issues = len(needs_work_by_impact[impact])
        passing = total - issues
        pct = (passing / total * 100) if total > 0 else 100
        color = impact_colors[impact]

        # Color the percentage based on pass rate
        pct_color = Color.GREEN if pct >= 80 else Color.YELLOW if pct >= 50 else Color.RED
        print(f"    {color.value}{impact.capitalize():<10}{Color.RESET.value} "
              f"{passing:>3}/{total:<3} passing  "
              f"{pct_color.value}({pct:>5.1f}%){Color.RESET.value}")

    # Show top 3 worst offenders in terminal (full list in report)
    limit = 3 if not show_all else len(needs_work)
    shown = needs_work[:limit]

    if shown:
        print()
        print_colored("    Worst offenders (critical/high):", Color.DIM)
        for m in shown:
            score_color = (
                Color.RED if m.dx_score < 50 else
                Color.YELLOW if m.dx_score < 70 else
                Color.WHITE
            )
            issue_preview = m.dx_issues[0] if m.dx_issues else ""
            print(
                f"      {score_color.value}{m.dx_score:>3}{Color.RESET.value} "
                f"{m.name:<40} "
                f"{Color.DIM.value}{issue_preview[:30]}{Color.RESET.value}"
            )

        if len(needs_work) > limit:
            print()
            print_info(f"{len(needs_work) - limit} more in report (--dx-all to show all)")

    return len(needs_work)


def export_dx_report(messages: list[RuleMessage], output_dir: Path) -> Path:
    """Export DX audit report to timestamped markdown file.

    Returns:
        Path to the generated report file.
    """
    # Filter to high/critical impact rules with issues
    needs_work = [
        m for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]

    # Sort by score (worst first), then by impact
    impact_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    needs_work.sort(key=lambda m: (m.dx_score, impact_order.get(m.impact, 4)))

    # Generate filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"dx_audit_{timestamp}.md"
    output_path = output_dir / filename

    # Group by file for easier batch editing
    by_file: dict[str, list[RuleMessage]] = {}
    for m in needs_work:
        file_key = m.file_path.name
        if file_key not in by_file:
            by_file[file_key] = []
        by_file[file_key].append(m)

    # Build markdown content
    lines: list[str] = []
    lines.append("# DX Message Quality Audit Report")
    lines.append("")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    critical_count = sum(1 for m in needs_work if m.impact == "critical")
    high_count = sum(1 for m in needs_work if m.impact == "high")
    lines.append(f"- **Total rules needing work:** {len(needs_work)}")
    lines.append(f"- **Critical impact:** {critical_count}")
    lines.append(f"- **High impact:** {high_count}")
    lines.append(f"- **Files affected:** {len(by_file)}")
    lines.append("")
    lines.append("## Scoring Guide")
    lines.append("")
    lines.append("| Score | Status | Action |")
    lines.append("|-------|--------|--------|")
    lines.append("| 0-49 | Critical | Fix immediately - multiple serious issues |")
    lines.append("| 50-69 | Warning | Should fix - missing consequence or context |")
    lines.append("| 70-89 | Minor | Consider improving - minor issues |")
    lines.append("| 90-100 | Good | Meets DX standards |")
    lines.append("")

    # Worst offenders section (score < 50)
    worst = [m for m in needs_work if m.dx_score < 50]
    if worst:
        lines.append("## Priority: Worst Offenders (Score < 50)")
        lines.append("")
        lines.append("These rules have multiple serious DX issues and should be fixed first.")
        lines.append("")
        lines.append("| Rule | Impact | Score | Issues | Current Message |")
        lines.append("|------|--------|-------|--------|-----------------|")
        for m in worst[:30]:
            issues = ", ".join(m.dx_issues[:2])
            # Escape pipes in message
            msg_preview = m.problem_message[:60].replace("|", "\\|")
            if len(m.problem_message) > 60:
                msg_preview += "..."
            lines.append(
                f"| `{m.name}` | {m.impact} | {m.dx_score} | {issues} | {msg_preview} |"
            )
        lines.append("")

    # By-file breakdown for batch editing
    lines.append("## Rules by File")
    lines.append("")
    lines.append("Grouped for efficient batch editing.")
    lines.append("")

    for file_name in sorted(by_file.keys()):
        file_rules = by_file[file_name]
        lines.append(f"### {file_name} ({len(file_rules)} rules)")
        lines.append("")
        lines.append("| Rule | Score | Issues |")
        lines.append("|------|-------|--------|")
        for m in file_rules:
            issues = ", ".join(m.dx_issues[:2])
            lines.append(f"| `{m.name}` | {m.dx_score} | {issues} |")
        lines.append("")

    # Detailed section with current messages
    lines.append("## Full Details")
    lines.append("")
    lines.append("Current messages and suggested improvements.")
    lines.append("")

    for m in needs_work:
        lines.append(f"### `{m.name}`")
        lines.append("")
        lines.append(f"- **File:** `{m.file_path.name}`")
        lines.append(f"- **Impact:** {m.impact}")
        lines.append(f"- **Score:** {m.dx_score}/100")
        lines.append(f"- **Issues:** {', '.join(m.dx_issues)}")
        lines.append("")
        lines.append("**Current problemMessage:**")
        lines.append("```")
        lines.append(m.problem_message)
        lines.append("```")
        lines.append("")
        if m.correction_message:
            lines.append("**Current correctionMessage:**")
            lines.append("```")
            lines.append(m.correction_message)
            lines.append("```")
            lines.append("")
        lines.append("---")
        lines.append("")

    # Write file
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


def export_full_audit_report(
    file_stats: list[FileStats],
    rules: set[str],
    aliases: set[str],
    quick_fixes: int,
    with_corrections: set[str],
    without_corrections: set[str],
    tier_stats: TierStats,
    orphan_rules: set[str],
    severity_stats: SeverityStats,
    owasp_coverage: OwaspCoverage,
    dx_messages: list[RuleMessage],
    output_dir: Path
) -> Path:
    """Export a full audit report to markdown, covering all analysis sections."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"full_audit_{timestamp}.md"
    output_path = output_dir / filename
    lines: list[str] = []
    lines.append(f"# Saropa Lints Full Audit Report\n")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    lines.append("## Rule Inventory\n")
    lines.append(f"- Implemented rules: {len(rules)}\n")
    lines.append(f"- Documented aliases: {len(aliases)}\n")
    lines.append(f"- Quick fixes: {quick_fixes}\n")
    lines.append(f"- Rules with correction messages: {len(with_corrections)}\n")
    lines.append(f"- Rules without correction messages: {len(without_corrections)}\n")
    lines.append("")
    lines.append("### Rule Files\n")
    for s in file_stats:
        lines.append(f"- {s.name}: {s.rules} rules, {s.fixes} fixes, {s.lines} lines")
    lines.append("")
    lines.append("## Tier Assignment\n")
    for tier in TIERS:
        rules_in_tier = tier_stats.rules[tier]
        lines.append(f"### {tier.capitalize()} ({len(rules_in_tier)})\n")
        for rule in sorted(rules_in_tier):
            lines.append(f"- {rule}")
        lines.append("")
    lines.append(f"### Unassigned ({len(orphan_rules)})\n")
    for rule in sorted(orphan_rules):
        lines.append(f"- {rule}")
    lines.append("")
    lines.append("## Severity Distribution\n")
    for severity in SEVERITIES:
        lines.append(f"- {severity.capitalize()}: {severity_stats.counts[severity]}")
    lines.append("")
    lines.append("## OWASP Coverage\n")
    lines.append(f"Mobile categories covered: {owasp_coverage.mobile_covered}/10\n")
    lines.append(f"Web categories covered: {owasp_coverage.web_covered}/10\n")
    lines.append(f"Total mobile mappings: {owasp_coverage.total_mobile_mappings}\n")
    lines.append(f"Total web mappings: {owasp_coverage.total_web_mappings}\n")
    lines.append("")
    lines.append("## DX Message Audit\n")
    for m in dx_messages:
        lines.append(f"### {m.name}")
        lines.append(f"- Impact: {m.impact}")
        lines.append(f"- DX Score: {m.dx_score}")
        if m.dx_issues:
            lines.append(f"- Issues: {', '.join(m.dx_issues)}")
        lines.append(f"- Problem Message: {m.problem_message}")
        if m.correction_message:
            lines.append(f"- Correction Message: {m.correction_message}")
        lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


# =============================================================================
# MAIN
# =============================================================================

def main() -> int:
    """Main entry point."""
    enable_ansi_support()
    show_saropa_logo()
    print_header(f"SAROPA LINTS AUDIT v{SCRIPT_VERSION}")

    # Parse args
    show_dx_all = "--dx-all" in sys.argv
    skip_dx = "--no-dx" in sys.argv
    compact = "--compact" in sys.argv

    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    rules_dir = project_root / "lib" / "src" / "rules"
    roadmap_path = project_root / "ROADMAP.md"
    tiers_path = project_root / "lib" / "src" / "tiers.dart"

    # =========================================================================
    # SECTION 1: Rule Inventory
    # =========================================================================
    print_section("RULE INVENTORY")

    rules, aliases, quick_fixes = get_implemented_rules(rules_dir)
    implemented = rules | aliases
    roadmap = get_roadmap_rules(roadmap_path)
    file_stats = get_file_stats(rules_dir)
    with_corrections, without_corrections = get_rules_with_corrections(rules_dir)

    # File table (unless compact mode)
    if not compact:
        print_subheader("Rule Files")
        print_file_stats_table(file_stats, compact=False)

    # Summary stats
    print_subheader("Overview")
    print_stat("Implemented rules", len(rules), Color.GREEN)
    print_stat("Documented aliases", len(aliases), Color.CYAN)
    print_stat("Quick fixes", quick_fixes, Color.MAGENTA)
    print_stat("ROADMAP entries remaining", len(roadmap), Color.YELLOW)

    # =========================================================================
    # SECTION 2: Distribution Analysis
    # =========================================================================
    print_section("DISTRIBUTION ANALYSIS")

    # Tier statistics
    tier_stats: TierStats | None = None
    if tiers_path.exists():
        tier_stats = get_tier_stats(tiers_path)
        print_tier_stats(tier_stats)

    # Severity statistics
    severity_stats = get_severity_stats(rules_dir)
    print_severity_stats(severity_stats)

    # =========================================================================
    # SECTION 3: Security & Compliance
    # =========================================================================
    print_section("SECURITY & COMPLIANCE")

    # OWASP coverage
    owasp_coverage = get_owasp_coverage(rules_dir)
    print_owasp_coverage(owasp_coverage)

    # =========================================================================
    # SECTION 4: Quality Metrics
    # =========================================================================
    print_section("QUALITY METRICS")

    print_quality_metrics(
        file_stats, rules, quick_fixes, with_corrections, without_corrections
    )

    # Orphan rules analysis
    if tier_stats:
        print_subheader("Tier Assignment")
        orphan_rules = find_orphan_rules(rules, tier_stats)
        print_orphan_analysis(orphan_rules, tier_stats, rules)

    # File health
    print_file_health(file_stats)

    # =========================================================================
    # SECTION 5: ROADMAP Sync
    # =========================================================================
    print_section("ROADMAP SYNC")

    # Find exact matches (implemented or aliased AND in roadmap)
    duplicates = implemented & roadmap

    if duplicates:
        print_subheader(f"Duplicates Found ({len(duplicates)})")
        print_warning("These rules are already implemented but still in ROADMAP:")
        print()
        for rule in sorted(duplicates)[:10]:
            source = "alias" if rule in aliases else "rule"
            color = Color.CYAN if source == "alias" else Color.GREEN
            print(f"      {color.value}{rule}{Color.RESET.value} "
                  f"{Color.DIM.value}({source}){Color.RESET.value}")
        if len(duplicates) > 10:
            print(f"      {Color.DIM.value}... and {len(duplicates) - 10} more{Color.RESET.value}")
    else:
        print_success("ROADMAP is clean - no duplicates")

    # Find close matches using common naming variations
    remaining = roadmap - duplicates
    near_matches: list[tuple[str, str]] = []

    for roadmap_rule in sorted(remaining):
        for impl_rule in implemented:
            if (roadmap_rule.replace("_", "") == impl_rule.replace("_", "") or
                roadmap_rule + "s" == impl_rule or
                roadmap_rule == impl_rule + "s"):
                near_matches.append((roadmap_rule, impl_rule))
                break

    if near_matches:
        print_subheader(f"Near-Matches ({len(near_matches)})")
        print_warning("These may need aliases:")
        print()
        for roadmap_rule, impl_rule in near_matches[:5]:
            print(f"      {Color.YELLOW.value}{roadmap_rule}{Color.RESET.value}"
                  f" → {Color.GREEN.value}{impl_rule}{Color.RESET.value}")
        if len(near_matches) > 5:
            print(f"      {Color.DIM.value}... and {len(near_matches) - 5} more{Color.RESET.value}")

    # =========================================================================
    # SECTION 6: DX Message Audit
    # =========================================================================
    dx_issues_count = 0
    report_path: Path | None = None

    if not skip_dx:
        print_section("DX MESSAGE AUDIT")
        messages = extract_rule_messages(rules_dir)
        dx_issues_count = print_dx_audit_report(messages, show_all=show_dx_all)

        # Auto-export markdown report
        if dx_issues_count > 0:
            reports_dir = project_root / "reports"
            reports_dir.mkdir(exist_ok=True)
            report_path = export_dx_report(messages, reports_dir)
            print()
            print_info(f"Report: {report_path.relative_to(project_root)}")

        # Auto-export full audit report
        full_report_path = export_full_audit_report(
            file_stats, rules, aliases, quick_fixes,
            with_corrections, without_corrections,
            tier_stats, orphan_rules, severity_stats,
            owasp_coverage, messages, reports_dir
        )
        print_info(f"Full report: {full_report_path.relative_to(project_root)}")

    # =========================================================================
    # SUMMARY
    # =========================================================================
    print_header("SUMMARY")

    print_stat("Total rules", len(rules), Color.GREEN)
    print_stat("ROADMAP remaining", len(remaining), Color.YELLOW)
    print_stat("OWASP Mobile", f"{owasp_coverage.mobile_covered}/10",
               Color.GREEN if owasp_coverage.mobile_covered >= 8 else Color.YELLOW)
    print_stat("OWASP Web", f"{owasp_coverage.web_covered}/10",
               Color.GREEN if owasp_coverage.web_covered >= 8 else Color.YELLOW)
    print_stat("Quick fix coverage", f"{quick_fixes}/{len(rules)} ({quick_fixes/len(rules)*100:.0f}%)",
               Color.GREEN if quick_fixes/len(rules) > 0.15 else Color.YELLOW)

    if not skip_dx:
        dx_color = Color.RED if dx_issues_count > 50 else Color.YELLOW if dx_issues_count > 0 else Color.GREEN
        print_stat("DX issues", dx_issues_count, dx_color)

    print()

    if duplicates:
        print_error(f"Action required: Remove {len(duplicates)} duplicates from ROADMAP.md")
        return 1

    print_success("All checks passed!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
