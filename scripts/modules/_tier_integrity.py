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

These checks mirror the Dart tests in test/integrity/saropa_lints_test.dart
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
        flutter_stylistic_not_in_stylistic: Rules in flutterStylisticRules
            but not in stylisticRules.
        package_rules_not_in_tiers: Rules in packageRuleSets but not in
            any tier set. Each entry is (rule_name, package_name).
        unpaired_examples: Rules that have exampleBad but not exampleGood
            or vice versa. Each entry is (rule_name, which_missing).
        core_lint_collisions: saropa_lints rule names that collide with
            core Dart/Flutter analyzer lint names. Zero permitted.
    """

    passed: bool
    orphan_rules: list[str] = field(default_factory=list)
    phantom_rules: list[str] = field(default_factory=list)
    multi_tier_rules: list[tuple[str, list[str]]] = field(default_factory=list)
    misplaced_opinionated: list[tuple[str, str]] = field(default_factory=list)
    flutter_stylistic_not_in_stylistic: list[str] = field(default_factory=list)
    package_rules_not_in_tiers: list[tuple[str, str]] = field(
        default_factory=list,
    )
    unpaired_examples: list[tuple[str, str]] = field(default_factory=list)
    core_lint_collisions: list[str] = field(default_factory=list)

    @property
    def issues_count(self) -> int:
        """Total number of issues found across all checks."""
        return (
            len(self.orphan_rules)
            + len(self.phantom_rules)
            + len(self.multi_tier_rules)
            + len(self.misplaced_opinionated)
            + len(self.flutter_stylistic_not_in_stylistic)
            + len(self.package_rules_not_in_tiers)
            + len(self.unpaired_examples)
            + len(self.core_lint_collisions)
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
    "pedantic": r"const Set<String> pedanticOnlyRules = <String>\{([^}]*)\};",
    "stylistic": r"const Set<String> stylisticRules = <String>\{([^}]*)\};",
}

# Core Dart/Flutter analyzer lint names. saropa_lints must NEVER register
# a rule under any of these names — zero collisions permitted. Sourced from
# the Dart SDK linter package (dart-lang/linter) as of Dart 3.7. Update
# this set when new core lints are added upstream.
#
# Only includes rules that a saropa_lints rule has historically collided
# with or is likely to collide with (common naming patterns). Not the
# full ~200-rule SDK set — add names as needed when new saropa_lints
# rules are authored with names close to core lints.
CORE_DART_LINT_NAMES: frozenset[str] = frozenset({
    "always_declare_return_types",
    "always_put_control_body_on_new_line",
    "always_put_required_named_parameters_first",
    "always_require_non_null_named_parameters",
    "always_specify_types",
    "always_use_package_imports",
    "annotate_overrides",
    "annotate_redeclares",
    "avoid_annotating_with_dynamic",
    "avoid_as",
    "avoid_bool_literals_in_conditional_expressions",
    "avoid_catches_without_on_clauses",
    "avoid_catching_errors",
    "avoid_classes_with_only_static_members",
    "avoid_double_and_int_checks",
    "avoid_dynamic_calls",
    "avoid_empty_else",
    "avoid_equals_and_hash_code_on_mutable_classes",
    "avoid_escaping_inner_quotes",
    "avoid_field_initializers_in_const_classes",
    "avoid_final_parameters",
    "avoid_function_literals_in_foreach_calls",
    "avoid_implementing_value_types",
    "avoid_init_to_null",
    "avoid_js_rounded_ints",
    "avoid_multiple_declarations_per_line",
    "avoid_null_checks_in_equality_operators",
    "avoid_positional_boolean_parameters",
    "avoid_print",
    "avoid_private_typedef_functions",
    "avoid_redundant_argument_values",
    "avoid_relative_lib_imports",
    "avoid_renaming_method_parameters",
    "avoid_return_types_on_setters",
    "avoid_returning_null",
    "avoid_returning_null_for_future",
    "avoid_returning_null_for_void",
    "avoid_returning_this",
    "avoid_setters_without_getters",
    "avoid_shadowing_type_parameters",
    "avoid_single_cascade_in_expression_statements",
    "avoid_slow_async_io",
    "avoid_type_to_string",
    "avoid_types_as_parameter_names",
    "avoid_types_on_closure_parameters",
    "avoid_unnecessary_containers",
    "avoid_unstable_final_fields",
    "avoid_unused_constructor_parameters",
    "avoid_void_async",
    "avoid_web_libraries_in_flutter",
    "await_only_futures",
    "camel_case_extensions",
    "camel_case_types",
    "cancel_subscriptions",
    "cascade_invocations",
    "cast_nullable_to_non_nullable",
    "close_sinks",
    "collection_methods_unrelated_type",
    "combinators_ordering",
    "comment_references",
    "conditional_uri_does_not_exist",
    "constant_identifier_names",
    "control_flow_in_finally",
    "curly_braces_in_flow_control_structures",
    "dangling_library_doc_comments",
    "depend_on_referenced_packages",
    "deprecated_consistency",
    "deprecated_member_use_from_same_package",
    "diagnostic_describe_all_properties",
    "directives_ordering",
    "discarded_futures",
    "do_not_use_environment",
    "document_ignores",
    "empty_catches",
    "empty_constructor_bodies",
    "empty_statements",
    "eol_at_end_of_file",
    "exhaustive_cases",
    "file_names",
    "flutter_style_todos",
    "hash_and_equals",
    "implementation_imports",
    "implicit_call_tearoffs",
    "implicit_reopen",
    "invalid_case_patterns",
    "join_return_with_assignment",
    "leading_newlines_in_multiline_strings",
    "library_annotations",
    "library_names",
    "library_prefixes",
    "library_private_types_in_public_api",
    "lines_longer_than_80_chars",
    "literal_only_boolean_expressions",
    "matching_super_parameters",
    "missing_code_block_language_in_doc_comment",
    "missing_whitespace_between_adjacent_strings",
    "no_adjacent_strings_in_list",
    "no_default_cases",
    "no_duplicate_case_values",
    "no_leading_underscores_for_library_prefixes",
    "no_leading_underscores_for_local_identifiers",
    "no_literal_bool_comparisons",
    "no_logic_in_create_state",
    "no_runtimeType_toString",
    "no_self_assignments",
    "no_wildcard_variable_uses",
    "non_constant_identifier_names",
    "noop_primitive_operations",
    "null_check_on_nullable_type_parameter",
    "null_closures",
    "omit_local_variable_types",
    "omit_obvious_local_variable_types",
    "omit_obvious_property_types",
    "one_member_abstracts",
    "only_throw_errors",
    "overridden_fields",
    "package_api_docs",
    "package_names",
    "package_prefixed_library_names",
    "parameter_assignments",
    "prefer_adjacent_string_concatenation",
    "prefer_asserts_in_initializer_lists",
    "prefer_asserts_with_message",
    "prefer_collection_literals",
    "prefer_conditional_assignment",
    "prefer_const_constructors",
    "prefer_const_constructors_in_immutables",
    "prefer_const_declarations",
    "prefer_const_literals_to_create_immutables",
    "prefer_constructors_over_static_methods",
    "prefer_contains",
    "prefer_double_quotes",
    "prefer_expression_function_bodies",
    "prefer_final_fields",
    "prefer_final_in_for_each",
    "prefer_final_locals",
    "prefer_final_parameters",
    "prefer_for_elements_to_map_fromIterable",
    "prefer_foreach",
    "prefer_function_declarations_over_variables",
    "prefer_generic_function_type_aliases",
    "prefer_if_elements_to_conditional_expressions",
    "prefer_if_null_operators",
    "prefer_initializing_formals",
    "prefer_inlined_adds",
    "prefer_int_literals",
    "prefer_interpolation_to_compose_strings",
    "prefer_is_empty",
    "prefer_is_not_empty",
    "prefer_is_not_operator",
    "prefer_iterable_whereType",
    "prefer_mixin",
    "prefer_null_aware_method_calls",
    "prefer_null_aware_operators",
    "prefer_relative_imports",
    "prefer_single_quotes",
    "prefer_spread_collections",
    "prefer_typing_uninitialized_variables",
    "prefer_void_to_null",
    "provide_deprecation_message",
    "public_member_api_docs",
    "recursive_getters",
    "require_trailing_commas",
    "secure_pubspec_urls",
    "sized_box_for_whitespace",
    "sized_box_shrink_expand",
    "slash_for_doc_comments",
    "sort_child_properties_last",
    "sort_constructors_first",
    "sort_pub_dependencies",
    "sort_unnamed_constructors_first",
    "specify_nonobvious_local_variable_types",
    "specify_nonobvious_property_types",
    "test_types_in_equals",
    "throw_in_finally",
    "tighten_type_of_initializing_formals",
    "type_annotate_public_apis",
    "type_init_formals",
    "type_literal_in_constant_pattern",
    "unawaited_futures",
    "unintended_html_in_doc_comment",
    "unnecessary_await_in_return",
    "unnecessary_brace_in_string_interps",
    "unnecessary_breaks",
    "unnecessary_const",
    "unnecessary_constructor_name",
    "unnecessary_final",
    "unnecessary_getters_setters",
    "unnecessary_lambdas",
    "unnecessary_late",
    "unnecessary_library_directive",
    "unnecessary_library_name",
    "unnecessary_new",
    "unnecessary_null_aware_assignments",
    "unnecessary_null_aware_operator_on_extension_on_nullable",
    "unnecessary_null_checks",
    "unnecessary_null_in_if_null_operators",
    "unnecessary_nullable_for_final_variable_declarations",
    "unnecessary_overrides",
    "unnecessary_parenthesis",
    "unnecessary_raw_strings",
    "unnecessary_statements",
    "unnecessary_string_escapes",
    "unnecessary_string_interpolations",
    "unnecessary_this",
    "unnecessary_to_list_in_spreads",
    "unreachable_from_main",
    "unrelated_type_equality_checks",
    "unsafe_html",
    "use_build_context_synchronously",
    "use_colored_box",
    "use_decorated_box",
    "use_enums",
    "use_full_hex_values_for_flutter_colors",
    "use_function_type_syntax_for_parameters",
    "use_if_null_to_convert_nulls_to_bools",
    "use_is_even_rather_than_modulo",
    "use_key_in_widget_constructors",
    "use_late_for_private_fields_and_variables",
    "use_named_constants",
    "use_raw_strings",
    "use_rethrow_when_possible",
    "use_setters_to_change_properties",
    "use_string_buffers",
    "use_string_in_part_of_directives",
    "use_super_parameters",
    "use_test_throws_matchers",
    "use_to_and_as_if_applicable",
    "use_truncating_division",
    "valid_regexps",
    "void_checks",
})


def _find_lint_rule_class_start(content: str, class_name: str) -> int:
    """Return byte offset of a lint rule class declaration, or -1.

    ``dart format`` often emits ``class Foo extends Bar`` on one line, but
    multiline ``class Foo\\n    extends Bar`` is valid and must be recognized
    when mapping ``_allRuleFactories`` entries to ``LintCode`` names. Missing
    either shape produces false **phantom rule** audit failures.
    """
    same_line = content.find(f"class {class_name} ")
    if same_line != -1:
        return same_line
    multiline = re.search(
        rf"class {re.escape(class_name)}\s*\n\s+extends\s+",
        content,
    )
    return multiline.start() if multiline else -1


def get_registered_rule_names(
    saropa_lints_path: Path,
    rules_dir: Path,
) -> set[str]:
    """Extract rule names for classes registered in _allRuleFactories.

    This is the accurate "implemented rules" set — only rules that
    are actually registered in the plugin's factory list. Unregistered
    LintCode definitions in source files are excluded.

    The approach:
      1. Parse ``saropa_lints.dart`` to extract class names from
         ``_allRuleFactories`` (e.g. ``AvoidDebugPrintRule``).
      2. For each class, find its ``_code`` LintCode definition in
         the corresponding ``*_rules.dart`` file.
      3. Extract the ``name:`` value from the LintCode constructor.

    Args:
        saropa_lints_path: Path to lib/saropa_lints.dart.
        rules_dir: Path to lib/src/rules/ directory.

    Returns:
        Set of rule name strings registered in the plugin.
    """
    saropa_content = saropa_lints_path.read_text(encoding="utf-8")

    # Step 1: Extract factory class names (ClassName.new entries)
    # v5 uses SaropaLintRule, v4 used LintRule. The type and variable
    # name may be on separate lines.
    factory_match = re.search(
        r"final List<\w+LintRule Function\(\)>\s*"
        r"_allRuleFactories\s*=\s*<\w+LintRule Function\(\)>\[(.+?)\];",
        saropa_content,
        re.DOTALL,
    )
    if not factory_match:
        print_warning("Could not find _allRuleFactories in saropa_lints.dart")
        return set()

    class_names = re.findall(r"(\w+)\.new", factory_match.group(1))

    # Step 2: Build file content cache (read each file once)
    file_contents: dict[str, str] = {}
    for dart_file in rules_dir.glob("**/*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        file_contents[dart_file.name] = dart_file.read_text(encoding="utf-8")

    # Step 3: Resolve each class name to its _code rule name
    #
    # v5 uses positional constructor: LintCode('rule_name', 'message', ...)
    # v4 used named params:          LintCode(name: 'rule_name', ...)
    # Both formats are matched for backward compatibility.
    #
    # Also handles: LintCode(_name, ...) where _name is a const String.
    #
    # NOTE: Uses _code\w* (not _code) to match variant field names:
    #   _codeField, _codeMethod  (PreferWidgetPrivateMembersRule)
    #   _codeDoubleNegation, _codeDeMorgan  (PreferSimplerBooleanExpressionsRule)
    # Without \w*, rules using these names appear as "phantom" because
    # the regex can't resolve their class to a rule name.

    # v5 positional: LintCode('rule_name', ...
    code_positional = re.compile(
        r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
        r"'([a-z_0-9]+)',",
        re.DOTALL,
    )
    # v5 positional variable: LintCode(_name, ...
    code_positional_var = re.compile(
        r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
        r"(_\w+),",
        re.DOTALL,
    )
    # v4 named: LintCode(name: 'rule_name', ...
    code_literal = re.compile(
        r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
        r"name:\s*'([a-z_0-9]+)',",
        re.DOTALL,
    )
    # v4 named variable: LintCode(name: _name, ...
    code_variable = re.compile(
        r"static const (?:LintCode )?_code\w*\s*=\s*LintCode\(\s*"
        r"name:\s*(_\w+),",
        re.DOTALL,
    )
    name_const = re.compile(
        r"static const String (_\w+)\s*=\s*'([a-z_0-9]+)';",
    )

    registered: set[str] = set()

    for class_name in class_names:
        for _fname, content in file_contents.items():
            class_start = _find_lint_rule_class_start(content, class_name)
            if class_start == -1:
                continue

            # Find next class definition (or end of file)
            next_class = content.find("\nclass ", class_start + 1)
            class_body = content[class_start : (
                next_class if next_class != -1 else len(content)
            )]

            # Try v5 positional: LintCode('rule_name', ...
            match = code_positional.search(class_body)
            if match:
                registered.add(match.group(1))
                break

            # Try v4 named: LintCode(name: 'rule_name', ...
            match = code_literal.search(class_body)
            if match:
                registered.add(match.group(1))
                break

            # Try v5 positional variable: LintCode(_name, ...
            var_match = code_positional_var.search(class_body)
            if var_match:
                var_name = var_match.group(1)
                for nm in name_const.finditer(class_body):
                    if nm.group(1) == var_name:
                        registered.add(nm.group(2))
                        break
                break

            # Try v4 named variable: LintCode(name: _name, ...
            var_match = code_variable.search(class_body)
            if var_match:
                var_name = var_match.group(1)
                for nm in name_const.finditer(class_body):
                    if nm.group(1) == var_name:
                        registered.add(nm.group(2))
                        break
                break

            break

    return registered


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

    for dart_file in rules_dir.glob("**/*.dart"):
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
            rule_names = re.findall(r"'([a-z0-9_]+)'", set_content)
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

    IMPORTANT: Uses class-scoped searching to associate each impact
    getter with its own class's LintCode name. The previous approach
    searched backward from each ``LintImpact.opinionated`` occurrence
    for the nearest ``name:`` pattern, but in SaropaLintRule classes
    the field order is typically::

        class FooRule extends SaropaLintRule {
          const FooRule() : super(code: _code);
          LintImpact get impact => LintImpact.opinionated;  // ← here
          static const LintCode _code = LintCode(
            name: 'foo_rule',  // ← name is AFTER impact

    Because ``name:`` appears AFTER the impact getter, a backward
    search crosses into the previous class and picks up the wrong
    rule name. For example, if class A has ``name: 'prefer_foo'``
    and class B below it has ``LintImpact.opinionated``, the backward
    search from B's impact finds A's name — a false positive.

    The fix: find each class boundary first, then check impact and
    name within the same class body. This is the same approach used
    by ``get_owasp_coverage()`` in ``_audit.py``.

    Args:
        rules_dir: Path to lib/src/rules/ directory.

    Returns:
        Set of rule names matching both criteria.
    """
    opinionated_prefer: set[str] = set()
    # v5 positional: LintCode('rule_name', ...
    # v4 named:      LintCode(name: 'rule_name', ...
    name_pattern = re.compile(
        r"LintCode\(\s*(?:name:\s*)?'([a-z_0-9]+)',"
    )
    impact_pattern = re.compile(
        r"LintImpact get impact => LintImpact\.opinionated;"
    )
    class_pattern = re.compile(
        r"class\s+\w+\s+extends\s+\w+LintRule"
    )

    for dart_file in rules_dir.glob("**/*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")

        # Find each class boundary, then check within it
        class_starts = [m.start() for m in class_pattern.finditer(content)]

        for idx, start in enumerate(class_starts):
            # Class body extends to next class or end of file
            end = (
                class_starts[idx + 1]
                if idx + 1 < len(class_starts)
                else len(content)
            )
            class_body = content[start:end]

            # Only care about classes with opinionated impact
            if not impact_pattern.search(class_body):
                continue

            # Find rule name(s) within this class body
            for name_match in name_pattern.finditer(class_body):
                rule_name = name_match.group(1)
                if rule_name.startswith("prefer_"):
                    opinionated_prefer.add(rule_name)
                    break  # One name per class is enough

    return opinionated_prefer


