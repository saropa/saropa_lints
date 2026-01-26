"""
Tier integrity checks for saropa_lints.

Validates that the tier system in tiers.dart is consistent with
implemented rules. These are BLOCKING checks - if any fail, the
publish workflow will not proceed.

Checks performed:
  1. Orphan rules   - implemented but not in any tier set
  2. Phantom rules  - in tiers.dart but not implemented
  3. Multi-tier     - same rule appears in more than one tier set
  4. Opinionated    - prefer_* rules with LintImpact.opinionated
                      must be in stylisticRules

These checks mirror the Dart tests in test/saropa_lints_test.dart
but run as a pre-publish gate in the Python workflow. Defense in
depth: the Dart tests catch issues during development, and this
script catches them before publishing.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_error,
    print_section,
    print_success,
    print_warning,
)


# =============================================================================
# RESULT DATA CLASS
# =============================================================================


@dataclass
class TierIntegrityResult:
    """Result of tier integrity validation.

    Attributes:
        passed: True if all checks passed.
        orphan_rules: Rules implemented but not in any tier set.
        phantom_rules: Rules in tiers.dart but not implemented.
        multi_tier_rules: Rules appearing in more than one tier set.
            Each entry is (rule_name, list_of_tier_names).
        misplaced_opinionated: Opinionated prefer_* rules not in
            stylisticRules. Each entry is (rule_name, current_tier).
    """

    passed: bool
    orphan_rules: list[str] = field(default_factory=list)
    phantom_rules: list[str] = field(default_factory=list)
    multi_tier_rules: list[tuple[str, list[str]]] = field(default_factory=list)
    misplaced_opinionated: list[tuple[str, str]] = field(default_factory=list)

    @property
    def issues_count(self) -> int:
        """Total number of issues found across all checks."""
        return (
            len(self.orphan_rules)
            + len(self.phantom_rules)
            + len(self.multi_tier_rules)
            + len(self.misplaced_opinionated)
        )


# =============================================================================
# EXTRACTION HELPERS
# =============================================================================

# The 6 tier set names in tiers.dart and their regex patterns.
# Order matters: checked in this order for display purposes.
TIER_SET_PATTERNS: dict[str, str] = {
    "essential": r"const Set<String> essentialRules = <String>\{([^}]*)\};",
    "recommended": r"const Set<String> recommendedOnlyRules = <String>\{([^}]*)\};",
    "professional": r"const Set<String> professionalOnlyRules = <String>\{([^}]*)\};",
    "comprehensive": r"const Set<String> comprehensiveOnlyRules = <String>\{([^}]*)\};",
    "insanity": r"const Set<String> insanityOnlyRules = <String>\{([^}]*)\};",
    "stylistic": r"const Set<String> stylisticRules = <String>\{([^}]*)\};",
}


def get_implemented_rule_names(rules_dir: Path) -> set[str]:
    """Extract all rule names from LintCode definitions in *_rules.dart.

    Parses ``static const _code = LintCode(name: 'rule_name', ...)``
    blocks to find implemented rule names. Only matches actual LintCode
    definitions, not comments or example code.

    Args:
        rules_dir: Path to lib/src/rules/ directory.

    Returns:
        Set of rule name strings (e.g. {'avoid_print', 'require_dispose'}).
    """
    rules: set[str] = set()

    # Match LintCode blocks: static const [LintCode] _code* = LintCode(name: '...',
    lintcode_pattern = re.compile(
        r"static const (?:LintCode )?_code\w* = LintCode\(\s*"
        r"name:\s*'([a-z_]+)',",
        re.DOTALL,
    )

    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        rules.update(lintcode_pattern.findall(content))

    return rules


def get_aliases(rules_dir: Path) -> set[str]:
    """Extract documented aliases from rule files.

    Aliases are documented as ``/// Alias: name1, name2`` in rule
    class doc comments. These are alternative names that map to
    a canonical rule.

    Args:
        rules_dir: Path to lib/src/rules/ directory.

    Returns:
        Set of alias strings.
    """
    aliases: set[str] = set()
    alias_pattern = re.compile(
        r"^///\s*Alias:\s*([a-zA-Z0-9_,\s]+)", re.MULTILINE
    )

    for dart_file in rules_dir.glob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        for match in alias_pattern.findall(content):
            for alias in match.split(","):
                alias = alias.strip()
                if alias:
                    aliases.add(alias)

    return aliases


def get_tier_assignments(tiers_path: Path) -> dict[str, set[str]]:
    """Parse tiers.dart and return tier-to-rules mapping.

    Reads each of the 6 const Set<String> definitions in tiers.dart
    and extracts the quoted rule names from each. Comments within the
    set blocks are stripped before parsing.

    Args:
        tiers_path: Path to lib/src/tiers.dart.

    Returns:
        Dict mapping tier name to set of rule names, e.g.
        {'essential': {'rule_a', 'rule_b'}, 'stylistic': {...}, ...}
    """
    content = tiers_path.read_text(encoding="utf-8")
    tiers: dict[str, set[str]] = {}

    for tier_name, pattern in TIER_SET_PATTERNS.items():
        match = re.search(pattern, content, re.DOTALL)
        if match:
            set_content = match.group(1)
            # Strip comment lines (// ...)
            set_content = "\n".join(
                line
                for line in set_content.splitlines()
                if not line.strip().startswith("//")
            )
            rule_names = re.findall(r"'([a-z_]+)'", set_content)
            tiers[tier_name] = set(rule_names)
        else:
            tiers[tier_name] = set()

    return tiers


def get_opinionated_prefer_rules(rules_dir: Path) -> set[str]:
    """Extract prefer_* rules that have LintImpact.opinionated.

    Finds rule classes where:
      1. The impact getter returns LintImpact.opinionated
      2. The rule name starts with 'prefer_'

    This mirrors the Dart test: opinionated prefer_* rules must be
    in stylisticRules. Non-prefer opinionated rules (avoid_*, require_*)
    are case-by-case and not enforced here.

    Args:
        rules_dir: Path to lib/src/rules/ directory.

    Returns:
        Set of rule names matching both criteria.
    """
    opinionated_prefer: set[str] = set()
    name_pattern = re.compile(r"name:\s*'([a-z_]+)'")
    impact_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.opinionated;"
    )

    for dart_file in rules_dir.glob("*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")

        for match in impact_pattern.finditer(content):
            # Search backwards from the impact getter to find the
            # nearest preceding rule name (from LintCode definition).
            pre_content = content[: match.start()]
            name_matches = list(name_pattern.finditer(pre_content))
            if name_matches:
                rule_name = name_matches[-1].group(1)
                if rule_name.startswith("prefer_"):
                    opinionated_prefer.add(rule_name)

    return opinionated_prefer


# =============================================================================
# INTEGRITY CHECK
# =============================================================================


def check_tier_integrity(
    rules_dir: Path,
    tiers_path: Path,
) -> TierIntegrityResult:
    """Run all tier integrity checks.

    This is the main entry point. It performs four checks:

    Check 1 - Orphan rules:
        Every implemented rule must appear in exactly one tier set.
        Rules that exist in *_rules.dart but not in any tier set in
        tiers.dart are orphans.

    Check 2 - Phantom rules:
        Every rule in tiers.dart must be implemented (or be an alias).
        Rules listed in a tier set but not found in any *_rules.dart
        file are phantoms.

    Check 3 - Multi-tier rules:
        Each rule must appear in at most one tier set. The tier sets
        (essentialRules, recommendedOnlyRules, etc.) are mutually
        exclusive. A rule appearing in two sets is a bug.

    Check 4 - Opinionated placement:
        All prefer_* rules with LintImpact.opinionated must be in
        stylisticRules, not in a numbered tier. This ensures they
        are always opt-in and set to ``true`` in generated configs.

    Args:
        rules_dir: Path to lib/src/rules/ directory.
        tiers_path: Path to lib/src/tiers.dart.

    Returns:
        TierIntegrityResult with pass/fail and details of all issues.
    """
    implemented = get_implemented_rule_names(rules_dir)
    aliases = get_aliases(rules_dir)
    tiers = get_tier_assignments(tiers_path)
    opinionated_prefer = get_opinionated_prefer_rules(rules_dir)

    # Union of all rules across all tier sets
    all_tiered: set[str] = set()
    for tier_rules in tiers.values():
        all_tiered.update(tier_rules)

    # ------------------------------------------------------------------
    # Check 1: Orphan rules (implemented but not in any tier)
    # ------------------------------------------------------------------
    orphans = sorted(implemented - all_tiered)

    # ------------------------------------------------------------------
    # Check 2: Phantom rules (in tiers but not implemented or aliased)
    # ------------------------------------------------------------------
    phantoms = sorted(all_tiered - implemented - aliases)

    # ------------------------------------------------------------------
    # Check 3: Multi-tier rules (in more than one exclusive set)
    # ------------------------------------------------------------------
    rule_to_tiers: dict[str, list[str]] = {}
    for tier_name, tier_rules in tiers.items():
        for rule in tier_rules:
            rule_to_tiers.setdefault(rule, []).append(tier_name)

    multi_tier = [
        (rule, tier_list)
        for rule, tier_list in sorted(rule_to_tiers.items())
        if len(tier_list) > 1
    ]

    # ------------------------------------------------------------------
    # Check 4: Opinionated prefer_* must be in stylistic
    # ------------------------------------------------------------------
    stylistic_set = tiers.get("stylistic", set())
    misplaced: list[tuple[str, str]] = []

    for rule in sorted(opinionated_prefer):
        if rule not in stylistic_set:
            # Find which tier it ended up in (if any)
            current_tier = "unassigned"
            for tier_name, tier_rules in tiers.items():
                if tier_name != "stylistic" and rule in tier_rules:
                    current_tier = tier_name
                    break
            misplaced.append((rule, current_tier))

    # ------------------------------------------------------------------
    # Result
    # ------------------------------------------------------------------
    passed = (
        not orphans and not phantoms and not multi_tier and not misplaced
    )

    return TierIntegrityResult(
        passed=passed,
        orphan_rules=orphans,
        phantom_rules=phantoms,
        multi_tier_rules=multi_tier,
        misplaced_opinionated=misplaced,
    )


# =============================================================================
# REPORTING
# =============================================================================


def print_tier_integrity_report(result: TierIntegrityResult) -> None:
    """Print a formatted tier integrity report to the terminal.

    Shows pass/fail status for each of the four checks with
    details of any failures.

    Args:
        result: The TierIntegrityResult from check_tier_integrity().
    """
    print_section("TIER INTEGRITY CHECK")

    # Check 1: Orphans
    if result.orphan_rules:
        print_error(
            f"{len(result.orphan_rules)} rule(s) not in any tier set:"
        )
        for rule in result.orphan_rules[:20]:
            print(f"      {Color.RED.value}{rule}{Color.RESET.value}")
        if len(result.orphan_rules) > 20:
            print(
                f"      {Color.DIM.value}"
                f"... and {len(result.orphan_rules) - 20} more"
                f"{Color.RESET.value}"
            )
        print()
    else:
        print_success("All implemented rules are assigned to a tier")

    # Check 2: Phantoms
    if result.phantom_rules:
        print_error(
            f"{len(result.phantom_rules)} phantom rule(s) in tiers.dart "
            f"(not implemented):"
        )
        for rule in result.phantom_rules[:20]:
            print(f"      {Color.RED.value}{rule}{Color.RESET.value}")
        if len(result.phantom_rules) > 20:
            print(
                f"      {Color.DIM.value}"
                f"... and {len(result.phantom_rules) - 20} more"
                f"{Color.RESET.value}"
            )
        print()
    else:
        print_success("All tier rules exist as implemented rules")

    # Check 3: Multi-tier
    if result.multi_tier_rules:
        print_error(
            f"{len(result.multi_tier_rules)} rule(s) in multiple tier sets:"
        )
        for rule, tier_list in result.multi_tier_rules[:10]:
            tiers_str = ", ".join(tier_list)
            print(
                f"      {Color.RED.value}{rule}{Color.RESET.value}"
                f" → {tiers_str}"
            )
        print()
    else:
        print_success("No rule appears in multiple tier sets")

    # Check 4: Opinionated placement
    if result.misplaced_opinionated:
        print_error(
            f"{len(result.misplaced_opinionated)} opinionated prefer_* "
            f"rule(s) not in stylisticRules:"
        )
        for rule, current_tier in result.misplaced_opinionated[:10]:
            print(
                f"      {Color.RED.value}{rule}{Color.RESET.value}"
                f" (currently in: {current_tier})"
            )
        print()
    else:
        print_success(
            "All opinionated prefer_* rules are in stylisticRules"
        )

    # Summary
    print()
    if result.passed:
        print_success("Tier integrity: ALL CHECKS PASSED")
    else:
        print_error(
            f"Tier integrity: FAILED ({result.issues_count} issue(s))"
        )
        print_warning(
            "Fix tier assignments in lib/src/tiers.dart before publishing."
        )
