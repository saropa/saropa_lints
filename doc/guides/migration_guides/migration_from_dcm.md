# Migrating from DCM (Dart Code Metrics)

This guide helps you migrate from `dart_code_metrics` (DCM) to `saropa_lints`.

## Why Migrate?

| Feature | DCM | saropa_lints |
|---------|-----|--------------|
| **Rule count** | ~70 rules + metrics | 2300+ custom rules |
| **Focus** | Code metrics & complexity | Flutter-specific analysis |
| **Configuration** | Extensive YAML options | 5 progressive tiers |
| **Maintenance** | DCM Classic discontinued | Actively maintained |
| **Cost** | DCM v2+ requires license | Free & open source |

**Note**: If you're using DCM primarily for metrics (cyclomatic complexity, lines of code, etc.), saropa_lints focuses more on Flutter-specific patterns. Consider your primary use case.

## Architecture Differences

DCM and saropa_lints take different approaches to performance:

| Aspect | DCM | saropa_lints |
|--------|-----|--------------|
| **Architecture** | Precompiled binary | custom_lint plugin |
| **IDE integration** | Separate CLI tool | Real-time IDE feedback |
| **Performance** | Fast CLI, limited IDE | Full IDE support, memory scales with tier |
| **Installation** | Global binary + project config | Package dependency only |

**DCM's approach**: DCM moved to a precompiled binary to solve performance issues with running many rules in the Dart Analysis Server. This makes CLI analysis fast but limits real-time IDE feedback.

**saropa_lints' approach**: Uses the custom_lint plugin architecture for full IDE integration (squiggles, quick fixes, hover info). The tier system lets you control memory usage - start with `essential` (~300 rules) for lighter resource usage, scale up as needed.

**Recommendation**: For large codebases concerned about IDE performance, start with `essential` or `recommended` tier. Use higher tiers in CI where memory isn't constrained.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  dart_code_metrics: ^5.7.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - dart_code_metrics

dart_code_metrics:
  anti-patterns:
    - long-method
    - long-parameter-list
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
  rules:
    - avoid-returning-widgets
    - prefer-conditional-expressions

# After
analyzer:
  plugins:
    - custom_lint
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Using Both Together

If you still need DCM's metrics alongside saropa_lints' rules:

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - dart_code_metrics
    - custom_lint

dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100
```

Then generate saropa_lints configuration:

```bash
dart run saropa_lints:init --tier recommended
```

```yaml
# pubspec.yaml
dev_dependencies:
  dart_code_metrics: ^5.7.0
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

## Choosing a Tier

DCM has granular metric thresholds. saropa_lints uses progressive tiers:

| DCM Usage | saropa_lints Tier | Description |
|-----------|-------------------|-------------|
| Minimal rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Default config | **Recommended** (~900 rules) | Balanced coverage |
| Strict metrics | **Professional** (~1600 rules) | Enterprise-grade |
| All rules enabled | **Comprehensive** (~2100 rules) | Quality obsessed |
| Maximum everything | **Pedantic** (1450+ rules) | Every single rule |

**Start with `recommended`** - it provides broad coverage without overwhelming noise.

**Plus 114 optional stylistic rules** for team preferences (trailing commas, sorting, etc.) - see [stylistic rules](../../README_STYLISTIC.md).

## Rule Mapping

Coverage: 425 HAVE (87%), 16 PARTIAL (3%), 46 TODO (9%) — audited 2026-09-02 against dcm.dev/docs/rules/.