def _parse_named_set(content: str, set_name: str) -> set[str]:
    """Extract rule names from a named ``const Set<String>`` in tiers.dart."""
    pattern = (
        rf"const Set<String> {set_name} = <String>\{{([^}}]*)\}};"
    )
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return set()
    set_content = "\n".join(
        line
        for line in match.group(1).splitlines()
        if not line.strip().startswith("//")
    )
    return set(re.findall(r"'([a-z0-9_]+)'", set_content))


def get_flutter_stylistic_rules(tiers_path: Path) -> set[str]:
    """Extract flutterStylisticRules from tiers.dart."""
    content = tiers_path.read_text(encoding="utf-8")
    return _parse_named_set(content, "flutterStylisticRules")


def get_package_rule_sets(tiers_path: Path) -> dict[str, set[str]]:
    """Extract all packageRuleSets from tiers.dart.

    Parses the ``packageRuleSets`` getter and resolves each
    ``<name>PackageRules`` reference to its const set.
    """
    content = tiers_path.read_text(encoding="utf-8")

    # Find all <name>PackageRules sets (e.g., blocPackageRules)
    pkg_set_pattern = re.compile(
        r"const Set<String> (\w+PackageRules) = <String>\{([^}]*)\};",
        re.DOTALL,
    )
    pkg_sets: dict[str, set[str]] = {}
    for match in pkg_set_pattern.finditer(content):
        set_name = match.group(1)
        set_content = "\n".join(
            line
            for line in match.group(2).splitlines()
            if not line.strip().startswith("//")
        )
        rules = set(re.findall(r"'([a-z0-9_]+)'", set_content))

        # Resolve spread references like ..._databaseSharedRules
        for spread in re.findall(r"\.\.\._?(\w+)", set_content):
            ref_name = f"_{spread}" if not spread.startswith("_") else spread
            ref_rules = _parse_named_set(content, ref_name)
            if not ref_rules:
                ref_rules = _parse_named_set(content, spread)
            rules.update(ref_rules)

        pkg_sets[set_name] = rules

    return pkg_sets


