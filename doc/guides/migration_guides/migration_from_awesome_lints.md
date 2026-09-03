# Migrating from awesome_lints

This guide helps you migrate from [`awesome_lints`](https://pub.dev/packages/awesome_lints) to `saropa_lints`.

## Why Migrate?

| Feature | awesome_lints | saropa_lints |
|---------|-----------------|--------------|
| **Rule count** | 123 rules (65 Common Dart, 32 Flutter, 22 Bloc, 8 Provider, 1 FakeAsync) | 2300+ custom rules |
| **Focus** | Broad Dart/Flutter lint collection, largely DCM-compatible naming | Security, accessibility, performance, and 2300+ Flutter-specific patterns |
| **Configuration** | Flat rule list | 5 progressive tiers |
| **Maintenance** | Community package | Actively maintained |

**Note**: Most `awesome_lints` rule ids and semantics match `dart_code_metrics` (DCM) rules of the same name — if you already use the [DCM migration guide](migration_from_dcm.md), the mappings below track it closely.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  awesome_lints: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

## Choosing a Tier

| awesome_lints Usage | saropa_lints Tier | Description |
|-----------|-------------------|-------------|
| Minimal rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Default config | **Recommended** (~900 rules) | Balanced coverage |
| Strict metrics | **Professional** (~1600 rules) | Enterprise-grade |
| All rules enabled | **Comprehensive** (~2100 rules) | Quality obsessed |

**Start with `recommended`** - it provides broad coverage without overwhelming noise.

## Rule Mapping

Coverage: 128 rules — 110 HAVE (85%), 7 PARTIAL, 11 TODO (8%)

### Bloc

| awesome_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_bloc_public_fields` | HAVE | `avoid_bloc_public_fields` |
| `avoid_bloc_public_methods` | HAVE | `avoid_bloc_public_methods` |
| `avoid_cubits` | HAVE | `avoid_cubit_usage` |
| `avoid_duplicate_bloc_event_handlers` | HAVE | `avoid_duplicate_bloc_event_handlers` |
| `avoid_empty_build_when` | PARTIAL | `avoid_empty_build_when` — saropa's version fires only when `buildWhen` always returns `true`, not when it's omitted entirely |
| `avoid_existing_instances_in_bloc_provider` | HAVE | `avoid_existing_instances_in_bloc_provider` |
| `avoid_instantiating_in_bloc_value_provider` | HAVE | `avoid_instantiating_in_bloc_value_provider` |
| `avoid_passing_bloc_to_bloc` | HAVE | `avoid_passing_bloc_to_bloc` |
| `avoid_passing_build_context_to_blocs` | HAVE | `avoid_passing_build_context_to_blocs` |
| `avoid_returning_value_from_cubit_methods` | HAVE | `avoid_returning_value_from_cubit_methods` |
| `check_is_not_closed_after_async_gap` | HAVE | `check_is_not_closed_after_async_gap` |
| `emit_new_bloc_state_instances` | HAVE | `emit_new_bloc_state_instances` |
| `handle_bloc_event_subclasses` | PARTIAL | `require_bloc_event_sealed` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_require_bloc_event_sealed_dcm_parity.md) |
| `prefer_bloc_event_suffix` | HAVE | `prefer_bloc_event_suffix` |
| `prefer_bloc_extensions` | HAVE | `prefer_bloc_extensions` |
| `prefer_bloc_state_suffix` | HAVE | `prefer_bloc_state_suffix` |
| `prefer_correct_bloc_provider` | HAVE | `prefer_correct_bloc_provider` |
| `prefer_immutable_bloc_events` | HAVE | `prefer_immutable_bloc_events` |
| `prefer_immutable_bloc_state` | HAVE | `prefer_immutable_bloc_state` |
| `prefer_multi_bloc_provider` | HAVE | `prefer_multi_bloc_provider` |
| `prefer_sealed_bloc_events` | HAVE | `prefer_sealed_bloc_events` |
| `prefer_sealed_bloc_state` | HAVE | `prefer_sealed_bloc_state` |

### Common Dart

| awesome_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `arguments_ordering` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_arguments_ordering.md) |
| `avoid_accessing_collections_by_constant_index` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_accessing_collections_by_constant_index.md) |
| `avoid_accessing_other_classes_private_members` | HAVE | `avoid_accessing_other_classes_private_members` |
| `avoid_adjacent_strings` | TODO | TODO — saropa's `prefer_adjacent_strings` enforces the opposite convention — see [proposal](../../../bugs/declined/proposal_avoid_adjacent_strings.md) |
| `avoid_always_null_parameters` | HAVE | `avoid_always_null_parameters` |
| `avoid_assigning_to_static_field` | HAVE | `avoid_assigning_to_static_field` |
| `avoid_assignments_as_conditions` | HAVE | `avoid_assignments_as_conditions` |
| `avoid_async_call_in_sync_function` | HAVE | `avoid_async_call_in_sync_function` |
| `avoid_barrel_files` | HAVE | `avoid_barrel_files` |
| `avoid_bitwise_operators_with_booleans` | HAVE | `avoid_bitwise_operators_with_booleans` |
| `avoid_bottom_type_in_patterns` | HAVE | `avoid_bottom_type_in_patterns` |
| `avoid_bottom_type_in_records` | HAVE | `avoid_bottom_type_in_records` |
| `avoid_cascade_after_if_null` | HAVE | `avoid_cascade_after_if_null` |
| `avoid_casting_to_extension_type` | HAVE | `avoid_casting_to_extension_type` |
| `avoid_collapsible_if` | HAVE | `avoid_collapsible_if` |
| `avoid_collection_equality_checks` | HAVE | `avoid_collection_equality_checks` |
| `avoid_collection_methods_with_unrelated_types` | HAVE | `avoid_collection_methods_with_unrelated_types` |
| `avoid_collection_mutating_methods` | PARTIAL | `avoid_collection_mutating_methods` — saropa scopes this to mutation inside `setState()` only; theirs is general |
| `avoid_commented_out_code` | HAVE | `prefer_no_commented_out_code` |
| `avoid_complex_arithmetic_expressions` | HAVE | `avoid_complex_arithmetic_expressions` |
| `avoid_complex_conditions` | HAVE | `avoid_complex_conditions` |
| `avoid_complex_loop_conditions` | PARTIAL | `avoid_complex_loop_conditions` — narrower threshold, TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_complex_loop_conditions_dcm_parity.md) |
| `avoid_conditions_with_boolean_literals` | HAVE | `avoid_conditions_with_boolean_literals` |
| `avoid_constant_assert_conditions` | HAVE | `avoid_constant_assert_conditions` |
| `avoid_constant_conditions` | HAVE | `avoid_constant_conditions` |
| `avoid_constant_switches` | HAVE | `avoid_constant_switches` |
| `avoid_continue` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_continue.md) |
| `avoid_contradictory_expressions` | HAVE | `avoid_contradictory_expressions` |
| `avoid_declaring_call_method` | HAVE | `avoid_declaring_call_method` |
| `avoid_default_tostring` | HAVE | `avoid_default_tostring` |
| `avoid_deprecated_usage` | HAVE | `avoid_deprecated_usage` |
| `avoid_double_slash_imports` | HAVE | `avoid_double_slash_imports` |
| `avoid_duplicate_cascades` | HAVE | `avoid_duplicate_cascades` |
| `avoid_duplicate_collection_elements` | TODO | TODO — unconfirmed — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_duplicate_collection_elements.md) |
| `avoid_non_null_assertion` | HAVE | `avoid_non_null_assertion` |
| `binary_expression_operand_order` | HAVE | `binary_expression_operand_order` |
| `dispose_class_fields` | HAVE | `dispose_class_fields` |
| `double_literal_format` | HAVE | `double_literal_format` |
| `newline_before_case` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_newline_before_case.md) |
| `newline_before_constructor` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_newline_before_constructor.md) |
| `newline_before_method` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_newline_before_method.md) |
| `newline_before_return` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_newline_before_return.md) |
| `no_boolean_literal_compare` | HAVE | `no_boolean_literal_compare` |
| `no_empty_block` | HAVE | `no_empty_block` |
| `no_empty_string` | HAVE | `no_empty_string` |
| `no_equal_arguments` | HAVE | `no_equal_arguments` |
| `no_equal_conditions` | HAVE | `no_equal_conditions` |
| `no_equal_nested_conditions` | HAVE | `no_equal_nested_conditions` |
| `no_equal_switch_case` | HAVE | `no_equal_switch_case` |
| `no_equal_switch_expression_cases` | HAVE | `no_equal_switch_expression_cases` |
| `no_equal_then_else` | HAVE | `no_equal_then_else` |
| `no_magic_number` | HAVE | `no_magic_number` |
| `no_magic_string` | HAVE | `no_magic_string` |
| `no_object_declaration` | HAVE | `no_object_declaration` |
| `prefer_async_await` | HAVE | `prefer_async_await` |
| `prefer_contains` | HAVE | `prefer_list_contains` |
| `prefer_correct_for_loop_increment` | HAVE | `prefer_correct_for_loop_increment` |
| `prefer_correct_json_casts` | HAVE | `prefer_correct_json_casts` |
| `prefer_early_return` | HAVE | `prefer_early_return` |
| `prefer_first` | HAVE | `prefer_list_first` |
| `prefer_iterable_of` | HAVE | `prefer_iterable_of` |
| `prefer_last` | HAVE | `prefer_list_last` |
| `prefer_named_boolean_parameters` | HAVE | `prefer_named_boolean_parameters` |
| `prefer_return_await` | HAVE | `prefer_return_await` |
| `prefer_switch_expression` | HAVE | `prefer_switch_expression` |

### Flutter

| awesome_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_empty_setstate` | HAVE | `avoid_empty_setstate` |
| `avoid_late_context` | HAVE | `avoid_late_context` |
| `avoid_missing_controller` | HAVE | `require_form_field_controller` |
| `avoid_mounted_in_setstate` | HAVE | `avoid_mounted_in_setstate` |
| `avoid_single_child_column_or_row` | HAVE | `avoid_single_child_column_row` |
| `avoid_stateless_widget_initialized_fields` | HAVE | `avoid_stateless_widget_initialized_fields` |
| `avoid_undisposed_instances` | HAVE | `avoid_undisposed_instances` |
| `avoid_unnecessary_gesture_detector` | HAVE | `avoid_unnecessary_gesture_detector` |
| `avoid_unnecessary_overrides_in_state` | HAVE | `avoid_unnecessary_overrides_in_state` |
| `avoid_unnecessary_stateful_widgets` | HAVE | `avoid_unnecessary_stateful_widgets` |
| `avoid_wrapping_in_padding` | HAVE | `avoid_wrapping_in_padding` |
| `dispose_fields` | HAVE | `dispose_widget_fields` / `dispose_class_fields` |
| `pass_existing_future_to_future_builder` | HAVE | `pass_existing_future_to_future_builder` |
| `pass_existing_stream_to_stream_builder` | HAVE | `pass_existing_stream_to_stream_builder` |
| `prefer_action_button_tooltip` | HAVE | `prefer_action_button_tooltip` |
| `prefer_align_over_container` | HAVE | `prefer_align_over_container` |
| `prefer_async_callback` | TODO | TODO — saropa has the opposite rule, `prefer_future_void_function_over_async_callback` — see [proposal](../../../bugs/declined/proposal_prefer_async_callback.md) |
| `prefer_center_over_align` | HAVE | `prefer_center_over_align` |
| `prefer_compute_over_isolate_run` | HAVE | `prefer_compute_over_isolate_run` |
| `prefer_constrained_box_over_container` | HAVE | `prefer_constrained_box_over_container` |
| `prefer_container` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_prefer_container.md) |
| `prefer_dedicated_media_query_methods` | PARTIAL | `avoid_deprecated_use_inherited_media_query` — TODO extend, see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_deprecated_use_inherited_media_query_dcm_parity.md) |
| `prefer_for_loop_in_children` | HAVE | `prefer_for_loop_in_children` |
| `prefer_padding_over_container` | HAVE | `prefer_padding_over_container` |
| `prefer_single_setstate` | HAVE | `prefer_single_setstate` |
| `prefer_sized_box_square` | HAVE | `prefer_sized_box_square` |
| `prefer_sliver_prefix` | HAVE | `prefer_sliver_prefix` |
| `prefer_spacing` | HAVE | `prefer_spacing_over_sizedbox` |
| `prefer_text_rich` | HAVE | `prefer_text_rich` |
| `prefer_void_callback` | HAVE | `prefer_void_callback` |
| `prefer_widget_private_members` | HAVE | `prefer_widget_private_members` |
| `proper_super_calls` | HAVE | `proper_super_calls` |