### Common Dart

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `add-static-field` | TODO | TODO — see [proposal](../../../bugs/proposal_infra_add_static_field.md) |
| `arguments-ordering` | HAVE | `prefer_arguments_ordering` |
| `avoid-accessing-collections-by-constant-index` | HAVE | `avoid_accessing_collections_by_constant_index` |
| `avoid-accessing-other-classes-private-members` | HAVE | `avoid_accessing_other_classes_private_members` |
| `avoid-adjacent-strings` | HAVE | `avoid_adjacent_strings` |
| `avoid-always-null-parameters` | HAVE | `avoid_always_null_parameters` |
| `avoid-always-null-variables` | PARTIAL | `avoid_always_null_parameters` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_always_null_parameters_dcm_parity.md) |
| `avoid-assigning-to-static-field` | HAVE | `avoid_assigning_to_static_field` |
| `avoid-assignments-as-conditions` | HAVE | `avoid_assignments_as_conditions` |
| `avoid-async-call-in-sync-function` | HAVE | `avoid_async_call_in_sync_function` |
| `avoid-banned-annotations` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_banned_annotations.md) |
| `avoid-banned-exports` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_banned_exports.md) |
| `avoid-banned-file-names` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_banned_file_names.md) |
| `avoid-banned-imports` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_banned_imports.md) |
| `avoid-banned-names` | PARTIAL | `banned_identifier_usage` — TODO extend, see [proposal](../../../bugs/proposal_extend_banned_identifier_usage_dcm_parity.md) |
| `avoid-banned-types` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_banned_types.md) |
| `avoid-barrel-files` | HAVE | `avoid_barrel_files` |
| `avoid-bitwise-operators-with-booleans` | HAVE | `avoid_bitwise_operators_with_booleans` |
| `avoid-bottom-type-in-patterns` | HAVE | `avoid_bottom_type_in_patterns` |
| `avoid-bottom-type-in-records` | HAVE | `avoid_bottom_type_in_records` |
| `avoid-cascade-after-if-null` | HAVE | `avoid_cascade_after_if_null` |
| `avoid-casting-to-extension-type` | HAVE | `avoid_casting_to_extension_type` |
| `avoid-collapsible-if` | HAVE | `avoid_collapsible_if` |
| `avoid-collection-equality-checks` | HAVE | `avoid_collection_equality_checks` |
| `avoid-collection-methods-with-unrelated-types` | HAVE | `avoid_collection_methods_with_unrelated_types` |
| `avoid-collection-mutating-methods` | HAVE | `avoid_collection_mutating_methods` |
| `avoid-commented-out-code` | HAVE | `prefer_no_commented_out_code` |
| `avoid-complex-arithmetic-expressions` | HAVE | `avoid_complex_arithmetic_expressions` |
| `avoid-complex-conditions` | HAVE | `avoid_complex_conditions` |
| `avoid-complex-loop-conditions` | HAVE | `avoid_complex_loop_conditions` |
| `avoid-conditions-with-boolean-literals` | HAVE | `avoid_conditions_with_boolean_literals` |
| `avoid-constant-assert-conditions` | HAVE | `avoid_constant_assert_conditions` |
| `avoid-constant-conditions` | HAVE | `avoid_constant_conditions` |
| `avoid-constant-switches` | HAVE | `avoid_constant_switches` |
| `avoid-continue` | HAVE | `prefer_no_continue_statement` |
| `avoid-contradictory-expressions` | HAVE | `avoid_contradictory_expressions` |
| `avoid-declaring-call-method` | HAVE | `avoid_declaring_call_method` |
| `avoid-default-tostring` | HAVE | `avoid_default_tostring` |
| `avoid-deprecated-usage` | HAVE | `avoid_deprecated_usage` |
| `avoid-dot-shorthands` | HAVE | `prefer_dot_shorthand` |
| `avoid-double-slash-imports` | HAVE | `avoid_double_slash_imports` |
| `avoid-duplicate-cascades` | HAVE | `avoid_duplicate_cascades` |
| `avoid-duplicate-collection-elements` | HAVE | `avoid_duplicate_number_elements` / `avoid_duplicate_string_elements` / `avoid_duplicate_object_elements` |
| `avoid-duplicate-constant-values` | HAVE | `avoid_duplicate_constant_values` |
| `avoid-duplicate-exports` | HAVE | `avoid_duplicate_exports` |
| `avoid-duplicate-factories` | HAVE | `duplicate_constructor_declarations` |
| `avoid-duplicate-field-initializers` | HAVE | `duplicate_field_name` / `avoid_duplicate_initializers` |
| `avoid-duplicate-initializers` | HAVE | `avoid_duplicate_initializers` |
| `avoid-duplicate-map-keys` | HAVE | `avoid_duplicate_map_keys` |
| `avoid-duplicate-mixins` | HAVE | `avoid_duplicate_mixins` |
| `avoid-duplicate-named-imports` | HAVE | `avoid_duplicate_named_imports` |
| `avoid-duplicate-patterns` | HAVE | `avoid_duplicate_patterns` |
| `avoid-duplicate-switch-case-conditions` | HAVE | `avoid_duplicate_switch_case_conditions` |
| `avoid-duplicate-test-assertions` | HAVE | `avoid_duplicate_test_assertions` |
| `avoid-dynamic` | HAVE | `avoid_dynamic_type` |
| `avoid-empty-spread` | HAVE | `avoid_empty_spread` |
| `avoid-empty-test-groups` | HAVE | `avoid_empty_test_groups` |
| `avoid-enum-values-by-index` | HAVE | `avoid_enum_values_by_index` |
| `avoid-equal-expressions` | HAVE | `avoid_equal_expressions` |
| `avoid-excessive-expressions` | HAVE | `avoid_excessive_expressions` |
| `avoid-explicit-pattern-field-name` | HAVE | `avoid_explicit_pattern_field_name` |
| `avoid-explicit-type-declaration` | HAVE | `avoid_explicit_type_declaration` |
| `avoid-extensions-on-records` | HAVE | `avoid_extensions_on_records` |
| `avoid-function-type-in-records` | HAVE | `avoid_function_type_in_records` |
| `avoid-future-ignore` | HAVE | `avoid_future_ignore` |
| `avoid-future-tostring` | HAVE | `avoid_future_tostring` |
| `avoid-generics-shadowing` | HAVE | `avoid_generics_shadowing` |
| `avoid-getter-prefix` | HAVE | `prefer_no_getter_prefix` |
| `avoid-global-state` | HAVE | `avoid_global_state` |
| `avoid-high-cyclomatic-complexity` | HAVE | `avoid_high_cyclomatic_complexity` |
| `avoid-identical-exception-handling-blocks` | HAVE | `avoid_identical_exception_handling_blocks` |
| `avoid-if-with-many-branches` | HAVE | `avoid_if_with_many_branches` |
| `avoid-ignoring-return-values` | HAVE | `avoid_ignoring_return_values` |
| `avoid-immediately-invoked-functions` | HAVE | `avoid_immediately_invoked_functions` |
| `avoid-implicitly-nullable-extension-types` | HAVE | `avoid_implicitly_nullable_extension_types` |
| `avoid-importing-entrypoint-exports` | HAVE | `avoid_importing_entrypoint_exports` |
| `avoid-inconsistent-digit-separators` | HAVE | `avoid_inconsistent_digit_separators` |
| `avoid-incorrect-uri` | HAVE | `avoid_incorrect_uri` |
| `avoid-inferrable-type-arguments` | HAVE | `prefer_inferred_type_arguments` |
| `avoid-inverted-boolean-checks` | HAVE | `avoid_inverted_boolean_checks` |
| `avoid-keywords-in-wildcard-pattern` | HAVE | `avoid_keywords_in_wildcard_pattern` |
| `avoid-labels` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_labels.md) |
| `avoid-late-final-reassignment` | HAVE | `avoid_late_final_reassignment` |
| `avoid-late-keyword` | HAVE | `avoid_late_keyword` |
| `avoid-local-functions` | HAVE | `avoid_local_functions` |
| `avoid-long-functions` | HAVE | `avoid_long_functions` |
| `avoid-long-files` | HAVE | `avoid_long_length_files` / `avoid_very_long_length_files` |
| `avoid-long-parameter-list` | HAVE | `avoid_long_parameter_list` |
| `avoid-long-records` | HAVE | `avoid_long_records` |
| `avoid-map-keys-contains` | HAVE | `avoid_map_keys_contains` |
| `avoid-missed-calls` | HAVE | `avoid_missed_calls` |
| `avoid-missing-completer-stack-trace` | HAVE | `avoid_missing_completer_stack_trace` |
| `avoid-missing-enum-constant-in-map` | HAVE | `avoid_missing_enum_constant_in_map` |
| `avoid-missing-interpolation` | HAVE | `avoid_missing_interpolation` |
| `avoid-missing-test-files` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_missing_test_files.md) |
| `avoid-misused-test-matchers` | HAVE | `avoid_misused_test_matchers` |
| `avoid-misused-set-literals` | HAVE | `avoid_misused_set_literals` |
| `avoid-misused-wildcard-pattern` | PARTIAL | `avoid_keywords_in_wildcard_pattern` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_keywords_in_wildcard_pattern_dcm_parity.md) |
| `avoid-mixing-named-and-positional-fields` | HAVE | `avoid_mixing_named_and_positional_fields` |
| `avoid-multi-assignment` | HAVE | `avoid_multi_assignment` |
| `avoid-mutating-constant-collections` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_mutating_constant_collections.md) |
| `avoid-mutating-parameters` | HAVE | `avoid_parameter_mutation` |
| `avoid-negated-conditions` | HAVE | `avoid_negated_conditions` |
| `avoid-negations-in-equality-checks` | HAVE | `avoid_negations_in_equality_checks` |
| `avoid-nested-assignments` | HAVE | `avoid_nested_assignments` |
| `avoid-nested-conditional-expressions` | HAVE | `avoid_nested_conditional_expressions` |
| `avoid-nested-extension-types` | HAVE | `avoid_nested_extension_types` |
| `avoid-nested-futures` | HAVE | `avoid_nested_futures` |
| `avoid-nested-records` | HAVE | `avoid_nested_records` |
| `avoid-nested-shorthands` | HAVE | `avoid_nested_shorthands` |
| `avoid-nested-streams-and-futures` | HAVE | `avoid_nested_streams_and_futures` |
| `avoid-nested-switch-expressions` | HAVE | `avoid_nested_switch_expressions` |
| `avoid-nested-switches` | HAVE | `avoid_nested_switches` |
| `avoid-nested-try-statements` | HAVE | `avoid_nested_try_statements` |
| `avoid-never-passed-parameters` | TODO | TODO — see [proposal](../../../bugs/proposal_infra_avoid_never_passed_parameters.md) |
| `avoid-non-ascii-symbols` | HAVE | `avoid_non_ascii_symbols` |
| `avoid-non-empty-constructor-bodies` | HAVE | `avoid_non_empty_constructor_bodies` |
| `avoid-non-final-exception-class-fields` | HAVE | `avoid_non_final_exception_class_fields` |
| `avoid-non-null-assertion` | HAVE | `avoid_non_null_assertion` |
| `avoid-not-assignable-collection-types` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_not_assignable_collection_types.md) |
| `avoid-not-encodable-in-to-json` | HAVE | `avoid_not_encodable_in_to_json` |
| `avoid-nullable-interpolation` | HAVE | `avoid_nullable_interpolation` |
| `avoid-nullable-parameters-with-default-values` | HAVE | `avoid_nullable_parameters_with_default_values` |
| `avoid-nullable-tostring` | HAVE | `avoid_nullable_tostring` |
| `avoid-one-field-records` | HAVE | `avoid_one_field_records` |
| `avoid-only-rethrow` | HAVE | `avoid_only_rethrow` |
| `avoid-passing-async-when-sync-expected` | HAVE | `avoid_passing_async_when_sync_expected` |
| `avoid-passing-default-values` | HAVE | `avoid_passing_default_values` |
| `avoid-passing-self-as-argument` | HAVE | `avoid_passing_self_as_argument` |
| `avoid-positional-record-field-access` | HAVE | `avoid_positional_record_field_access` |
| `avoid-recursive-calls` | HAVE | `avoid_recursive_calls` |
| `avoid-recursive-tostring` | HAVE | `avoid_recursive_tostring` |
| `avoid-redundant-async` | HAVE | `avoid_redundant_async` |
| `avoid-redundant-else` | HAVE | `avoid_redundant_else` |
| `avoid-redundant-positional-field-name` | HAVE | `avoid_redundant_positional_field_name` |
| `avoid-redundant-pragma-inline` | HAVE | `avoid_redundant_pragma_inline` |
| `avoid-referencing-discarded-variables` | HAVE | `avoid_referencing_discarded_variables` |
| `avoid-referencing-subclasses` | HAVE | `avoid_referencing_subclasses` |
| `avoid-renaming-representation-getters` | HAVE | `avoid_renaming_representation_getters` |
| `avoid-returning-cascades` | HAVE | `avoid_returning_cascades` |
| `avoid-returning-void` | HAVE | `avoid_returning_void` |
| `avoid-self-assignment` | HAVE | `avoid_self_assignment` |
| `avoid-self-compare` | HAVE | `avoid_self_compare` |
| `avoid-sensitive-query-params` | HAVE | `avoid_auth_in_query_params` / `avoid_app_links_sensitive_params` |
| `avoid-shadowed-extension-methods` | HAVE | `avoid_shadowed_extension_methods` |
| `avoid-shadowing` | HAVE | `avoid_variable_shadowing` |
| `avoid-similar-names` | HAVE | `avoid_similar_names` |
| `avoid-single-field-destructuring` | HAVE | `avoid_single_field_destructuring` |
| `avoid-slow-collection-methods` | HAVE | `avoid_slow_collection_methods` |
| `avoid-stream-tostring` | HAVE | `avoid_stream_tostring` |
| `avoid-substring` | HAVE | `avoid_string_substring` |
| `avoid-suspicious-global-reference` | PARTIAL | `avoid_global_state` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_global_state_dcm_parity.md) |
| `avoid-suspicious-super-overrides` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_suspicious_super_overrides.md) |
| `avoid-throw-in-catch-block` | HAVE | `avoid_throw_in_catch_block` |
| `avoid-throw-objects-without-tostring` | HAVE | `avoid_throw_objects_without_tostring` |
| `avoid-throw` | PARTIAL | `avoid_throw_in_finally` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_throw_in_finally_dcm_parity.md) |
| `avoid-top-level-members-in-tests` | HAVE | `avoid_top_level_members_in_tests` |
| `avoid-type-casts` | HAVE | `avoid_type_casts` |
| `avoid-unassigned-fields` | HAVE | `avoid_unassigned_fields` |
| `avoid-unassigned-late-fields` | HAVE | `avoid_unassigned_late_fields` |
| `avoid-unassigned-local-variable` | PARTIAL | `avoid_unassigned_late_fields` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_unassigned_late_fields_dcm_parity.md) |
| `avoid-unassigned-stream-subscriptions` | HAVE | `avoid_unassigned_stream_subscriptions` |
| `avoid-uncaught-future-errors` | HAVE | `avoid_uncaught_future_errors` |
| `avoid-unconditional-break` | HAVE | `avoid_unconditional_break` |
| `avoid-unknown-pragma` | HAVE | `avoid_unknown_pragma` |
| `avoid-unmodified-loop-condition` | PARTIAL | `avoid_complex_loop_conditions` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_complex_loop_conditions_dcm_parity.md) |
| `avoid-unnecessary-block` | HAVE | `avoid_unnecessary_block` |
| `avoid-unnecessary-call` | HAVE | `avoid_unnecessary_call` |
| `avoid-unnecessary-collections` | HAVE | `avoid_unnecessary_collections` |
| `avoid-unnecessary-compare-to` | HAVE | `avoid_unnecessary_compare_to` |
| `avoid-unnecessary-conditionals` | HAVE | `avoid_unnecessary_conditionals` |
| `avoid-unnecessary-constructor` | HAVE | `avoid_unnecessary_constructor` |
| `avoid-unnecessary-continue` | HAVE | `avoid_unnecessary_continue` |
| `avoid-unnecessary-digit-separators` | HAVE | `avoid_unnecessary_digit_separators` |
| `avoid-unnecessary-enum-arguments` | HAVE | `avoid_unnecessary_enum_arguments` |
| `avoid-unnecessary-enum-prefix` | HAVE | `avoid_unnecessary_enum_prefix` |
| `avoid-unnecessary-extends` | HAVE | `avoid_unnecessary_extends` |
| `avoid-unnecessary-factory` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_unnecessary_factory.md) |
| `avoid-unnecessary-futures` | HAVE | `avoid_unnecessary_futures` |
| `avoid-unnecessary-getter` | HAVE | `avoid_unnecessary_getter` |
| `avoid-unnecessary-if` | HAVE | `avoid_unnecessary_if` |
| `avoid-unnecessary-late-fields` | HAVE | `avoid_unnecessary_late_fields` |
| `avoid-unnecessary-length-check` | HAVE | `avoid_unnecessary_length_check` |
| `avoid-unnecessary-local-late` | HAVE | `avoid_unnecessary_local_late` |
| `avoid-unnecessary-local-variable` | HAVE | `avoid_unnecessary_local_variable` |
| `avoid-unnecessary-negations` | HAVE | `avoid_unnecessary_negations` |
| `avoid-unnecessary-null-aware-elements` | HAVE | `avoid_unnecessary_null_aware_elements` |
| `avoid-unnecessary-nullable-fields` | HAVE | `avoid_unnecessary_nullable_fields` |
| `avoid-unnecessary-nullable-parameters` | HAVE | `avoid_unnecessary_nullable_parameters` |
| `avoid-unnecessary-nullable-return-type` | HAVE | `avoid_unnecessary_nullable_return_type` |
| `avoid-unnecessary-overrides` | HAVE | `avoid_unnecessary_overrides` |
| `avoid-unnecessary-parentheses` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_unnecessary_parentheses.md) |
| `avoid-unnecessary-patterns` | HAVE | `avoid_unnecessary_patterns` |
| `avoid-unnecessary-reassignment` | HAVE | `avoid_unnecessary_reassignment` |
| `avoid-unnecessary-return` | HAVE | `avoid_unnecessary_return` |
| `avoid-unnecessary-statements` | HAVE | `avoid_unnecessary_statements` |
| `avoid-unnecessary-super` | HAVE | `avoid_unnecessary_super` |
| `avoid-unnecessary-type-assertions` | HAVE | `avoid_unnecessary_type_assertions` |
| `avoid-unnecessary-type-casts` | HAVE | `avoid_unnecessary_type_casts` |
| `avoid-unreachable-for-loop` | HAVE | `avoid_unreachable_for_loop` |
| `avoid-unrelated-type-assertions` | HAVE | `avoid_unrelated_type_assertions` |
| `avoid-unrelated-type-casts` | HAVE | `avoid_unrelated_type_casts` |
| `avoid-unremovable-callbacks-in-listeners` | HAVE | `avoid_unremovable_callbacks_in_listeners` |
| `avoid-unsafe-collection-methods` | HAVE | `avoid_unsafe_collection_methods` |
| `avoid-unsafe-reduce` | HAVE | `avoid_unsafe_reduce` |
| `avoid-unused-after-null-check` | HAVE | `avoid_unused_after_null_check` |
| `avoid-unused-assignment` | HAVE | `avoid_unused_assignment` |
| `avoid-unused-generics` | HAVE | `avoid_unused_generics` |
| `avoid-unused-instances` | HAVE | `avoid_unused_instances` |
| `avoid-unused-local-variable` | TODO | TODO — see [proposal](../../../bugs/proposal_infra_avoid_unused_local_variable.md) |
| `avoid-unused-parameters` | HAVE | `avoid_unused_parameters` |
| `avoid-weak-cryptographic-algorithms` | HAVE | `avoid_weak_cryptographic_algorithms` |
| `avoid-wildcard-cases-with-enums` | HAVE | `avoid_wildcard_cases_with_enums` |
| `avoid-wildcard-cases-with-sealed-classes` | HAVE | `avoid_wildcard_cases_with_sealed_classes` |
| `banned-usage` | HAVE | `banned_identifier_usage` |
| `binary-expression-operand-order` | HAVE | `binary_expression_operand_order` |
| `dispose-class-fields` | HAVE | `dispose_class_fields` |
| `double-literal-format` | HAVE | `double_literal_format` |
| `enum-constants-ordering` | HAVE | `enum_constants_ordering` |
| `format-comment` | HAVE | `format_comment_style` |
| `format-test-name` | HAVE | `format_test_name` |
| `function-always-returns-null` | HAVE | `function_always_returns_null` |
| `function-always-returns-same-value` | HAVE | `function_always_returns_same_value` |
| `handle-throwing-invocations` | HAVE | `handle_throwing_invocations` |
| `initializers-ordering` | TODO | TODO — see [proposal](../../../bugs/proposal_initializers_ordering.md) |
| `map-keys-ordering` | HAVE | `map_keys_ordering` |
| `match-base-class-default-value` | HAVE | `match_base_class_default_value` |
| `match-class-name-pattern` | HAVE | `match_class_name_pattern` |
| `match-getter-setter-field-names` | HAVE | `match_getter_setter_field_names` |
| `match-lib-folder-structure` | HAVE | `match_lib_folder_structure` |
| `match-positional-field-names-on-assignment` | HAVE | `match_positional_field_names_on_assignment` |
| `max-imports` | HAVE | `limit_max_imports` |
| `max-statements` | PARTIAL | `avoid_long_functions` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_long_functions_dcm_parity.md) |
| `member-ordering` | HAVE | `prefer_member_ordering` |
| `missing-test-assertion` | HAVE | `missing_test_assertion` |
| `missing-use-result-annotation` | HAVE | `missing_use_result_annotation` |
| `move-records-to-typedefs` | HAVE | `move_records_to_typedefs` |
| `move-variable-closer-to-its-usage` | HAVE | `move_variable_closer_to_its_usage` |
| `move-variable-outside-iteration` | HAVE | `move_variable_outside_iteration` |
| `newline-before-break` | TODO | TODO — see [proposal](../../../bugs/proposal_newline_before_break.md) |
| `newline-before-case` | HAVE | `prefer_blank_line_before_case` |
| `newline-before-constructor` | HAVE | `prefer_blank_line_before_constructor` |
| `newline-before-continue` | TODO | TODO — see [proposal](../../../bugs/proposal_newline_before_continue.md) |
| `newline-before-method` | HAVE | `prefer_blank_line_before_method` |
| `newline-before-return` | HAVE | `NewlineBeforeReturnRule` |
| `newline-before-throw` | TODO | TODO — see [proposal](../../../bugs/proposal_newline_before_throw.md) |
| `no-boolean-literal-compare` | HAVE | `no_boolean_literal_compare` |
| `no-empty-block` | HAVE | `no_empty_block` |
| `no-empty-string` | HAVE | `no_empty_string` |
| `no-equal-arguments` | HAVE | `no_equal_arguments` |
| `no-equal-conditions` | HAVE | `no_equal_conditions` |
| `no-equal-nested-conditions` | HAVE | `no_equal_nested_conditions` |
| `no-equal-switch-case` | HAVE | `no_equal_switch_case` |
| `no-equal-switch-expression-cases` | HAVE | `no_equal_switch_expression_cases` |
| `no-equal-then-else` | HAVE | `no_equal_then_else` |
| `no-magic-number` | HAVE | `no_magic_number` |
| `no-magic-string` | HAVE | `no_magic_string` |
| `no-object-declaration` | HAVE | `no_object_declaration` |
| `parameters-ordering` | HAVE | `enforce_parameters_ordering` |
| `pass-correct-accepted-type` | HAVE | `pass_correct_accepted_type` |
| `pass-optional-argument` | HAVE | `pass_optional_argument` |
| `pattern-fields-ordering` | HAVE | `prefer_sorted_pattern_fields` |
| `prefer-abstract-final-static-class` | HAVE | `prefer_abstract_final_static_class` |
| `prefer-add-all` | HAVE | `prefer_add_all` |
| `prefer-addition-subtraction-assignments` | HAVE | `prefer_addition_subtraction_assignments` |
| `prefer-any-or-every` | HAVE | `prefer_any_or_every` |
| `prefer-assert-initializers-first` | HAVE | `prefer_asserts_in_initializer_lists_safe` |
| `prefer-assigning-await-expressions` | HAVE | `prefer_assigning_await_expressions` |
| `prefer-async-await` | HAVE | `prefer_async_await` |
| `prefer-boolean-prefixes` | HAVE | `prefer_boolean_prefixes` |
| `prefer-both-inlining-annotations` | HAVE | `prefer_both_inlining_annotations` |
| `prefer-bytes-builder` | HAVE | `prefer_bytes_builder` |
| `prefer-class-destructuring` | HAVE | `prefer_class_destructuring` |
| `prefer-commenting-analyzer-ignores` | HAVE | `prefer_commenting_analyzer_ignores` |
| `prefer-commenting-future-delayed` | HAVE | `prefer_commenting_future_delayed` |
| `prefer-compound-assignment-operators` | HAVE | `prefer_compound_assignment_operators` |
| `prefer-conditional-expressions` | HAVE | `prefer_conditional_expressions` |
| `prefer-contains` | HAVE | `prefer_list_contains` |
| `prefer-correct-callback-field-name` | HAVE | `prefer_correct_callback_field_name` |
| `prefer-correct-error-name` | HAVE | `prefer_correct_error_name` |
| `prefer-correct-for-loop-increment` | HAVE | `prefer_correct_for_loop_increment` |
| `prefer-correct-future-return-type` | HAVE | `prefer_correct_future_return_type` |
| `prefer-correct-handler-name` | HAVE | `prefer_correct_handler_name` |
| `prefer-correct-identifier-length` | HAVE | `prefer_correct_identifier_length` |
| `prefer-correct-json-casts` | HAVE | `prefer_correct_json_casts` |
| `prefer-correct-mutated` | TODO | TODO — see [proposal](../../../bugs/proposal_infra_prefer_correct_mutated.md) |
| `prefer-correct-setter-parameter-name` | HAVE | `prefer_correct_setter_parameter_name` |
| `prefer-correct-stream-return-type` | HAVE | `prefer_correct_stream_return_type` |
| `prefer-correct-switch-length` | HAVE | `prefer_correct_switch_length` |
| `prefer-correct-test-file-name` | HAVE | `prefer_correct_test_file_name` |
| `prefer-correct-throws` | HAVE | `prefer_correct_throws` |
| `prefer-correct-type-name` | HAVE | `prefer_correct_type_name` |
| `prefer-declaring-const-constructor` | HAVE | `prefer_declaring_const_constructor` |
| `prefer-digit-separators` | HAVE | `prefer_digit_separators` |
| `prefer-early-return` | HAVE | `prefer_early_return` |
| `prefer-enums-by-name` | HAVE | `prefer_enums_by_name` |
| `prefer-expect-later` | HAVE | `prefer_expect_later` |
| `prefer-explicit-function-type` | HAVE | `prefer_explicit_function_type` |
| `prefer-explicit-parameter-names` | HAVE | `prefer_explicit_parameter_names` |
| `prefer-explicit-type-arguments` | HAVE | `prefer_explicit_type_arguments` |
| `prefer-extracting-function-callbacks` | HAVE | `prefer_extracting_function_callbacks` |
| `prefer-first` | HAVE | `prefer_list_first` |
| `prefer-for-in` | HAVE | `prefer_for_in` |
| `prefer-getter-over-method` | HAVE | `prefer_getter_over_method` |
| `prefer-immediate-return` | HAVE | `prefer_immediate_return` |
| `prefer-initializing-formals` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_initializing_formals.md) |
| `prefer-iterable-of` | HAVE | `prefer_iterable_of` |
| `prefer-last` | HAVE | `prefer_list_last` |
| `prefer-match-file-name` | HAVE | `prefer_match_file_name` |
| `prefer-moving-to-variable` | HAVE | `prefer_moving_to_variable` |
| `prefer-named-boolean-parameters` | HAVE | `prefer_named_boolean_parameters` |
| `prefer-named-imports` | HAVE | `prefer_named_imports` |
| `prefer-named-parameters` | HAVE | `prefer_named_parameters` |
| `prefer-non-nulls` | PARTIAL | `avoid_unnecessary_nullable_parameters` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_unnecessary_nullable_parameters_dcm_parity.md) |
| `prefer-null-aware-elements` | HAVE | `prefer_null_aware_elements` |
| `prefer-null-aware-spread` | HAVE | `prefer_null_aware_spread` |
| `prefer-overriding-parent-equality` | HAVE | `prefer_overriding_parent_equality` |
| `prefer-parentheses-with-if-null` | HAVE | `prefer_parentheses_with_if_null` |
| `prefer-prefixed-global-constants` | HAVE | `prefer_prefixed_global_constants` |
| `prefer-private-extension-type-field` | HAVE | `prefer_private_extension_type_field` |
| `prefer-private-named-parameters` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_private_named_parameters.md) |
| `prefer-public-exception-classes` | HAVE | `prefer_public_exception_classes` |
| `prefer-pushing-conditional-expressions` | HAVE | `prefer_pushing_conditional_expressions` |
| `prefer-random-secure` | HAVE | `prefer_secure_random_for_crypto` |
| `prefer-redirecting-superclass-constructor` | HAVE | `prefer_redirecting_superclass_constructor` |
| `prefer-return-await` | HAVE | `prefer_return_await` |
| `prefer-returning-condition` | HAVE | `prefer_returning_condition` |
| `prefer-returning-conditional-expressions` | HAVE | `prefer_returning_conditional_expressions` |
| `prefer-returning-shorthands` | HAVE | `prefer_arrow_functions` (stylistic tier; supersedes the former rule) |
| `prefer-shorthands-with-constructors` | HAVE | `prefer_shorthands_with_constructors` |
| `prefer-shorthands-with-enums` | HAVE | `prefer_shorthands_with_enums` |
| `prefer-shorthands-with-static-fields` | HAVE | `prefer_shorthands_with_static_fields` |
| `prefer-simpler-boolean-expressions` | HAVE | `prefer_simpler_boolean_expressions` |
| `prefer-simpler-patterns-null-check` | HAVE | `prefer_simpler_patterns_null_check` |
| `prefer-single-declaration-per-file` | HAVE | `prefer_single_declaration_per_file` |
| `prefer-specific-cases-first` | HAVE | `prefer_specific_cases_first` |
| `prefer-specifying-future-value-type` | HAVE | `prefer_specifying_future_value_type` |
| `prefer-static-class` | HAVE | `prefer_static_class` |
| `prefer-static-method` | HAVE | `prefer_static_method` |
| `prefer-switch-expression` | HAVE | `prefer_switch_expression` |
| `prefer-switch-with-enums` | HAVE | `prefer_switch_with_enums` |
| `prefer-switch-with-sealed-classes` | HAVE | `prefer_switch_with_sealed_classes` |
| `prefer-test-matchers` | HAVE | `prefer_test_matchers` |
| `prefer-test-structure` | HAVE | `prefer_test_structure` |
| `prefer-trailing-comma` | HAVE | `prefer_trailing_comma` |
| `prefer-type-over-var` | HAVE | `prefer_type_over_var` |
| `prefer-typedefs-for-callbacks` | HAVE | `prefer_typedefs_for_callbacks` |
| `prefer-unique-test-names` | HAVE | `prefer_unique_test_names` |
| `prefer-unmodifiable-of` | PARTIAL | `prefer_unmodifiable_collections` — TODO extend, see [proposal](../../../bugs/proposal_extend_prefer_unmodifiable_collections_dcm_parity.md) |
| `prefer-unwrapping-future-or` | HAVE | `prefer_unwrapping_future_or` |
| `prefer-visible-for-testing-on-members` | HAVE | `prefer_visible_for_testing_on_members` |
| `prefer-wildcard-pattern` | HAVE | `prefer_wildcard_pattern` |
| `record-fields-ordering` | HAVE | `prefer_sorted_record_fields` |
| `require-atomic-async-updates` | PARTIAL | `require_mounted_check_after_await` — TODO extend, see [proposal](../../../bugs/proposal_extend_require_mounted_check_after_await_dcm_parity.md) |
| `tag-name` | HAVE | `prefer_kebab_tag_name` |
| `unnecessary-trailing-comma` | HAVE | `unnecessary_trailing_comma` |
| `use-existing-destructuring` | HAVE | `use_existing_destructuring` |
| `use-existing-variable` | HAVE | `use_existing_variable` |

