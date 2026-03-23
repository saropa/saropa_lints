# Implemented: plan_additional_rules_31_through_40

**Source plan:** [plan/plan_additional_rules_31_through_40.md](../../plan_additional_rules_31_through_40.md)  
**Status:** Complete (2026-03-23)

## Summary

Ten Essential-tier rules were added, mirroring or supplementing common Dart analyzer diagnostics for consistent Saropa tier messaging and configuration:

| Rule | Primary file |
|------|----------------|
| `abstract_field_initializer` | `compile_time_syntax_rules.dart` |
| `undefined_enum_constructor` | `compile_time_syntax_rules.dart` |
| `non_constant_map_element` | `collection_rules.dart` |
| `return_in_generator`, `yield_in_non_generator` | `control_flow_rules.dart` |
| `subtype_of_disallowed_type`, `abi_specific_integer_invalid` | `type_rules.dart` |
| `deprecated_new_in_comment_reference` | `documentation_rules.dart` |
| `annotate_redeclares`, `document_ignores` | `stylistic_rules.dart` |

## Follow-up (review pass)

- **Registration:** Rules are listed in [`lib/saropa_lints.dart`](../../lib/saropa_lints.dart) `_allRuleFactories` and in [`lib/src/tiers.dart`](../../lib/src/tiers.dart) `essentialRules` (required for the plugin to load them).
- **Tests:** `test/plan_additional_rules_31_40_test.dart` — registry resolution, `requiredPatterns` for file pre-filter, duplicated regex checks for `document_ignores` / `deprecated_new_in_comment_reference`, GOOD-section fixture slices.
- **Performance:** `requiredPatterns` on `abi_specific_integer_invalid`, `return_in_generator`, `yield_in_non_generator`, `document_ignores`, `deprecated_new_in_comment_reference` (skip irrelevant files via content index).
- **Docs / counts:** README, `pubspec.yaml`, and ROADMAP rule total **2117** (`allSaropaRules.length`); `example/analysis_options_template.yaml` tier approximations + ten new rule entries under compile-time shape.
- **Analyzer 9:** `migration_rule_source_utils`: `declaredFragment?.element.library`; `flutter_test_window_deprecation_utils` uses `ElementKind.GETTER`; `image_filter_quality_detection` uses `SimpleIdentifier.element`.

## Quick fixes

Not added (plan optional); overlapping analyzer fixes already exist for several codes.