def get_unpaired_examples(rules_dir: Path) -> list[tuple[str, str]]:
    """Find rules where exampleBad/exampleGood are not paired.

    Scans rule classes for ``get exampleBad`` and ``get exampleGood``
    overrides. If a class has one but not the other, it's reported.

    Returns:
        List of (rule_name, missing_property) tuples.
    """
    unpaired: list[tuple[str, str]] = []

    class_pattern = re.compile(
        r"class\s+\w+\s+extends\s+\w+LintRule"
    )
    name_pattern = re.compile(
        r"LintCode\(\s*(?:name:\s*)?'([a-z_0-9]+)',"
    )
    bad_pattern = re.compile(r"String\s+get\s+exampleBad\s*=>")
    good_pattern = re.compile(r"String\s+get\s+exampleGood\s*=>")

    for dart_file in rules_dir.glob("**/*.dart"):
        if dart_file.name == "all_rules.dart":
            continue
        content = dart_file.read_text(encoding="utf-8")
        class_starts = [m.start() for m in class_pattern.finditer(content)]

        for idx, start in enumerate(class_starts):
            end = (
                class_starts[idx + 1]
                if idx + 1 < len(class_starts)
                else len(content)
            )
            class_body = content[start:end]

            name_match = name_pattern.search(class_body)
            if not name_match:
                continue
            rule_name = name_match.group(1)

            has_bad = bool(bad_pattern.search(class_body))
            has_good = bool(good_pattern.search(class_body))

            if has_bad and not has_good:
                unpaired.append((rule_name, "exampleGood"))
            elif has_good and not has_bad:
                unpaired.append((rule_name, "exampleBad"))

    return sorted(unpaired)