### Flutter

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `add-copy-with` | TODO | TODO — see [proposal](../../../bugs/proposal_add_copy_with.md) |
| `always-pass-global-key` | TODO | TODO — see [proposal](../../../bugs/proposal_always_pass_global_key.md) |
| `always-remove-listener` | HAVE | `always_remove_listener` |
| `avoid-border-all` | HAVE | `avoid_border_all` |
| `avoid-disposing-late-fields` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_disposing_late_fields.md) |
| `avoid-empty-setstate` | HAVE | `avoid_empty_setstate` |
| `avoid-expanded-as-spacer` | HAVE | `avoid_expanded_as_spacer` |
| `avoid-flexible-outside-flex` | HAVE | `avoid_flexible_outside_flex` |
| `avoid-focusable-offstage` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_focusable_offstage.md) |
| `avoid-incomplete-copy-with` | HAVE | `avoid_incomplete_copy_with` |
| `avoid-incorrect-image-opacity` | HAVE | `avoid_incorrect_image_opacity` |
| `avoid-inherited-widget-in-initstate` | HAVE | `avoid_inherited_widget_in_initstate` |
| `avoid-late-context` | HAVE | `avoid_late_context` |
| `avoid-merge-semantics-list-tile` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_merge_semantics_list_tile.md) |
| `avoid-missing-controller` | HAVE | `require_form_field_controller` |
| `provide-image-semantic-label` | HAVE | `require_image_semantics` |
| `avoid-mounted-in-setstate` | HAVE | `avoid_mounted_in_setstate` |
| `avoid-nested-interactive-semantics` | PARTIAL | `avoid_merged_semantics_hiding_info` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_merged_semantics_hiding_info_dcm_parity.md) |
| `avoid-recursive-widget-calls` | HAVE | `avoid_recursive_widget_calls` |
| `avoid-redundant-semantics-wrapper` | HAVE | `avoid_redundant_semantics` |
| `avoid-returning-widgets` | HAVE | `avoid_returning_widgets` |
| `avoid-shrink-wrap-in-lists` | HAVE | `avoid_shrink_wrap_in_lists` |
| `avoid-single-child-column-or-row` | HAVE | `avoid_single_child_column_row` |
| `avoid-state-constructors` | HAVE | `avoid_state_constructors` |
| `avoid-undisposed-instances` | HAVE | `avoid_undisposed_instances` |
| `avoid-unnecessary-gesture-detector` | HAVE | `avoid_unnecessary_gesture_detector` |
| `avoid-stateless-widget-initialized-fields` | HAVE | `avoid_stateless_widget_initialized_fields` |
| `avoid-unnecessary-overrides-in-state` | HAVE | `avoid_unnecessary_overrides_in_state` |
| `avoid-unnecessary-setstate` | HAVE | `avoid_unnecessary_setstate` |
| `avoid-unnecessary-stateful-widgets` | HAVE | `avoid_unnecessary_stateful_widgets` |
| `avoid-unrestricted-javascript` | HAVE | `avoid_webview_javascript_enabled` |
| `avoid-unrestricted-navigation` | HAVE | `require_webview_navigation_delegate` |
| `avoid-wrapping-in-padding` | HAVE | `avoid_wrapping_in_padding` |
| `check-for-equals-in-render-object-setters` | HAVE | `check_for_equals_in_render_object_setters` |
| `consistent-update-render-object` | HAVE | `consistent_update_render_object` |
| `dispose-fields` | HAVE | `dispose_widget_fields` / `dispose_class_fields` |
| `keep-state-below-its-widget` | TODO | TODO — see [proposal](../../../bugs/proposal_keep_state_below_its_widget.md) |
| `pass-existing-future-to-future-builder` | HAVE | `pass_existing_future_to_future_builder` |
| `pass-existing-stream-to-stream-builder` | HAVE | `pass_existing_stream_to_stream_builder` |
| `prefer-action-button-tooltip` | HAVE | `prefer_action_button_tooltip` |
| `prefer-align-over-container` | HAVE | `prefer_align_over_container` |
| `prefer-async-callback` | HAVE | `prefer_async_callback` |
| `prefer-center-over-align` | HAVE | `prefer_center_over_align` |
| `prefer-compute-over-isolate-run` | HAVE | `prefer_compute_over_isolate_run` |
| `prefer-const-border-radius` | HAVE | `prefer_const_border_radius` |
| `prefer-constrained-box-over-container` | HAVE | `prefer_constrained_box_over_container` |
| `prefer-container` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_container.md) |
| `prefer-correct-edge-insets-constructor` | HAVE | `prefer_correct_edge_insets_constructor` |
| `prefer-correct-static-icon-provider` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_correct_static_icon_provider.md) |
| `prefer-dedicated-media-query-methods` | PARTIAL | `avoid_deprecated_use_inherited_media_query` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_deprecated_use_inherited_media_query_dcm_parity.md) |
| `prefer-define-hero-tag` | HAVE | `prefer_define_hero_tag` |
| `prefer-extracting-callbacks` | HAVE | `prefer_extracting_callbacks` |
| `prefer-for-loop-in-children` | HAVE | `prefer_for_loop_in_children` |
| `prefer-haptic-feedback-on-interaction` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_haptic_feedback_on_interaction.md) |
| `prefer-icon-button-tooltip` | HAVE | `avoid_icon_buttons_without_tooltip` |
| `prefer-localized-semantic-labels` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_localized_semantic_labels.md) |
| `prefer-padding-over-container` | HAVE | `prefer_padding_over_container` |
| `prefer-semantics-header` | HAVE | `require_heading_semantics` |
| `prefer-single-setstate` | HAVE | `prefer_single_setstate` |
| `prefer-single-widget-per-file` | HAVE | `prefer_single_widget_per_file` |
| `prefer-sized-box-square` | HAVE | `prefer_sized_box_square` |
| `prefer-sliver-prefix` | HAVE | `prefer_sliver_prefix` |
| `prefer-spacing` | HAVE | `prefer_spacing_over_sizedbox` |
| `prefer-text-rich` | HAVE | `prefer_text_rich` |
| `prefer-transform-over-container` | HAVE | `prefer_transform_over_container` |
| `prefer-using-list-view` | HAVE | `prefer_using_list_view` |
| `prefer-void-callback` | HAVE | `prefer_void_callback` |
| `prefer-widget-private-members` | HAVE | `prefer_widget_private_members` |
| `proper-super-calls` | HAVE | `proper_super_calls` |
| `provide-autofill-hints` | HAVE | `require_autofill_hints` |
| `provide-icon-semantic-label` | HAVE | `require_semantic_label_icons` |
| `provide-input-field-label` | TODO | TODO — see [proposal](../../../bugs/proposal_provide_input_field_label.md) |
| `provide-progress-indicator-semantics` | TODO | TODO — see [proposal](../../../bugs/proposal_provide_progress_indicator_semantics.md) |
| `provide-slider-semantic-formatter` | TODO | TODO — see [proposal](../../../bugs/proposal_provide_slider_semantic_formatter.md) |
| `use-closest-build-context` | HAVE | `use_closest_build_context` |
| `use-existing-widget` | TODO | TODO — see [proposal](../../../bugs/proposal_use_existing_widget.md) |
| `use-setstate-synchronously` | HAVE | `use_setstate_synchronously` |

