# Adding saropa_lints alongside very_good_analysis

This guide helps you add `saropa_lints` to a project that already uses `very_good_analysis` (VGA).

**This is not a replacement guide.** VGA is a preset-only package — it ships zero custom rule
implementations. It enables ~206 stock Dart SDK `linter: rules:` entries (style, formatting,
documentation, basic correctness) via its `include:` file. saropa_lints is a separate custom
`analyzer_plugin`/`custom_lint` package delivering ~2,383 rules through its own plugin diagnostics
channel. **The two operate in completely different rule namespaces and are meant to run together** —
keep VGA (or `flutter_lints`) for stock rule coverage, and add saropa_lints for Flutter-specific,
security, accessibility, and performance analysis VGA doesn't attempt.

## Why Add saropa_lints?

| Feature | very_good_analysis | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | ~206 stock analyzer rules | 2,383+ custom rules |
| **Delivery mechanism** | `linter: rules:` (stock Dart SDK linter) | `analyzer_plugin`/`custom_lint` (custom analysis) |
| **Focus** | Style, formatting, docs, basic correctness | Flutter-specific patterns, security, accessibility, performance |
| **Configuration** | One `include:` line, fixed rule set | 5 progressive tiers + rule packs |
| **Maintenance** | Very Good Ventures, stable preset | Actively maintained |
| **Relationship to VGA** | N/A | Complementary, not competing — designed to run alongside VGA |

## Architecture Differences

VGA and saropa_lints sit at different layers of the Dart analysis toolchain:

| Aspect | very_good_analysis | saropa_lints |
|--------|---------------------|--------------|
| **Architecture** | `include:` file enabling stock `linter: rules:` | custom_lint / analyzer_plugin |
| **Rule implementations** | None — reuses the Dart SDK's built-in linter rules | ~2,383 custom implementations |
| **IDE integration** | Native — same engine as `dart analyze` | Real-time IDE feedback via custom_lint |
| **Installation** | `include: package:very_good_analysis/analysis_options.yaml` | Package dependency + `analyzer: plugins:` entry |

**VGA's approach**: VGA doesn't write rules — it curates which of the Dart SDK's existing stock
lints to turn on, at a strict, opinionated default. Because it rides the same analyzer engine as
`dart analyze`, there's no separate plugin process and no extra IDE integration to configure.

**saropa_lints' approach**: Uses the custom_lint plugin architecture to implement rules the stock
analyzer has no concept of — widget lifecycle, disposal tracking, secure storage, semantics labels,
Bloc/Riverpod/GetX patterns. The tier system lets you control memory usage — start with `essential`
(~300 rules) for lighter resource usage, scale up as needed.

**Recommendation**: Keep VGA's `include:` exactly as-is. Add saropa_lints as an additional plugin —
there is no conflict because the two never register the same rule name.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  very_good_analysis: ^10.0.0

# After — VGA stays, saropa_lints is added
dev_dependencies:
  very_good_analysis: ^10.0.0
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:very_good_analysis/analysis_options.yaml

