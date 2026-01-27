"""
Comprehensive rule audit for saropa_lints.

Provides rule inventory, duplicate detection, tier distribution,
OWASP security coverage, DX message quality analysis, and quality
metrics. Called from the publish workflow (publish_to_pubdev.py)
as a pre-publish gate.

The main entry point is ``run_full_audit()``, which returns an
``AuditResult`` dataclass for programmatic inspection.

Version:   3.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import collections
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_error,
    print_header,
    print_info,
    print_section,
    print_stat,
    print_stat_bar,
    print_subheader,
    print_success,
    print_warning,
    get_project_dir,
)

# cspell:ignore refreshindicator searchdelegate didchangedependencies initstate


# =============================================================================
# DATA CLASSES
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


class RuleMessage:
    """A rule's problem message with DX quality metadata."""

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
        self.dx_score: int = 100

    def audit_dx(self) -> None:
        """Audit this message against DX quality criteria.

        Scoring: start at 100, deduct for issues.
        See inline comments for each check and its penalty.
        """
        msg = self.problem_message.lower()
        content = re.sub(r"^\[[a-z0-9_]+\]\s*", "", self.problem_message)

        # --- Vague language (-20) ---
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
                break

        # --- Consequence check (-30 for critical/high) ---
        consequence_indicators = [
            "leak", "memory", "gc", "garbage", "retain", "hold",
            "crash", "error", "exception", "fail", "throw", "break",
            "invalid", "corrupt", "undefined",
            "slow", "performance", "expensive", "overhead", "block",
            "hang", "freeze", "jank", "stutter",
            "waste", "drain", "battery", "bandwidth", "resource",
            "expose", "vulnerable", "security", "attack", "inject",
            "breach",
            "stale", "inconsistent", "race", "deadlock", "lost",
            "user", "screen reader", "accessibility", "colorblind",
        ]
        has_consequence = any(w in msg for w in consequence_indicators)
        if not has_consequence and self.impact in ("critical", "high"):
            self.dx_issues.append("Missing consequence (why it matters)")
            self.dx_score -= 30

        # --- Specific type check (-15 for generic terms) ---
        if self.impact in ("critical", "high"):
            if "controller" in msg:
                specific = [
                    "animation", "text", "scroll", "page", "tab",
                    "video", "audio", "media", "stream", "timer",
                    "socket", "websocket", "navigation", "focus",
                    "draggable", "refreshindicator", "searchdelegate",
                ]
                if not any(t in msg for t in specific):
                    self.dx_issues.append(
                        "Generic 'controller' - specify type"
                    )
                    self.dx_score -= 15

            if (
                "widget" in msg
                and "stateful" not in msg
                and "stateless" not in msg
            ):
                if not any(
                    w in msg for w in ["build", "tree", "parent", "child"]
                ):
                    self.dx_issues.append("Generic 'widget' - add context")
                    self.dx_score -= 10

            if "resource" in msg and not any(
                r in msg
                for r in [
                    "file", "socket", "stream", "connection", "database",
                    "memory", "handle", "port", "channel",
                ]
            ):
                self.dx_issues.append("Generic 'resource' - specify type")
                self.dx_score -= 10

        # --- Avoid prefix (-10) ---
        if (
            "] Avoid" in self.problem_message
            or "] avoid" in self.problem_message
        ):
            self.dx_issues.append("Starts with 'Avoid' - state detected")
            self.dx_score -= 10

        # --- Message length (-25/-15) ---
        if len(content) < 180 and self.impact in ("critical", "high"):
            self.dx_issues.append(
                f"Too short ({len(content)} chars) - min 180"
            )
            self.dx_score -= 25
        elif len(content) < 150 and self.impact == "medium":
            self.dx_issues.append(
                f"Very short ({len(content)} chars) - min 150"
            )
            self.dx_score -= 15

        # --- Correction message length (-10/-5) ---
        corr_len = (
            len(self.correction_message.strip())
            if self.correction_message
            else 0
        )
        if self.impact == "critical":
            if corr_len < 100:
                self.dx_issues.append(
                    f"Correction too short ({corr_len} chars) - min 100"
                )
                self.dx_score -= 10
        else:
            if 0 < corr_len < 80:
                self.dx_issues.append(
                    f"Correction too short ({corr_len} chars) - min 80"
                )
                self.dx_score -= 5

        # --- AI copilot compat (-15/-10) ---
        if self.impact in ("critical", "high"):
            if "dispose" in self.name and "dispose" not in msg:
                self.dx_issues.append("Disposal rule missing 'dispose'")
                self.dx_score -= 15

            method_keywords = [
                "build", "initstate", "didchangedependencies",
            ]
            if any(k in self.name for k in method_keywords):
                if not any(k in msg for k in method_keywords):
                    self.dx_issues.append("Method rule should name method")
                    self.dx_score -= 10

        # --- Passive voice (-10) ---
        passive_patterns = [
            "is required", "are required", "must be used",
            "needs to be", "has to be",
        ]
        if any(p in msg for p in passive_patterns):
            self.dx_issues.append("Passive voice - use active")
            self.dx_score -= 10

        # --- Bonus: Standards reference (+10) ---
        standards = [
            "owasp", "wcag", "material", "guideline",
            "m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10",
            "a01", "a02", "a03", "a04", "a05", "2.4", "1.4",
        ]
        if any(s in msg for s in standards):
            self.dx_score = min(100, self.dx_score + 10)

        # --- Bonus: Specific error message (+5) ---
        if "'" in self.problem_message and "error" in msg:
            self.dx_score = min(100, self.dx_score + 5)

        self.dx_score = max(0, self.dx_score)


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
            for alias in [a.strip() for a in alias_list.split(",") if a.strip()]:
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