# =============================================================================
# INTEGRITY CHECK
# =============================================================================


def check_tier_integrity(
    rules_dir: Path,
    tiers_path: Path,
    saropa_lints_path: Path | None = None,
) -> TierIntegrityResult:
    """Run all tier integrity checks.

    This is the main entry point. It performs seven checks:

    Check 1 - Orphan rules:
        Every registered plugin rule must appear in exactly one tier
        set. Rules in _allRuleFactories but not in any tier set are
        orphans.

    Check 2 - Phantom rules:
        Every rule in tiers.dart must be registered in the plugin
        (or be an alias). Rules listed in a tier set but not found
        in _allRuleFactories are phantoms.

    Check 3 - Multi-tier rules:
        Each rule must appear in at most one tier set. The tier sets
        (essentialRules, recommendedOnlyRules, etc.) are mutually
        exclusive. A rule appearing in two sets is a bug.

    Check 4 - Opinionated placement:
        All prefer_* rules with LintImpact.opinionated must be in
        stylisticRules, not in a numbered tier. This ensures they
        are always opt-in and set to ``true`` in generated configs.

    Check 5 - flutterStylisticRules subset:
        Every rule in flutterStylisticRules must also be in
        stylisticRules. flutterStylisticRules is a filter, not a
        separate tier.

    Check 6 - Package rule set consistency:
        Every rule in a packageRuleSets entry must exist in the
        tier system (the union of all tier sets).

    Check 7 - Example pairing:
        If a rule overrides exampleBad, it must also override
        exampleGood (and vice versa). Unpaired examples break
        the interactive walkthrough display.

    Check 8 - Core lint name collisions:
        saropa_lints rule names must never collide with core
        Dart/Flutter analyzer lint names. Zero conflicts permitted.

    Args:
        rules_dir: Path to lib/src/rules/ directory.
        tiers_path: Path to lib/src/tiers.dart.
        saropa_lints_path: Path to lib/saropa_lints.dart. If None,
            derived from rules_dir parent.

    Returns:
        TierIntegrityResult with pass/fail and details of all issues.
    """
    if saropa_lints_path is None:
        saropa_lints_path = rules_dir.parent.parent / "saropa_lints.dart"

    implemented = get_registered_rule_names(saropa_lints_path, rules_dir)
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
    # Check 5: flutterStylisticRules ⊆ stylisticRules
    # ------------------------------------------------------------------
    flutter_stylistic = get_flutter_stylistic_rules(tiers_path)
    flutter_not_in_stylistic = sorted(flutter_stylistic - stylistic_set)

    # ------------------------------------------------------------------
    # Check 6: Package rules must be in tier system
    # ------------------------------------------------------------------
    pkg_sets = get_package_rule_sets(tiers_path)
    pkg_not_in_tiers: list[tuple[str, str]] = []
    for pkg_name, pkg_rules in sorted(pkg_sets.items()):
        for rule in sorted(pkg_rules - all_tiered):
            pkg_not_in_tiers.append((rule, pkg_name))

    # ------------------------------------------------------------------
    # Check 7: exampleBad/exampleGood must be paired
    # ------------------------------------------------------------------
    unpaired = get_unpaired_examples(rules_dir)

    # ------------------------------------------------------------------
    # Check 8: No collisions with core Dart/Flutter lint names
    # ------------------------------------------------------------------
    core_collisions = sorted(implemented & CORE_DART_LINT_NAMES)

    # ------------------------------------------------------------------
    # Result
    # ------------------------------------------------------------------
    passed = (
        not orphans
        and not phantoms
        and not multi_tier
        and not misplaced
        and not flutter_not_in_stylistic
        and not pkg_not_in_tiers
        and not unpaired
        and not core_collisions
    )

    return TierIntegrityResult(
        passed=passed,
        orphan_rules=orphans,
        phantom_rules=phantoms,
        multi_tier_rules=multi_tier,
        misplaced_opinionated=misplaced,
        flutter_stylistic_not_in_stylistic=flutter_not_in_stylistic,
        package_rules_not_in_tiers=pkg_not_in_tiers,
        unpaired_examples=unpaired,
        core_lint_collisions=core_collisions,
    )