### Provider

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-instantiating-in-value-provider` | HAVE | `avoid_instantiating_in_value_provider` |
| `avoid-read-inside-build` | PARTIAL | `avoid_ref_read_inside_build` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_ref_read_inside_build_dcm_parity.md) |
| `avoid-watch-outside-build` | PARTIAL | `avoid_ref_watch_outside_build` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_ref_watch_outside_build_dcm_parity.md) |
| `dispose-providers` | HAVE | `dispose_provider_instances` / `require_provider_dispose` |
| `prefer-immutable-selector-value` | HAVE | `prefer_immutable_selector_value` |
| `prefer-multi-provider` | HAVE | `prefer_multi_provider` |
| `prefer-nullable-provider-types` | HAVE | `prefer_nullable_provider_types` |
| `prefer-provider-extensions` | HAVE | `prefer_provider_extensions` |

### Bloc

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-bloc-public-fields` | HAVE | `avoid_bloc_public_fields` |
| `avoid-bloc-public-methods` | HAVE | `avoid_bloc_public_methods` |
| `avoid-cubits` | HAVE | `avoid_cubit_usage` |
| `avoid-duplicate-bloc-event-handlers` | HAVE | `avoid_duplicate_bloc_event_handlers` |
| `avoid-empty-build-when` | HAVE | `avoid_empty_build_when` |
| `avoid-existing-instances-in-bloc-provider` | HAVE | `avoid_existing_instances_in_bloc_provider` |
| `avoid-instantiating-in-bloc-value-provider` | HAVE | `avoid_instantiating_in_bloc_value_provider` |
| `avoid-passing-bloc-to-bloc` | HAVE | `avoid_passing_bloc_to_bloc` |
| `avoid-passing-build-context-to-blocs` | HAVE | `avoid_passing_build_context_to_blocs` |
| `avoid-returning-value-from-cubit-methods` | HAVE | `avoid_returning_value_from_cubit_methods` |
| `check-is-not-closed-after-async-gap` | HAVE | `check_is_not_closed_after_async_gap` |
| `emit-new-bloc-state-instances` | HAVE | `emit_new_bloc_state_instances` |
| `handle-bloc-event-subclasses` | PARTIAL | `require_bloc_event_sealed` — TODO extend, see [proposal](../../../bugs/proposal_extend_require_bloc_event_sealed_dcm_parity.md) |
| `prefer-bloc-event-suffix` | HAVE | `prefer_bloc_event_suffix` |
| `prefer-bloc-extensions` | HAVE | `prefer_bloc_extensions` |
| `prefer-bloc-state-suffix` | HAVE | `prefer_bloc_state_suffix` |
| `prefer-correct-bloc-provider` | HAVE | `prefer_correct_bloc_provider` |
| `prefer-immutable-bloc-events` | HAVE | `prefer_immutable_bloc_events` |
| `prefer-immutable-bloc-state` | HAVE | `prefer_immutable_bloc_state` |
| `prefer-multi-bloc-provider` | HAVE | `prefer_multi_bloc_provider` |
| `prefer-sealed-bloc-events` | HAVE | `prefer_sealed_bloc_events` |
| `prefer-sealed-bloc-state` | HAVE | `prefer_sealed_bloc_state` |

