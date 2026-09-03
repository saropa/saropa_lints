# Migrating from dart_code_linter

This guide helps you migrate from `dart_code_linter` (Bancolombia's actively-maintained fork of the discontinued Dart Code Metrics) to `saropa_lints`.

## Why Migrate?

| Feature | dart_code_linter | saropa_lints |
|---------|-------------------|--------------|
| **Rule count** | 82 rules + continuous metrics | 2300+ custom rules |
| **Focus** | DCM-lineage code metrics & anti-patterns | Flutter-specific analysis across security, accessibility, performance, and every major state-management library |
| **Reporting** | HTML/console maintainability-index report | Discrete threshold lint rules (no continuous report) |
| **Configuration** | YAML rule/metric config | 5 progressive tiers |
| **Maintenance** | Actively maintained fork | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: dart_code_linter is a DCM fork, so its rule set overlaps heavily with `migration_from_dcm.md`. If you already use DCM, treat this guide as the fork-specific delta — most rule names and coverage carry over directly.

## Architecture Differences

dart_code_linter inherited DCM's cyclomatic-complexity, lines-of-code, and Halstead-style maintainability metrics, reported continuously via HTML/console output. saropa_lints encodes the same underlying signals as discrete threshold lint rules instead (`avoid_high_cyclomatic_complexity`, `avoid_long_functions`, `avoid_long_length_files`, etc.) — you get pass/fail lint diagnostics in your IDE rather than a separate metrics report. If a continuous maintainability-index report is a hard requirement, keep dart_code_linter's reporting alongside saropa_lints for that purpose.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  dart_code_linter: ^5.7.0

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
    - dart_code_linter

dart_code_linter:
  rules:
    - avoid-returning-widgets
    - no-magic-number

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

If you need dart_code_linter's continuous metrics report alongside saropa_lints' rules:

```yaml
# pubspec.yaml
dev_dependencies:
  dart_code_linter: ^5.7.0
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

```bash
dart run saropa_lints:init --tier recommended
```

## Choosing a Tier

| dart_code_linter Usage | saropa_lints Tier | Description |
|--------------------------|-------------------|--------------|
| Minimal rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Default config | **Recommended** (~900 rules) | Balanced coverage |
| Strict metrics | **Professional** (~1600 rules) | Enterprise-grade |
| All rules enabled | **Comprehensive** (~2100 rules) | Quality obsessed |

**Start with `recommended`** — it provides broad coverage without overwhelming noise.

## Rule Mapping

Coverage: 87 rules — 77 HAVE (88%), 2 PARTIAL, 8 TODO (9%)

| dart_code_linter Rule | Status | Saropa Rule / Action |
|---|---|---|
| `always_remove_listener` | HAVE | `always_remove_listener` |
| `arguments_ordering` | HAVE | `prefer_arguments_ordering` |
| `avoid_banned_imports` | TODO | TODO — see [proposal](../../../plans/tier_3_infrastructure/proposal_avoid_banned_imports.md) |
| `avoid_border_all` | HAVE | `avoid_border_all` |
| `avoid_cascade_after_if_null` | HAVE | `avoid_cascade_after_if_null` |
| `avoid_collection_methods_with_unrelated_types` | HAVE | `avoid_collection_methods_with_unrelated_types` |
| `avoid_creating_vector_in_update` | HAVE | `avoid_creating_vector_in_update` |
| `avoid_double_slash_imports` | HAVE | `avoid_double_slash_imports` |
| `avoid_duplicate_exports` | HAVE | `avoid_duplicate_exports` |
| `avoid_dynamic` | HAVE | `avoid_dynamic_type` |
| `avoid_expanded_as_spacer` | HAVE | `avoid_expanded_as_spacer` |
| `avoid_global_state` | HAVE | `avoid_global_state` |
| `avoid_ignoring_return_values` | HAVE | `avoid_ignoring_return_values` |
| `avoid_initializing_in_on_mount` | TODO | TODO — see [proposal](../../../plans/tier_2_high_value/proposal_avoid_initializing_in_on_mount.md) (Flame-specific) |
| `avoid_late_keyword` | HAVE | `avoid_late_keyword` |
| `avoid_missing_enum_constant_in_map` | HAVE | `avoid_missing_enum_constant_in_map` |
| `avoid_nested_conditional_expressions` | HAVE | `avoid_nested_conditional_expressions` |
| `avoid_non_ascii_symbols` | HAVE | `avoid_non_ascii_symbols` |
| `avoid_non_configurable_callbacks_in_init_state` | TODO | TODO — see [proposal](../../../plans/tier_1_quick_wins/proposal_avoid_non_configurable_callbacks_in_init_state.md) |
| `avoid_non_exhaustive_switch_on_sealed_classes` | HAVE | `require_exhaustive_sealed_switch` |
| `avoid_non_null_assertion` | HAVE | `avoid_non_null_assertion` |
| `avoid_passing_async_when_sync_expected` | HAVE | `avoid_passing_async_when_sync_expected` |
| `avoid_redundant_async` | HAVE | `avoid_redundant_async` |
| `avoid_redundant_async_on_load` | HAVE | `avoid_redundant_async_on_load` |
| `avoid_returning_widgets` | HAVE | `avoid_returning_widgets` |
| `avoid_shrink_wrap_in_lists` | HAVE | `avoid_shrink_wrap_in_lists` |
| `avoid_substring` | HAVE | `avoid_string_substring` |
| `avoid_throw_in_catch_block` | HAVE | `avoid_throw_in_catch_block` |
| `avoid_top_level_members_in_tests` | HAVE | `avoid_top_level_members_in_tests` |
| `avoid_unnecessary_conditionals` | HAVE | `avoid_unnecessary_conditionals` |
| `avoid_unnecessary_setstate` | HAVE | `avoid_unnecessary_setstate` |
| `avoid_unnecessary_type_assertions` | HAVE | `avoid_unnecessary_type_assertions` |
| `avoid_unnecessary_type_casts` | HAVE | `avoid_unnecessary_type_casts` |
| `avoid_unrelated_type_assertions` | HAVE | `avoid_unrelated_type_assertions` |
| `avoid_unused_parameters` | HAVE | `avoid_unused_parameters` |
| `avoid_wrapping_in_padding` | HAVE | `avoid_wrapping_in_padding` |
| `ban_name` | HAVE | `banned_identifier_usage` |
| `binary_expression_operand_order` | HAVE | `binary_expression_operand_order` |
| `check_for_equals_in_render_object_setters` | HAVE | `check_for_equals_in_render_object_setters` |
| `consistent_update_render_object` | HAVE | `consistent_update_render_object` |
| `correct_game_instantiating` | TODO | TODO — see [proposal](../../../plans/tier_2_high_value/proposal_correct_game_instantiating.md) (Flame-specific) |
| `double_literal_format` | HAVE | `double_literal_format` |
| `format_comment` | HAVE | `format_comment_style` |
| `list_all_equatable_fields` | HAVE | `list_all_equatable_fields` |
| `member_ordering` | HAVE | `prefer_member_ordering` |
| `missing_test_assertion` | HAVE | `missing_test_assertion` |
| `newline_before_return` | HAVE | `prefer_blank_line_before_return` |
| `no_blank_line_before_single_return` | TODO | TODO — see [proposal](../../../plans/tier_1_quick_wins/proposal_no_blank_line_before_single_return.md) |
| `no_boolean_literal_compare` | HAVE | `no_boolean_literal_compare` |
| `no_empty_block` | HAVE | `no_empty_block` |
| `no_equal_arguments` | HAVE | `no_equal_arguments` |
| `no_equal_then_else` | HAVE | `no_equal_then_else` |
| `no_magic_number` | HAVE | `no_magic_number` |
| `no_object_declaration` | HAVE | `no_object_declaration` |
| `only_barrel_import` | TODO | TODO — see [proposal](../../../plans/tier_3_infrastructure/proposal_only_barrel_import.md) |
| `prefer_async_await` | HAVE | `prefer_async_await` |
| `prefer_commenting_analyzer_ignores` | HAVE | `prefer_commenting_analyzer_ignores` |
| `prefer_conditional_expressions` | HAVE | `prefer_conditional_expressions` |
| `prefer_const_border_radius` | HAVE | `prefer_const_border_radius` |
| `prefer_correct_edge_insets_constructor` | HAVE | `prefer_correct_edge_insets_constructor` |
| `prefer_correct_identifier_length` | HAVE | `prefer_correct_identifier_length` |
| `prefer_correct_test_file_name` | HAVE | `prefer_correct_test_file_name` |
| `prefer_correct_type_name` | HAVE | `prefer_correct_type_name` |
| `prefer_define_hero_tag` | HAVE | `prefer_define_hero_tag` |
| `prefer_dot_shorthands` | HAVE | `prefer_dot_shorthand` |
| `prefer_enums_by_name` | HAVE | `prefer_enums_by_name` |
| `prefer_extracting_callbacks` | HAVE | `prefer_extracting_callbacks` |
| `prefer_first` | HAVE | `prefer_list_first` |
| `prefer_first_or_null` | TODO | TODO — see [proposal](../../../plans/tier_1_quick_wins/proposal_prefer_first_or_null.md) |
| `prefer_immediate_return` | HAVE | `prefer_immediate_return` |
| `prefer_intl_name` | HAVE | `prefer_intl_name` |
| `prefer_iterable_of` | HAVE | `prefer_iterable_of` |
| `prefer_last` | HAVE | `prefer_list_last` |
| `prefer_match_file_name` | HAVE | `prefer_match_file_name` |
| `prefer_media_query_direct_access` | PARTIAL | `avoid_deprecated_use_inherited_media_query` — TODO extend, see [proposal](../../../plans/tier_2_high_value/proposal_extend_avoid_deprecated_use_inherited_media_query_dcm_parity.md) |
| `prefer_moving_to_variable` | HAVE | `prefer_moving_to_variable` |
| `prefer_named_record_fields` | PARTIAL | `avoid_positional_record_field_access` — saropa only flags accessing positional records via `$1`/`$2`, not declaring fields without names |
| `prefer_provide_intl_description` | HAVE | `prefer_providing_intl_description` |
| `prefer_single_quotes` | HAVE | `prefer_single_quotes_strict` |
| `prefer_single_widget_per_file` | HAVE | `prefer_single_widget_per_file` |
| `prefer_static_class` | HAVE | `prefer_static_class` |
| `prefer_trailing_comma` | HAVE | `prefer_trailing_comma` |
| `prefer_using_list_view` | HAVE | `prefer_using_list_view` |
| `provide_correct_intl_args` | HAVE | `provide_correct_intl_args` |
| `tag_name` | HAVE | `prefer_kebab_tag_name` |
| `use_design_system` | TODO | TODO — see [proposal](../../../plans/tier_3_infrastructure/proposal_use_design_system.md) |
| `use_setstate_synchronously` | HAVE | `use_setstate_synchronously` |

Also reports continuous metrics (cyclomatic complexity, LOC, Halstead-style maintainability index) via an HTML/console report — see [Architecture Differences](#architecture-differences).

## What You Gain

dart_code_linter covers 82 rules from the DCM lineage plus a metrics report. saropa_lints matches that coverage (88%) and adds rules entirely outside its scope:

**State Management**
- Full Riverpod, Bloc, Provider, and GetX rule sets — dart_code_linter has minimal package-specific coverage

**Security**
- `avoid_hardcoded_credentials`, `avoid_logging_sensitive_data`, `require_secure_storage`, `avoid_weak_cryptographic_algorithms`

**Accessibility**
- `require_semantics_label`, `avoid_small_touch_targets`, `avoid_color_only_indicators`

## What You Lose

<!-- cspell:ignore Halstead -->
| dart_code_linter Feature | Alternative |
|---------------------------|--------------|
| Continuous maintainability-index / Halstead report (HTML/console) | Use `dart run saropa_lints:project_health` for a different structural view, or keep dart_code_linter's reporter alongside saropa_lints |
| `avoid_initializing_in_on_mount`, `correct_game_instantiating` (Flame-specific) | No saropa_lints equivalent — saropa_lints doesn't target the Flame game engine |
| `use_design_system` (configurable widget→design-system-replacement mapping) | No direct equivalent; enforce via code review |

## Suppressing Rules

```dart
// dart_code_linter style
// ignore: avoid-returning-widgets

// saropa_lints style
// ignore: avoid_returning_widgets
```

Note: dart_code_linter uses hyphens in its YAML config keys but underscores in `// ignore:` comments (inherited from DCM); saropa_lints uses underscores throughout.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
