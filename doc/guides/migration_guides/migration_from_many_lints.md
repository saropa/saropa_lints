# Migrating from many_lints

This guide helps you migrate from [`many_lints`](https://pub.dev/packages/many_lints) to
`saropa_lints`.

## Why Migrate?

| Feature | many_lints | saropa_lints |
|---------|-----------|--------------|
| **Rule count** | 261 rules + 106 quick fixes | 2300+ custom rules, 221+ quick fixes |
| **Focus** | General Dart/Flutter code quality, Bloc/Riverpod, fpdart | Security, accessibility, performance, and library-specific analysis at much greater breadth |
| **Architecture** | `analysis_server_plugin` (native, no `custom_lint`) | `custom_lint` plugin |
| **Configuration** | Presets (`none`/`core`/`recommended`/`opinionated`/`pedantic`), per-rule `include`/`exclude`/`message`/options | 5 progressive tiers |
| **Assists** | 13 lightbulb-menu refactorings (fpdart chain conversions, null-check-to-pattern, etc.) | N/A — saropa_lints does not offer non-diagnostic assists |

`many_lints` is a large, well-maintained plugin with strong overlap with saropa_lints on general
Dart/Flutter hygiene, and it goes further than saropa in three areas saropa doesn't cover at all:
the `fpdart` functional-programming ecosystem (`Either`/`Option`/`Task`/`TaskEither`/`Do`
notation, 23 rules), generic project-configurable ban/require engines (`avoid_banned_*`,
`use_class_prefix`/`use_class_suffix`, `match_pattern`), and lightbulb-menu assists that aren't
tied to a diagnostic at all. See [GAP_ANALYSIS.md](../../../plans/GAP_ANALYSIS.md) Gap Themes 1,
2, 3, 9, 10, and 11 for the underlying research behind these gaps.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before — many_lints needs no pubspec.yaml entry at all,
# it's declared entirely under the top-level `plugins:` key.

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
plugins:
  many_lints: ^1.2.0

many_lints:
  preset: recommended
  rules:
    prefer_type_over_var: true
    avoid_only_rethrow: false

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

`many_lints`' fpdart family, generic ban engines, and assists have no saropa_lints equivalent.
If your project uses `fpdart` or relies on the configurable ban rules, keep `many_lints` running
alongside saropa_lints — both are plugins under the `plugins:`/`custom_lint` umbrella and do not
conflict:

```yaml
# analysis_options.yaml
plugins:
  many_lints:
    version: ^1.2.0

analyzer:
  plugins:
    - custom_lint
```

## Choosing a Tier

many_lints' presets are cumulative rule counts; saropa_lints uses progressive tiers:

| many_lints Preset | Rules | saropa_lints Tier | Description |
|--------------------|------:|--------------------|--------------|
| `core` | 35 | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| `recommended` | 97 | **Recommended** (~900 rules) | Balanced coverage |
| `opinionated` | 185 | **Professional** (~1600 rules) | Enterprise-grade |
| `pedantic` | 242 | **Comprehensive** (~2100 rules) | Quality obsessed |
| — | — | **Pedantic** (1450+ rules) | Every single rule |

**Start with `recommended`** — it provides broad coverage without overwhelming noise.

## Rule Mapping

Coverage: 266 rules — 198 HAVE (74%), 7 PARTIAL, 57 TODO (21%)
[nikoro.github.io/many_lints/docs/rules](https://nikoro.github.io/many_lints/docs/rules/).

| many_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `always_pass_global_key` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_require_global_key_for_widget.md) |
| `always_remove_listener` | HAVE | `always_remove_listener` |
| `arguments_ordering` | HAVE | `prefer_arguments_ordering` |
| `async_value_nullable_pattern` | HAVE | `avoid_nullable_async_value_pattern` |
| `avoid_accessing_collections_by_constant_index` | HAVE | `avoid_accessing_collections_by_constant_index` |
| `avoid_accessing_other_classes_private_members` | HAVE | `avoid_accessing_other_classes_private_members` |
| `avoid_ad_hoc_left_type` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_dollar_outside_do_frame.md) (fpdart family, see Gap Theme 1) |
| `avoid_banned_annotations` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_annotations.md) |
| `avoid_banned_exports` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_exports.md) |
| `avoid_banned_imports` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_imports.md) |
| `avoid_banned_names` | PARTIAL | `banned_identifier_usage` — TODO extend, see [proposal](../../../bugs/tier_3_infrastructure/proposal_extend_banned_identifier_usage_dcm_parity.md) |
| `avoid_banned_types` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_types.md) |
| `avoid_bare_await_in_do` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_bare_await_in_do.md) (fpdart family, see Gap Theme 1) |
| `avoid_bloc_public_methods` | HAVE | `avoid_bloc_public_methods` |
| `avoid_border_all` | HAVE | `avoid_border_all` |
| `avoid_build_context_in_providers` | HAVE | `avoid_build_context_in_providers` |
| `avoid_cascade_after_if_null` | HAVE | `avoid_cascade_after_if_null` |
| `avoid_catch_error` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_avoid_catch_error.md) |
| `avoid_collapsible_if` | HAVE | `avoid_collapsible_if` |
| `avoid_collection_equality_checks` | HAVE | `avoid_collection_equality_checks` |
| `avoid_collection_methods_with_unrelated_types` | HAVE | `avoid_collection_methods_with_unrelated_types` |
| `avoid_commented_out_code` | HAVE | `prefer_no_commented_out_code` |
| `avoid_complex_conditions` | HAVE | `avoid_complex_conditions` |
| `avoid_conditional_hooks` | HAVE | `avoid_conditional_hooks` |
| `avoid_constant_conditions` | HAVE | `avoid_constant_conditions` |
| `avoid_constant_switches` | HAVE | `avoid_constant_switches` |
| `avoid_contradictory_expressions` | HAVE | `avoid_contradictory_expressions` |
| `avoid_deep_nesting` | HAVE | `avoid_deep_nesting` |
| `avoid_deep_widget_nesting` | HAVE | `avoid_deep_widget_nesting` |
| `avoid_default_tostring` | HAVE | `avoid_default_tostring` |
| `avoid_dollar_outside_do_frame` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_dollar_outside_do_frame.md) (fpdart family, see Gap Theme 1) |
| `avoid_dst_unsafe_date_arithmetic` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_dst_unsafe_date_arithmetic.md) |
| `avoid_duplicate_bloc_event_handlers` | HAVE | `avoid_duplicate_bloc_event_handlers` |
| `avoid_duplicate_cascades` | HAVE | `avoid_duplicate_cascades` |
| `avoid_duplicate_collection_elements` | HAVE | `avoid_duplicate_number_elements` / `avoid_duplicate_string_elements` / `avoid_duplicate_object_elements` |
| `avoid_duplicate_mixins` | HAVE | `avoid_duplicate_mixins` |
| `avoid_either_of_future` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_either_of_future.md) (fpdart family, see Gap Theme 1) |
| `avoid_empty_catch` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_empty_catch.md) |
| `avoid_empty_setstate` | HAVE | `avoid_empty_setstate` |
| `avoid_empty_spread` | HAVE | `avoid_empty_spread` |
| `avoid_equal_expressions` | HAVE | `avoid_equal_expressions` |
| `avoid_exit_outside_entrypoint` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_exit_outside_entrypoint.md) |
| `avoid_expanded_as_spacer` | HAVE | `avoid_expanded_as_spacer` |
| `avoid_flexible_outside_flex` | HAVE | `avoid_flexible_outside_flex` |
| `avoid_focused_tests` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_skipped_tests.md) (test hygiene, see Gap Theme 10) |
| `avoid_future_ignore` | HAVE | `avoid_future_ignore` |
| `avoid_future_of_either` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_future_of_either.md) (fpdart family, see Gap Theme 1) |
| `avoid_future_of_option` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_future_of_option.md) (fpdart family, see Gap Theme 1) |
| `avoid_generics_shadowing` | HAVE | `avoid_generics_shadowing` |
| `avoid_get_or_else_swallowing_failure` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_get_or_else_swallowing_failure.md) (fpdart family, see Gap Theme 1) |
| `avoid_high_cyclomatic_complexity` | HAVE | `avoid_high_cyclomatic_complexity` |
| `avoid_hooks_outside_build` | HAVE | `avoid_hooks_outside_build` |
| `avoid_incomplete_copy_with` | HAVE | `avoid_incomplete_copy_with` |
| `avoid_inconsistent_digit_separators` | HAVE | `avoid_inconsistent_digit_separators` |
| `avoid_incorrect_image_opacity` | HAVE | `avoid_incorrect_image_opacity` |
| `avoid_inherited_widget_in_initstate` | HAVE | `avoid_inherited_widget_in_initstate` |
| `avoid_inverted_boolean_checks` | HAVE | `avoid_inverted_boolean_checks` |
| `avoid_late_context` | HAVE | `avoid_late_context` |
| `avoid_late_final_reassignment` | HAVE | `avoid_late_final_reassignment` |
| `avoid_long_files` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_long_files.md) (configurable line-count budget, see Gap Theme 9) |
| `avoid_long_functions` | HAVE | `avoid_long_functions` |
| `avoid_long_parameter_list` | HAVE | `avoid_long_parameter_list` |
| `avoid_map_keys_contains` | HAVE | `avoid_map_keys_contains` |
| `avoid_missing_completer_stack_trace` | HAVE | `avoid_missing_completer_stack_trace` |
| `avoid_missing_enum_constant_in_map` | HAVE | `avoid_missing_enum_constant_in_map` |
| `avoid_misused_hooks` | HAVE | `avoid_misused_hooks` |
| `avoid_misused_test_matchers` | HAVE | `avoid_misused_test_matchers` |
| `avoid_mounted_in_setstate` | HAVE | `avoid_mounted_in_setstate` |
| `avoid_negated_conditions` | HAVE | `avoid_negated_conditions` |
| `avoid_nested_conditional_expressions` | HAVE | `avoid_nested_conditional_expressions` |
| `avoid_nested_do_notation` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_nested_do_notation.md) (fpdart family, see Gap Theme 1) |
| `avoid_nested_futures` | HAVE | `avoid_nested_futures` |
| `avoid_nested_shorthands` | HAVE | `avoid_nested_shorthands` |
| `avoid_non_null_assertion` | HAVE | `avoid_non_null_assertion` |
| `avoid_not_encodable_in_to_json` | HAVE | `avoid_not_encodable_in_to_json` |
| `avoid_notifier_constructors` | HAVE | `avoid_notifier_constructors` |
| `avoid_only_rethrow` | HAVE | `avoid_only_rethrow` |
| `avoid_passing_async_when_sync_expected` | HAVE | `avoid_passing_async_when_sync_expected` |
| `avoid_passing_bloc_to_bloc` | HAVE | `avoid_passing_bloc_to_bloc` |
| `avoid_passing_build_context_to_blocs` | HAVE | `avoid_passing_build_context_to_blocs` |
| `avoid_public_notifier_properties` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_public_notifier_properties.md) |
| `avoid_recursive_widget_calls` | HAVE | `avoid_recursive_widget_calls` |
| `avoid_redundant_async` | HAVE | `avoid_redundant_async` |
| `avoid_redundant_else` | HAVE | `avoid_redundant_else` |
| `avoid_ref_inside_state_dispose` | HAVE | `avoid_ref_inside_state_dispose` |
| `avoid_ref_read_inside_build` | HAVE | `avoid_ref_read_inside_build` |
| `avoid_ref_watch_outside_build` | HAVE | `avoid_ref_watch_outside_build` |
| `avoid_removed_fpdart_api` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_removed_fpdart_api.md) (fpdart family, see Gap Theme 1) |
| `avoid_returning_widgets` | HAVE | `avoid_returning_widgets` |
| `avoid_self_compare` | HAVE | `avoid_self_compare` |
| `avoid_shadowed_extension_methods` | HAVE | `avoid_shadowed_extension_methods` |
| `avoid_shrink_wrap_in_lists` | HAVE | `avoid_shrink_wrap_in_lists` |
| `avoid_single_child_in_multi_child_widgets` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_single_child_in_multi_child_widgets.md) |
| `avoid_single_field_destructuring` | HAVE | `avoid_single_field_destructuring` |
| `avoid_skipped_tests` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_skipped_tests.md) (test hygiene, see Gap Theme 10) |
| `avoid_state_constructors` | HAVE | `avoid_state_constructors` |
| `avoid_throw_in_catch_block` | HAVE | `avoid_throw_in_catch_block` |
| `avoid_throw_in_fp_callback` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_throw_in_fp_callback.md) (fpdart family, see Gap Theme 1) |
| `avoid_todo_comments` | PARTIAL | `prefer_todo_format` / `prefer_fixme_format` / `prefer_hack_format` — check marker format only, not issue/URL reference presence |
| `avoid_too_many_methods` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_too_many_methods.md) (budget rule, see Gap Theme 9) |
| `avoid_too_many_widgets_per_build` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_too_many_widgets_per_build.md) (budget rule, see Gap Theme 9) |
| `avoid_unassigned_stream_subscriptions` | HAVE | `avoid_unassigned_stream_subscriptions` |
| `avoid_unmodified_loop_condition` | PARTIAL | `avoid_complex_loop_conditions` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_complex_loop_conditions_dcm_parity.md) |
| `avoid_unnecessary_call` | HAVE | `avoid_unnecessary_call` |
| `avoid_unnecessary_constructor` | HAVE | `avoid_unnecessary_constructor` |
| `avoid_unnecessary_consumer_widgets` | HAVE | `avoid_unnecessary_consumer_widgets` |
| `avoid_unnecessary_continue` | HAVE | `avoid_unnecessary_continue` |
| `avoid_unnecessary_enum_prefix` | HAVE | `avoid_unnecessary_enum_prefix` |
| `avoid_unnecessary_extends` | HAVE | `avoid_unnecessary_extends` |
| `avoid_unnecessary_gesture_detector` | HAVE | `avoid_unnecessary_gesture_detector` |
| `avoid_unnecessary_hook_widgets` | HAVE | `avoid_unnecessary_hook_widgets` |
| `avoid_unnecessary_negations` | HAVE | `avoid_unnecessary_negations` |
| `avoid_unnecessary_option` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_unnecessary_option.md) (fpdart family, see Gap Theme 1) |
| `avoid_unnecessary_overrides` | HAVE | `avoid_unnecessary_overrides` |
| `avoid_unnecessary_return` | HAVE | `avoid_unnecessary_return` |
| `avoid_unnecessary_setstate` | HAVE | `avoid_unnecessary_setstate` |
| `avoid_unnecessary_stateful_widgets` | HAVE | `avoid_unnecessary_stateful_widgets` |
| `avoid_unrelated_type_casts` | HAVE | `avoid_unrelated_type_casts` |
| `avoid_unremovable_callbacks_in_listeners` | HAVE | `avoid_unremovable_callbacks_in_listeners` |
| `avoid_unrun_task` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_unrun_task.md) (fpdart family, see Gap Theme 1) |
| `avoid_unsafe_collection_methods` | HAVE | `avoid_unsafe_collection_methods` |
| `avoid_untyped_safe_cast` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_avoid_untyped_safe_cast.md) (fpdart family, see Gap Theme 1) |
| `avoid_unused_after_null_check` | HAVE | `avoid_unused_after_null_check` |
| `avoid_wildcard_cases_with_enums` | HAVE | `avoid_wildcard_cases_with_enums` |
| `avoid_wrapping_in_padding` | HAVE | `avoid_wrapping_in_padding` |
| `banned_usage` | HAVE | `banned_identifier_usage` |
| `check_for_equals_in_render_object_setters` | HAVE | `check_for_equals_in_render_object_setters` |
| `check_is_not_closed_after_async_gap` | HAVE | `check_is_not_closed_after_async_gap` |
| `dispose_fields` | HAVE | `dispose_widget_fields` / `dispose_class_fields` |
| `dispose_provided_instances` | HAVE | `dispose_provided_instances` |
| `double_literal_format` | HAVE | `double_literal_format` |
| `emit_new_bloc_state_instances` | HAVE | `emit_new_bloc_state_instances` |
| `enum_constants_ordering` | HAVE | `enum_constants_ordering` |
| `format_comment` | HAVE | `format_comment_style` |
| `format_test_name` | HAVE | `format_test_name` |
| `function_always_returns_null` | HAVE | `function_always_returns_null` |
| `function_always_returns_same_value` | HAVE | `function_always_returns_same_value` |
| `handle_bloc_event_subclasses` | PARTIAL | `require_bloc_event_sealed` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_require_bloc_event_sealed_dcm_parity.md) |
| `initializers_ordering` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_sorted_initializers.md) |
| `list_all_equatable_fields` | HAVE | `list_all_equatable_fields` |
| `map_keys_ordering` | HAVE | `map_keys_ordering` |
| `match_class_name_pattern` | HAVE | `match_class_name_pattern` |
| `match_getter_setter_field_names` | HAVE | `match_getter_setter_field_names` |
| `match_lib_folder_structure` | HAVE | `match_lib_folder_structure` |
| `match_pattern` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_match_pattern.md) (generic config-driven ban engine, see Gap Theme 2) |
| `max_imports` | HAVE | `limit_max_imports` |
| `max_statements` | PARTIAL | `avoid_long_functions` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_long_functions_dcm_parity.md) |
| `member_ordering` | HAVE | `prefer_member_ordering` |
| `missing_provider_scope` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_missing_provider_scope.md) |
| `never_discard_build_context` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_never_discard_build_context.md) |
| `no_equal_conditions` | HAVE | `no_equal_conditions` |
| `no_equal_switch_case` | HAVE | `no_equal_switch_case` |
| `no_equal_then_else` | HAVE | `no_equal_then_else` |
| `no_magic_number` | HAVE | `no_magic_number` |
| `no_magic_string` | HAVE | `no_magic_string` |
| `notifier_build` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_notifier_build.md) (Riverpod completeness, see Gap Theme 3) |
| `notifier_properties` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_public_notifier_properties.md) |
| `parameters_ordering` | HAVE | `enforce_parameters_ordering` |
| `pass_existing_future_to_future_builder` | HAVE | `pass_existing_future_to_future_builder` |
| `pass_existing_stream_to_stream_builder` | HAVE | `pass_existing_stream_to_stream_builder` |
| `pattern_fields_ordering` | HAVE | `prefer_sorted_pattern_fields` |
| `prefer_abstract_final_static_class` | HAVE | `prefer_abstract_final_static_class` |
| `prefer_add_all` | HAVE | `prefer_add_all` |
| `prefer_align_over_container` | HAVE | `prefer_align_over_container` |
| `prefer_and_then` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_and_then.md) (fpdart family, see Gap Theme 1) |
| `prefer_any_or_every` | HAVE | `prefer_any_or_every` |
| `prefer_async_callback` | HAVE | `prefer_async_callback` |
| `prefer_bloc_extensions` | HAVE | `prefer_bloc_extensions` |
| `prefer_boolean_prefixes` | HAVE | `prefer_boolean_prefixes` |
| `prefer_center_over_align` | HAVE | `prefer_center_over_align` |
| `prefer_chain_either` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_chain_either.md) (fpdart family, see Gap Theme 1) |
| `prefer_chaining_over_intermediate_run` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_chaining_over_intermediate_run.md) (fpdart family, see Gap Theme 1) |
| `prefer_class_destructuring` | HAVE | `prefer_class_destructuring` |
| `prefer_compute_over_isolate_run` | HAVE | `prefer_compute_over_isolate_run` |
| `prefer_conditional_expressions` | HAVE | `prefer_conditional_expressions` |
| `prefer_const_border_radius` | HAVE | `prefer_const_border_radius` |
| `prefer_constrained_box_over_container` | HAVE | `prefer_constrained_box_over_container` |
| `prefer_container` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_prefer_container.md) (collapse nested single-purpose widgets into one `Container`) |
| `prefer_correct_callback_field_name` | HAVE | `prefer_correct_callback_field_name` |
| `prefer_correct_edge_insets_constructor` | HAVE | `prefer_correct_edge_insets_constructor` |
| `prefer_correct_error_name` | HAVE | `prefer_correct_error_name` |
| `prefer_correct_future_return_type` | HAVE | `prefer_correct_future_return_type` |
| `prefer_correct_handler_name` | HAVE | `prefer_correct_handler_name` |
| `prefer_correct_identifier_length` | HAVE | `prefer_correct_identifier_length` |
| `prefer_correct_json_casts` | HAVE | `prefer_correct_json_casts` |
| `prefer_correct_setter_parameter_name` | HAVE | `prefer_correct_setter_parameter_name` |
| `prefer_correct_test_file_name` | HAVE | `prefer_correct_test_file_name` |
| `prefer_correct_type_name` | HAVE | `prefer_correct_type_name` |
| `prefer_declaring_const_constructor` | HAVE | `prefer_declaring_const_constructor` |
| `prefer_do_notation` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_do_notation.md) (fpdart family, see Gap Theme 1) |
| `prefer_early_return` | HAVE | `prefer_early_return` |
| `prefer_enums_by_name` | HAVE | `prefer_enums_by_name` |
| `prefer_equatable_mixin` | HAVE | `prefer_equatable_mixin` |
| `prefer_expect_later` | HAVE | `prefer_expect_later` |
| `prefer_explicit_function_type` | HAVE | `prefer_explicit_function_type` |
| `prefer_explicit_parameter_names` | HAVE | `prefer_explicit_parameter_names` |
| `prefer_explicit_type_arguments` | HAVE | `prefer_explicit_type_arguments` |
| `prefer_extracting_callbacks` | HAVE | `prefer_extracting_callbacks` |
| `prefer_for_loop_in_children` | HAVE | `prefer_for_loop_in_children` |
| `prefer_from_nullable` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_from_nullable.md) (fpdart family, see Gap Theme 1) |
| `prefer_from_predicate` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_from_predicate.md) (fpdart family, see Gap Theme 1) |
| `prefer_getter_over_method` | HAVE | `prefer_getter_over_method` |
| `prefer_immediate_return` | HAVE | `prefer_immediate_return` |
| `prefer_immutable_bloc_state` | HAVE | `prefer_immutable_bloc_state` |
| `prefer_immutable_state` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_immutable_state.md) (state-management-agnostic variant) |
| `prefer_iterable_of` | HAVE | `prefer_iterable_of` |
| `prefer_match_file_name` | HAVE | `prefer_match_file_name` |
| `prefer_moving_to_variable` | HAVE | `prefer_moving_to_variable` |
| `prefer_multi_bloc_provider` | HAVE | `prefer_multi_bloc_provider` |
| `prefer_named_parameters` | HAVE | `prefer_named_parameters` |
| `prefer_overriding_parent_equality` | HAVE | `prefer_overriding_parent_equality` |
| `prefer_padding_over_container` | HAVE | `prefer_padding_over_container` |
| `prefer_prefixed_global_constants` | HAVE | `prefer_prefixed_global_constants` |
| `prefer_primary_constructors` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_primary_constructors.md) (Dart 3.13 syntax, see Gap Theme 11) |
| `prefer_private_named_parameters` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_private_named_parameters.md) |
| `prefer_return_await` | HAVE | `prefer_return_await` |
| `prefer_returning_condition` | HAVE | `prefer_returning_condition` |
| `prefer_returning_shorthands` | HAVE | `prefer_arrow_functions` |
| `prefer_safe_collection_access` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_safe_collection_access.md) (fpdart family, see Gap Theme 1) |
| `prefer_shorthands_with_constructors` | HAVE | `prefer_shorthands_with_constructors` |
| `prefer_shorthands_with_enums` | HAVE | `prefer_shorthands_with_enums` |
| `prefer_shorthands_with_static_fields` | HAVE | `prefer_shorthands_with_static_fields` |
| `prefer_simpler_patterns_null_check` | HAVE | `prefer_simpler_patterns_null_check` |
| `prefer_single_declaration_per_file` | HAVE | `prefer_single_declaration_per_file` |
| `prefer_single_setstate` | HAVE | `prefer_single_setstate` |
| `prefer_single_widget_per_file` | HAVE | `prefer_single_widget_per_file` |
| `prefer_sized_box_square` | HAVE | `prefer_sized_box_square` |
| `prefer_spacing` | HAVE | `prefer_spacing_over_sizedbox` |
| `prefer_string_parse_extensions` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_string_parse_extensions.md) (fpdart family, see Gap Theme 1) |
| `prefer_switch_expression` | HAVE | `prefer_switch_expression` |
| `prefer_switch_with_enums` | HAVE | `prefer_switch_with_enums` |
| `prefer_task_either_over_try_catch` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_task_either_over_try_catch.md) (fpdart family, see Gap Theme 1) |
| `prefer_test_matchers` | HAVE | `prefer_test_matchers` |
| `prefer_text_rich` | HAVE | `prefer_text_rich` |
| `prefer_theme_mode_getters` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_prefer_theme_mode_getters.md) |
| `prefer_transform_over_container` | HAVE | `prefer_transform_over_container` |
| `prefer_type_over_var` | HAVE | `prefer_type_over_var` |
| `prefer_typed_exceptions` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_typed_exceptions.md) |
| `prefer_typedefs_for_callbacks` | HAVE | `prefer_typedefs_for_callbacks` |
| `prefer_unit_over_void` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_prefer_unit_over_void.md) (fpdart family, see Gap Theme 1) |
| `prefer_use_callback` | HAVE | `prefer_use_callback` |
| `prefer_use_prefix` | HAVE | `prefer_use_prefix` |
| `prefer_void_callback` | HAVE | `prefer_void_callback` |
| `prefer_widget_private_members` | HAVE | `prefer_widget_private_members` |
| `prefer_wildcard_pattern` | HAVE | `prefer_wildcard_pattern` |
| `proper_super_calls` | HAVE | `proper_super_calls` |
| `protected_notifier_properties` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_public_notifier_properties.md) |
| `provider_parameters` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_provider_parameters.md) (Riverpod completeness, see Gap Theme 3) |
| `record_fields_ordering` | HAVE | `prefer_sorted_record_fields` |
| `require_atomic_async_updates` | PARTIAL | `require_mounted_check_after_await` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_require_mounted_check_after_await_dcm_parity.md) |
| `require_mirror_test` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_missing_test_files.md) (same "mirror test" concept) |
| `use_class_prefix` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_infra_configurable_class_naming_rules.md) (generic config-driven naming engine, see Gap Theme 2) |
| `use_class_suffix` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_infra_configurable_class_naming_rules.md) (generic config-driven naming engine, see Gap Theme 2) |
| `use_closest_build_context` | HAVE | `use_closest_build_context` |
| `use_dedicated_media_query_methods` | PARTIAL | `avoid_deprecated_use_inherited_media_query` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_deprecated_use_inherited_media_query_dcm_parity.md) |
| `use_existing_destructuring` | HAVE | `use_existing_destructuring` |
| `use_existing_variable` | HAVE | `use_existing_variable` |
| `use_gap` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_gap.md) |
| `use_ref_and_state_synchronously` | HAVE | `use_ref_and_state_synchronously` |
| `use_ref_read_synchronously` | HAVE | `use_ref_read_synchronously` |
| `use_setstate_synchronously` | HAVE | `use_setstate_synchronously` |
| `use_sliver_prefix` | HAVE | `prefer_sliver_prefix` |

## What You Gain

saropa_lints includes rules well beyond many_lints' scope: OWASP-mapped security rules
(hardcoded credentials, weak cryptography, insecure storage), accessibility semantics, and
library-specific coverage for GetX, Isar, Hive, and Firebase that many_lints doesn't address at
all.

## What You Lose

`many_lints`' fpdart support (23 rules covering `Either`/`Option`/`TaskEither`/`Do` notation), its
13 lightbulb-menu assists (not tied to any diagnostic — always available regardless of enabled
rules), and its generic project-configurable `avoid_banned_*`/`use_class_prefix`/
`use_class_suffix`/`match_pattern` engine have no saropa_lints equivalent. If your project
depends on any of these, keep `many_lints` installed alongside saropa_lints (see "Using Both
Together" above).

## Suppressing Rules

```dart
// many_lints style
// ignore: many_lints/prefer_center_over_align

// saropa_lints style
// ignore: prefer_center_over_align
```

Note: `many_lints` requires the `many_lints/` prefix on `// ignore:` comments (a plugin
diagnostic is only silenced when prefixed with the plugin name); saropa_lints does not require a
prefix.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