# =============================================================================
# REPORTING
# =============================================================================


def get_tier_integrity_checks(
    result: TierIntegrityResult,
) -> list[tuple[str, str, list[str]]]:
    """Convert tier integrity results to check tuples for consolidated output.

    Returns list of (status, message, detail_lines) tuples compatible with
    ``_audit._print_quality_checks()``.
    """
    _P, _F = "pass", "fail"
    checks: list[tuple[str, str, list[str]]] = []

    # 1. Orphans
    if result.orphan_rules:
        shown = sorted(result.orphan_rules)[:10]
        checks.append((
            _F,
            f"{len(result.orphan_rules)} rule(s) not in any tier set",
            shown,
        ))
    else:
        checks.append((_P, "All rules assigned to a tier", []))

    # 2. Phantoms
    if result.phantom_rules:
        shown = sorted(result.phantom_rules)[:10]
        checks.append((
            _F,
            f"{len(result.phantom_rules)} phantom rule(s) in tiers.dart",
            shown,
        ))
    else:
        checks.append((_P, "All tier rules exist as implemented rules", []))

    # 3. Multi-tier
    if result.multi_tier_rules:
        details = [
            f"{rule} → {', '.join(tiers)}"
            for rule, tiers in result.multi_tier_rules[:10]
        ]
        checks.append((
            _F,
            f"{len(result.multi_tier_rules)} rule(s) in multiple tiers",
            details,
        ))
    else:
        checks.append((_P, "No rule appears in multiple tiers", []))

    # 4. Opinionated placement
    if result.misplaced_opinionated:
        details = [
            f"{rule} (in {tier})"
            for rule, tier in result.misplaced_opinionated[:10]
        ]
        checks.append((
            _F,
            f"{len(result.misplaced_opinionated)} prefer_* rule(s) "
            f"not in stylisticRules",
            details,
        ))
    else:
        checks.append((_P, "Opinionated prefer_* rules in stylisticRules", []))

    # 5. flutterStylisticRules subset
    if result.flutter_stylistic_not_in_stylistic:
        shown = sorted(result.flutter_stylistic_not_in_stylistic)[:10]
        checks.append((
            _F,
            f"{len(result.flutter_stylistic_not_in_stylistic)} "
            f"flutterStylistic rule(s) not in stylisticRules",
            shown,
        ))
    else:
        checks.append((
            _P, "All flutterStylisticRules exist in stylisticRules", [],
        ))

    # 6. Package rules
    if result.package_rules_not_in_tiers:
        details = [
            f"{rule} ({pkg})"
            for rule, pkg in result.package_rules_not_in_tiers[:10]
        ]
        checks.append((
            _F,
            f"{len(result.package_rules_not_in_tiers)} package rule(s) "
            f"not in tier system",
            details,
        ))
    else:
        checks.append((_P, "All package rules in tier system", []))

    # 7. Example pairing
    if result.unpaired_examples:
        details = [
            f"{rule} (missing {missing})"
            for rule, missing in result.unpaired_examples[:10]
        ]
        checks.append((
            _F,
            f"{len(result.unpaired_examples)} rule(s) with unpaired examples",
            details,
        ))
    else:
        checks.append((_P, "All rule examples properly paired", []))

    # 8. Core lint name collisions
    if result.core_lint_collisions:
        shown = sorted(result.core_lint_collisions)[:10]
        checks.append((
            _F,
            f"{len(result.core_lint_collisions)} rule(s) collide with core "
            f"Dart/Flutter lint names",
            shown,
        ))
    else:
        checks.append((_P, "No collisions with core Dart lint names", []))

    return checks


