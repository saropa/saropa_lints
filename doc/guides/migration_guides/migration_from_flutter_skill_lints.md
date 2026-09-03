# Migrating from flutter_skill_lints

This guide helps you migrate from `flutter_skill_lints` to `saropa_lints`.

## Why Migrate?

| Feature | flutter_skill_lints | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 279 rules | 2300+ custom rules |
| **Focus** | Flutter/Riverpod/Freezed-heavy general-purpose set | Broader coverage: security, accessibility, performance, GetX/Bloc/Provider/Firebase/Isar/Hive, plus the same Riverpod/Freezed ground |
| **Configuration** | Enable individually via `plugins.flutter_skill_lints` | 5 progressive tiers |
| **Overlap with saropa** | High — 83% of its rules have a direct saropa equivalent | — |

## Architecture Differences

flutter_skill_lints installs as an `analyzer.plugins` entry (`analysis_server_plugin`), the same install surface saropa_lints uses — no `custom_lint` layer for either package.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_skill_lints: ^1.0.0

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - flutter_skill_lints

# After
analyzer:
  plugins:
    - saropa_lints
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

## Rule Mapping

Coverage: 48 rules — 7 PARTIAL, 41 TODO (85%)

flutter_skill_lints ships 279 rules across ~25 grouped rule-source files (architecture, Riverpod, Freezed, router, persistence, UI, tests, etc.) rather than one rule per file, so the 231 HAVE rules are not individually enumerated below — each was confirmed to have a same- or similar-named saropa equivalent during the gap audit (see `plans/GAP_ANALYSIS.md` → `### flutter_skill_lints`). The tables below list every named GAP and PARTIAL rule.

### Gaps (41 rules — TODO)

| flutter_skill_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_any_version` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_any_version.md) |
| `avoid_banned_exports` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_exports.md) |
| `avoid_banned_file_names` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_file_names.md) |
| `avoid_banned_imports` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_imports.md) |
| `avoid_calling_notifier_members_inside_build` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_calling_notifier_members_inside_build.md) |
| `avoid_dependency_overrides` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_dependency_overrides.md) |
| `avoid_disposing_late_fields` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_disposing_late_fields.md) |
| `avoid_flutter_skill_lint_suppression` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_lint_suppression_abuse.md) (package-specific: bans suppressing flutter_skill_lints itself) |
| `avoid_implementation_in_mocks` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_implementation_in_mocks.md) |
| `avoid_inline_error_codes` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_inline_error_codes.md) |
| `avoid_labels` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_labeled_statements.md) |
| `avoid_local_contract_key_constants` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_local_contract_key_constants.md) |
| `avoid_missing_test_files` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_missing_test_files.md) |
| `avoid_misused_wildcard_pattern` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_keywords_in_wildcard_pattern_dcm_parity.md) |
| `avoid_mounted_check_in_finally` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_mounted_check_in_finally.md) |
| `avoid_nullable_async_or_collection_return_type` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_nullable_async_or_collection_return_type.md) |
| `avoid_parameter_aliases` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_parameter_aliases.md) |
| `avoid_positional_record_fields` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_positional_record_fields.md) |
| `avoid_public_late_final_without_initializer` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_public_late_final_without_initializer.md) |
| `avoid_public_notifier_properties` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_public_notifier_properties.md) |
| `avoid_repeated_property_aliases` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_repeated_property_aliases.md) |
| `avoid_then_return_with_future` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_then_return_with_future.md) |
| `avoid_throw` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_throw_in_finally_dcm_parity.md) |
| `avoid_unassigned_local_variable` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_unassigned_late_fields_dcm_parity.md) |
| `avoid_unnecessary_parentheses` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_unnecessary_parentheses.md) |
| `avoid_unnecessary_safe_area` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_unnecessary_safe_area.md) |
| `avoid_unused_local_variable` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_infra_avoid_unused_local_variable_na.md) |
| `keep_state_below_its_widget` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_state_class_below_widget.md) |
| `pass_mock_object` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_pass_mock_object.md) |
| `prefer_container` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_prefer_container.md) |
| `prefer_correct_any_matcher` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_correct_any_matcher.md) |
| `prefer_correct_static_icon_provider` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_correct_static_icon_provider.md) |
| `prefer_publish_to_none` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_publish_to_none.md) |
| `pubspec_ordering` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_pubspec_ordering.md) |
| `require_atomic_async_updates` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_require_mounted_check_after_await_dcm_parity.md) |
| `resolve_platform_specific_implementation_before_use` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_resolve_platform_specific_implementation_before_use.md) |
| `use_context_is_current_modal_route` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_use_context_is_current_modal_route.md) |
| `use_local_notifications_exact_alarm_permission_api` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_use_local_notifications_exact_alarm_permission_api.md) |
| `use_notifier_suffix` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_prefer_riverpod_notifier_suffix.md) |
| `use_on_reorder_item_index_semantics` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_on_reorder_item_index_semantics.md) |
| `use_then_answer` | TODO | TODO — see [proposal](../../../bugs/tier_4_needs_decision/proposal_use_then_answer.md) |

### Partial (7 rules)

| flutter_skill_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_banned_annotations` | PARTIAL | `banned_identifier_usage` — matches by identifier name only, not annotation-aware. TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_annotations.md) |
| `avoid_banned_names` | PARTIAL | `banned_identifier_usage` — TODO extend, see [proposal](../../../bugs/tier_3_infrastructure/proposal_extend_banned_identifier_usage_dcm_parity.md) |
| `avoid_banned_types` | PARTIAL | `banned_identifier_usage` — not type-annotation-aware. TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_avoid_banned_types.md) |
| `avoid_futureor_return_type` | PARTIAL | `prefer_unwrapping_future_or` — suggests unwrapping generally, doesn't specifically flag `FutureOr` as a return type. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_futureor_return_type.md) |
| `avoid_missing_controller` | PARTIAL | `require_form_field_controller` — only covers `TextFormField`, not all controller-accepting input widgets. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_missing_controller.md) |
| `avoid_single_child_in_multi_child_widgets` | PARTIAL | `avoid_single_child_column_row` — covers only Column/Row, not all multi-child widgets. TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_single_child_in_multi_child_widgets.md) |
| `avoid_unnecessary_else_after_control_flow` | PARTIAL | `avoid_redundant_else` — only flags else after return/throw/continue/break; flutter_skill_lints bans all else blocks unconditionally. TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_avoid_unnecessary_else_after_control_flow.md) |

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