def extract_rule_messages(rules_dir: Path) -> list[RuleMessage]:
    """Extract all rule messages with their impact levels."""
    messages: list[RuleMessage] = []

    lint_code_pattern = re.compile(
        r"static const (?:LintCode )?_code = LintCode\(\s*"
        r"name:\s*'([a-z0-9_]+)',\s*"
        r"problemMessage:\s*"
        r"(?:'([^']*)'|\"([^\"]*)\"),\s*"
        r"(?:correctionMessage:\s*(?:'([^']*)'|\"([^\"]*)\"),?\s*)?"
        r"[^)]*\);",
        re.DOTALL,
    )
    impact_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.(\w+);"
    )

    for dart_file in sorted(rules_dir.glob("*.dart")):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")

        for match in lint_code_pattern.finditer(content):
            name = match.group(1)
            problem_msg = match.group(2) or match.group(3) or ""
            correction_msg = match.group(4) or match.group(5) or ""

            pre_content = content[: match.start()]
            impact_matches = list(impact_pattern.finditer(pre_content))
            impact = (
                impact_matches[-1].group(1) if impact_matches else "medium"
            )

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


# =============================================================================
# PRINT FUNCTIONS
# =============================================================================


def print_duplicate_report(duplicates: dict) -> None:
    """Print report of duplicate class names, rule names, and aliases."""
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


def print_dx_audit_report(
    messages: list[RuleMessage], show_all: bool = False
) -> int:
    """Print DX audit report. Returns count of rules needing improvement."""
    all_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": [],
    }
    needs_work_by_impact: dict[str, list[RuleMessage]] = {
        "critical": [], "high": [], "medium": [], "low": [],
    }

    for m in messages:
        if m.impact in all_by_impact:
            all_by_impact[m.impact].append(m)
            if m.dx_issues:
                needs_work_by_impact[m.impact].append(m)

    needs_work = [
        m
        for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]
    impact_priority = {"critical": 0, "high": 1}
    needs_work.sort(
        key=lambda m: (impact_priority.get(m.impact, 99), m.dx_score)
    )

    total_needs_work = sum(len(v) for v in needs_work_by_impact.values())
    print_subheader(f"DX Message Quality ({total_needs_work} total issues)")

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
        pct_color = (
            Color.GREEN
            if pct >= 80
            else Color.YELLOW
            if pct >= 50
            else Color.RED
        )
        print(
            f"    {color.value}{impact.capitalize():<10}{Color.RESET.value} "
            f"{passing:>3}/{total:<3} passing  "
            f"{pct_color.value}({pct:>5.1f}%){Color.RESET.value}"
        )

    limit = 25 if not show_all else len(needs_work)
    shown = needs_work[:limit]

    if shown:
        print()
        print_colored("    Worst offenders (critical/high):", Color.DIM)
        for m in shown:
            if m.impact == "critical":
                impact_color = Color.RED
            elif m.impact == "high":
                impact_color = Color.YELLOW
            else:
                impact_color = Color.WHITE
            issue_preview = m.dx_issues[0] if m.dx_issues else ""
            print(
                f"      {impact_color.value}{m.dx_score:>3}"
                f"{Color.RESET.value} "
                f"{m.name:<40} "
                f"{Color.DIM.value}{issue_preview[:30]}{Color.RESET.value}"
            )

        if len(needs_work) > limit:
            print()
            print_info(
                f"{len(needs_work) - limit} more in report "
                f"(--dx-all to show all)"
            )

    return len(needs_work)


# =============================================================================
# REPORT EXPORT
# =============================================================================


def export_dx_report(
    messages: list[RuleMessage], output_dir: Path
) -> Path:
    """Export DX audit report to timestamped markdown file."""
    needs_work = [
        m
        for m in messages
        if m.impact in ("critical", "high") and m.dx_issues
    ]
    impact_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    needs_work.sort(
        key=lambda m: (m.dx_score, impact_order.get(m.impact, 4))
    )

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = output_dir / f"{timestamp}_dx_audit.md"

    by_file: dict[str, list[RuleMessage]] = {}
    for m in needs_work:
        file_key = m.file_path.name
        by_file.setdefault(file_key, []).append(m)

    lines: list[str] = []
    lines.append("# DX Message Quality Audit Report")
    lines.append("")
    lines.append(
        f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    )
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

    # Worst offenders
    worst = [m for m in needs_work if m.dx_score < 50]
    if worst:
        lines.append("## Priority: Worst Offenders (Score < 50)")
        lines.append("")
        lines.append(
            "| Rule | Impact | Score | Issues | Current Message |"
        )
        lines.append("|------|--------|-------|--------|-----------------|")
        for m in worst[:30]:
            issues = ", ".join(m.dx_issues[:2])
            msg_preview = m.problem_message[:60].replace("|", "\\|")
            if len(m.problem_message) > 60:
                msg_preview += "..."
            lines.append(
                f"| `{m.name}` | {m.impact} | {m.dx_score} "
                f"| {issues} | {msg_preview} |"
            )
        lines.append("")

    # By-file breakdown
    lines.append("## Rules by File")
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

    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


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