def print_tier_integrity_report(result: TierIntegrityResult) -> None:
    """Print a formatted tier integrity report to the terminal.

    Shows pass/fail status for each of the seven checks with
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

    # Check 5: flutterStylisticRules subset
    if result.flutter_stylistic_not_in_stylistic:
        print_error(
            f"{len(result.flutter_stylistic_not_in_stylistic)} rule(s) in "
            f"flutterStylisticRules but not in stylisticRules:"
        )
        for rule in result.flutter_stylistic_not_in_stylistic[:10]:
            print(f"      {Color.RED.value}{rule}{Color.RESET.value}")
        print()
    else:
        print_success(
            "flutterStylisticRules is a valid subset of stylisticRules"
        )

    # Check 6: Package rules in tier system
    if result.package_rules_not_in_tiers:
        print_error(
            f"{len(result.package_rules_not_in_tiers)} package rule(s) "
            f"not in any tier set:"
        )
        for rule, pkg in result.package_rules_not_in_tiers[:10]:
            print(
                f"      {Color.RED.value}{rule}{Color.RESET.value}"
                f" (in {pkg})"
            )
        if len(result.package_rules_not_in_tiers) > 10:
            print(
                f"      {Color.DIM.value}"
                f"... and {len(result.package_rules_not_in_tiers) - 10} more"
                f"{Color.RESET.value}"
            )
        print()
    else:
        print_success(
            "All package rules exist in the tier system"
        )

    # Check 7: Example pairing
    if result.unpaired_examples:
        print_error(
            f"{len(result.unpaired_examples)} rule(s) with unpaired "
            f"exampleBad/exampleGood:"
        )
        for rule, missing in result.unpaired_examples[:10]:
            print(
                f"      {Color.RED.value}{rule}{Color.RESET.value}"
                f" (missing {missing})"
            )
        print()
    else:
        print_success(
            "All rule examples are properly paired"
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