# After — VGA's include: line is untouched, custom_lint is added alongside it
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint
```

Then generate the saropa_lints configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run both linters

```bash
dart analyze          # runs VGA's stock rules (and any other linter: rules:)
dart run custom_lint  # runs saropa_lints' custom rules
```

Most IDEs (VS Code, IntelliJ/Android Studio with the Dart/Flutter plugins) surface both sets of
diagnostics simultaneously once the saropa_lints extension or custom_lint server is running — you
do not need to choose one.

## Choosing a Tier

VGA has one fixed rule set. saropa_lints uses progressive tiers so you can dial in how much
additional signal you want on top of VGA:

| Goal | saropa_lints Tier | Description |
|------|-------------------|--------------|
| Just the critical Flutter/security gaps | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Balanced addition to VGA | **Recommended** (~900 rules) | Broad coverage without overwhelming noise |
| Enterprise-grade | **Professional** (~1,600 rules) | Stricter thresholds, more categories |
| Quality obsessed | **Comprehensive** (~2,100 rules) | Nearly everything |
| Maximum everything | **Pedantic** (2,383 rules) | Every single rule |

**Start with `recommended`** — it adds strong Flutter-specific coverage without duplicating what
VGA already checks.

**Plus 114 optional stylistic rules** for team preferences (trailing commas, sorting, etc.) — see
stylistic rules.

## Rule Mapping

Coverage: 191 stock rules audited. ~10 have an enhanced saropa custom equivalent (optional
upgrade). The rest are complementary — keep them enabled alongside saropa_lints.

Audited 2026-09-02 against VGA's `analysis_options.10.0.0.yaml`. For the ~10 rules where saropa
has a genuinely enhanced custom version (quick fix, context-awareness, stricter enforcement),
adopting the saropa rule and disabling the VGA one is optional — VGA's version still works fine on
its own. For the other ~181 rules, saropa_lints does not reimplement them by design: they are
stock Dart SDK style/correctness rules and belong to VGA's layer, not saropa's.

### A

| VGA Rule | Status | saropa_lints Equivalent |
|---|---|---|
| `always_declare_return_types` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `always_put_required_named_parameters_first` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `always_use_package_imports` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `annotate_overrides` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_bool_literals_in_conditional_expressions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_catching_errors` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_double_and_int_checks` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_dynamic_calls` | **ENHANCED** | `avoid_dynamic_calls_extended` (any dynamic-receiver call/property/operator, not just the stock rule's narrower cases; noSuchMethod-override exemption) |
| `avoid_empty_else` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_equals_and_hash_code_on_mutable_classes` | **ENHANCED** | `avoid_equals_and_hash_code_on_mutable_classes_extended` (flags each mutable field individually referenced by a hand-written equality and hashCode override) |
| `avoid_escaping_inner_quotes` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_field_initializers_in_const_classes` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_final_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_function_literals_in_foreach_calls` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_init_to_null` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_js_rounded_ints` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_multiple_declarations_per_line` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_null_checks_in_equality_operators` | **ENHANCED** | `avoid_null_checks_in_equality_operators_extended` (saropa metadata + requiredPatterns optimization) |
| `avoid_positional_boolean_parameters` | **ENHANCED** | `avoid_positional_boolean_parameters_with_fix` (adds quick fix) |
| `avoid_print` | **ENHANCED** | `avoid_print_in_release` / `avoid_print_in_production` (context-aware, release only) |
| `avoid_private_typedef_functions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_redundant_argument_values` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_relative_lib_imports` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_renaming_method_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_return_types_on_setters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_returning_null_for_void` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_returning_this` | **ENHANCED** | `avoid_returning_this_with_fix` (adds quick fix) |
| `avoid_setters_without_getters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_shadowing_type_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_single_cascade_in_expression_statements` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_slow_async_io` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_type_to_string` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_types_as_parameter_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_unnecessary_containers` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_unused_constructor_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_void_async` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `avoid_web_libraries_in_flutter` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `await_only_futures` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |

### C–L

| VGA Rule | Status | saropa_lints Equivalent |
|---|---|---|
| `camel_case_extensions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `camel_case_types` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `cancel_subscriptions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `cascade_invocations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `cast_nullable_to_non_nullable` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `collection_methods_unrelated_type` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `combinators_ordering` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `comment_references` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `conditional_uri_does_not_exist` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `constant_identifier_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `control_flow_in_finally` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `curly_braces_in_flow_control_structures` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `dangling_library_doc_comments` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `depend_on_referenced_packages` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `deprecated_consistency` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `directives_ordering` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `empty_catches` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `empty_constructor_bodies` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `empty_statements` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `eol_at_end_of_file` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `exhaustive_cases` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `file_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `flutter_style_todos` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `hash_and_equals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `implicit_call_tearoffs` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `implementation_imports` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `implicit_reopen` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `invalid_case_patterns` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `join_return_with_assignment` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `leading_newlines_in_multiline_strings` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `library_annotations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `library_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `library_prefixes` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `library_private_types_in_public_api` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |

### L–P

| VGA Rule | Status | saropa_lints Equivalent |
|---|---|---|
| `lines_longer_than_80_chars` | **ENHANCED** | `prefer_readable_line_length` (configurable threshold) |
| `literal_only_boolean_expressions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `missing_code_block_language_in_doc_comment` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `missing_whitespace_between_adjacent_strings` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_adjacent_strings_in_list` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_default_cases` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_duplicate_case_values` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_leading_underscores_for_library_prefixes` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_leading_underscores_for_local_identifiers` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_logic_in_create_state` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_runtimeType_toString` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_self_assignments` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `no_wildcard_variable_uses` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `non_constant_identifier_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `noop_primitive_operations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `null_check_on_nullable_type_parameter` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `null_closures` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `omit_local_variable_types` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `one_member_abstracts` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `only_throw_errors` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `overridden_fields` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `package_api_docs` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `package_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `package_prefixed_library_names` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `parameter_assignments` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |

### P–R

| VGA Rule | Status | saropa_lints Equivalent |
|---|---|---|
| `prefer_adjacent_string_concatenation` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_asserts_in_initializer_lists` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_asserts_with_message` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_collection_literals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_conditional_assignment` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_const_constructors` | **ENHANCED** | `prefer_declaring_const_constructor` (declaration-side check) |
| `prefer_const_constructors_in_immutables` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_const_declarations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_const_literals_to_create_immutables` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_constructors_over_static_methods` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_contains` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_final_fields` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_final_in_for_each` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_final_locals` | **ENHANCED** | `prefer_final_locals_with_fix` (adds quick fix) |
| `prefer_for_elements_to_map_fromIterable` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_function_declarations_over_variables` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_generic_function_type_aliases` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_if_elements_to_conditional_expressions` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_if_null_operators` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_initializing_formals` | **ENHANCED** | `prefer_initializing_formals_extended` (inverse-rule pairing + saropa metadata) |
| `prefer_inlined_adds` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_int_literals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_interpolation_to_compose_strings` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_is_empty` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_is_not_empty` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_is_not_operator` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_iterable_whereType` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_null_aware_method_calls` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_null_aware_operators` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_single_quotes` | **ENHANCED** | `prefer_single_quotes_strict` (stricter enforcement) |
| `prefer_spread_collections` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_typing_uninitialized_variables` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `prefer_void_to_null` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `provide_deprecation_message` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `public_member_api_docs` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `recursive_getters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `require_trailing_commas` | **ENHANCED** | `prefer_trailing_comma` / `prefer_trailing_comma_always` |

### S–V

| VGA Rule | Status | saropa_lints Equivalent |
|---|---|---|
| `secure_pubspec_urls` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `sized_box_for_whitespace` | **ENHANCED** | `prefer_sized_box_for_whitespace` |
| `sized_box_shrink_expand` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `slash_for_doc_comments` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `sort_child_properties_last` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `sort_constructors_first` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `sort_pub_dependencies` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `sort_unnamed_constructors_first` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `test_types_in_equals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `throw_in_finally` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `tighten_type_of_initializing_formals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `type_annotate_public_apis` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `type_init_formals` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unawaited_futures` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_await_in_return` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_breaks` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_brace_in_string_interps` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_const` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_constructor_name` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_getters_setters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_lambdas` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_late` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_library_directive` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_new` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_null_aware_assignments` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_null_checks` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_null_in_if_null_operators` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_nullable_for_final_variable_declarations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_overrides` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_parenthesis` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_raw_strings` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_statements` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_string_escapes` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_string_interpolations` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_this` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unnecessary_to_list_in_spreads` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `unrelated_type_equality_checks` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_build_context_synchronously` | **ENHANCED** | `check_mounted_after_async` / `require_mounted_check_after_await` (more specific checks) |
| `use_colored_box` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_enums` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_full_hex_values_for_flutter_colors` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_function_type_syntax_for_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_if_null_to_convert_nulls_to_bools` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_is_even_rather_than_modulo` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_key_in_widget_constructors` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_late_for_private_fields_and_variables` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_named_constants` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_raw_strings` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_rethrow_when_possible` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_setters_to_change_properties` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_string_buffers` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_string_in_part_of_directives` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_super_parameters` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_test_throws_matchers` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `use_to_and_as_if_applicable` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `valid_regexps` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |
| `void_checks` | N/A (stock analyzer rule) | Keep VGA/flutter_lints for this — saropa does not reimplement stock style rules |

## What You Gain

### Rules VGA Doesn't Have

VGA's stock rules stop at Dart-level style and correctness. saropa_lints includes Flutter-specific
rules entirely outside VGA's scope:

**Lifecycle & State**
- `avoid_context_in_initstate_dispose` - Prevents common Flutter bug
- `pass_existing_future_to_future_builder` - Prevents rebuild loops
- `require_dispose` - Full resource disposal tracking

**Security**
- `avoid_hardcoded_credentials` - Catches secrets in code
- `avoid_logging_sensitive_data` - PII protection
- `require_secure_storage` - SharedPreferences warnings
- `avoid_http_urls` - HTTPS enforcement

**Accessibility**
- `require_semantics_label` - Screen reader support
- `avoid_small_touch_targets` - Touch target sizing
- `avoid_color_only_indicators` - Color blindness support

**State Management**
- `avoid_bloc_event_in_constructor` - Bloc anti-patterns
- `avoid_watch_in_callbacks` - Riverpod best practices
- `require_notify_listeners` - ChangeNotifier checks

## What You Lose

Nothing — VGA and saropa_lints are complementary, not competing. Keep VGA enabled. saropa_lints
never generates a `linter: rules:` block for consumer projects, so there is no rule name collision
and no functionality to give up by adding it.

## Suppressing Rules

Both use underscore-separated rule names, so the syntax is identical:

```dart
// VGA style
// ignore: avoid_print

// saropa_lints style
// ignore: avoid_print_in_release
```

The only difference is which package owns the rule name — check the Rule Mapping table above if
you're unsure whether a rule is stock (VGA) or custom (saropa_lints).

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about adding saropa_lints to a VGA project? Open an issue - we're happy to help.