### Riverpod

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-assigning-notifiers` | HAVE | `avoid_assigning_notifiers` |
| `avoid-calling-notifier-members-inside-build` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_calling_notifier_members_inside_build.md) |
| `avoid-notifier-constructors` | HAVE | `avoid_notifier_constructors` |
| `avoid-nullable-async-value-pattern` | HAVE | `avoid_nullable_async_value_pattern` |
| `avoid-public-notifier-properties` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_public_notifier_properties.md) |
| `avoid-ref-inside-state-dispose` | HAVE | `avoid_ref_inside_state_dispose` |
| `avoid-ref-read-inside-build` | HAVE | `avoid_ref_read_inside_build` |
| `avoid-ref-watch-outside-build` | HAVE | `avoid_ref_watch_outside_build` |
| `avoid-unnecessary-consumer-widgets` | HAVE | `avoid_unnecessary_consumer_widgets` |
| `dispose-provided-instances` | HAVE | `dispose_provided_instances` |
| `prefer-correct-notifier-file-name` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_correct_notifier_file_name.md) |
| `prefer-correct-provider-file-name` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_correct_provider_file_name.md) |
| `prefer-immutable-provider-arguments` | HAVE | `prefer_immutable_provider_arguments` |
| `prefer-riverpod-notifier-suffix` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_riverpod_notifier_suffix.md) |
| `prefer-riverpod-provider-suffix` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_riverpod_provider_suffix.md) |
| `prefer-single-notifier-per-file` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_single_notifier_per_file.md) |
| `use-ref-and-state-synchronously` | HAVE | `use_ref_and_state_synchronously` |
| `use-ref-read-synchronously` | HAVE | `use_ref_read_synchronously` |

### Equatable

| DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `add-equatable-props` | HAVE | `list_all_equatable_fields` |
| `avoid-equatable-call-on-equality-base-class` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_equatable_call_on_equality_base_class.md) |
| `prefer-equatable-key-name` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_equatable_key_name.md) |
| `sort-equatable-props` | TODO | TODO — see [proposal](../../../bugs/proposal_sort_equatable_props.md) |

## What You Gain

### Rules DCM Doesn't Have

saropa_lints includes Flutter-specific rules beyond DCM's scope:

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

DCM provides some features saropa_lints doesn't focus on:

<!-- cspell:ignore cloc Halstead -->
| DCM Feature | Alternative |
|-------------|-------------|
| Cyclomatic complexity metrics | Use `dart analyze` or IDE plugins |
| Lines of code metrics | Use `cloc` or IDE extensions |
| Technical debt estimation | Manual review or other tools |
| HTML/JSON reports | Custom lint output formatting |
| Halstead metrics | Specialized metrics tools |

If metrics are critical, consider keeping DCM alongside saropa_lints.

## Suppressing Rules

The syntax is similar:

```dart
// DCM style
// ignore: avoid-returning-widgets

// saropa_lints style
// ignore: avoid_returning_widgets
```

Note: DCM uses hyphens, saropa_lints uses underscores in rule names.

## Configuration Differences

### DCM's Metric Thresholds

```yaml
# DCM style
dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
    maximum-nesting-level: 5
```

### saropa_lints Tier Selection

```bash
# Generate configuration for your chosen tier
dart run saropa_lints:init --tier professional

# Or for a different tier
dart run saropa_lints:init --tier recommended
```

After generation, customize specific rules in analysis_options.yaml:

```yaml
custom_lint:
  rules:
    - avoid_magic_numbers: false  # Change to false to disable
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