### Provider

| awesome_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_instantiating_in_value_provider` | HAVE | `avoid_instantiating_in_value_provider` |
| `avoid_read_inside_build` | PARTIAL | `avoid_ref_read_inside_build` — Riverpod-specific; no exact analog for plain `provider` package `context.read` |
| `avoid_watch_outside_build` | PARTIAL | `avoid_ref_watch_outside_build` — Riverpod-specific; no exact analog for plain `provider` package `context.watch` |
| `dispose_providers` | HAVE | `dispose_provider_instances` / `require_provider_dispose` |
| `prefer_immutable_selector_value` | HAVE | `prefer_immutable_selector_value` |
| `prefer_multi_provider` | HAVE | `prefer_multi_provider` |
| `prefer_nullable_provider_types` | HAVE | `prefer_nullable_provider_types` |
| `prefer_provider_extensions` | HAVE | `prefer_provider_extensions` |

### FakeAsync

| awesome_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_async_callback_in_fake_async` | HAVE | `avoid_async_callback_in_fake_async` |

## Suppressing Rules

```dart
// awesome_lints style
// ignore: no_magic_number

// saropa_lints style
// ignore: no_magic_number
```

Note: unlike DCM, `awesome_lints` already uses underscores in its rule ids, so most suppression comments carry over unchanged.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
