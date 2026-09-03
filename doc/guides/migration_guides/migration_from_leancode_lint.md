# Migrating from leancode_lint

This guide helps you migrate from `leancode_lint` to `saropa_lints`.

## Why Migrate?

| Feature | leancode_lint | saropa_lints |
|---------|----------------|--------------|
| **Rule count** | 23 rules | 2300+ custom rules |
| **Focus** | Bloc/Cubit conventions, hooks, design-system enforcement | Flutter-specific analysis across security, accessibility, performance, and every major state-management library |
| **Architecture** | `analysis_server_plugin` (v27.0.0+) | custom_lint plugin |
| **Configuration** | Programmatic `LeanCodeLintConfig` (custom plugin package) | 5 progressive tiers, `analysis_options.yaml` |
| **Maintenance** | Actively maintained (LeanCode) | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: leancode_lint has already migrated to `analysis_server_plugin`, the same underlying analyzer-plugin API saropa_lints uses natively — so both packages can run side by side without a `custom_lint` compatibility layer.

## Architecture Differences

| Aspect | leancode_lint | saropa_lints |
|--------|----------------|--------------|
| **Architecture** | `analysis_server_plugin` | `analysis_server_plugin` (native) |
| **Configuration surface** | Programmatic (a companion Dart plugin package for custom config) | Declarative YAML tiers |
| **Design-system enforcement** | `use_design_system_item` — configurable ban list mapping Flutter widgets to your own design-system replacements | No direct equivalent — saropa_lints doesn't have a configurable widget-substitution mechanism |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  leancode_lint: ^27.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:leancode_lint/analysis_options.yaml

plugins:
  leancode_lint: ^27.0.0

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

## Choosing a Tier

leancode_lint ships one fixed rule set (with optional programmatic customization). saropa_lints offers progressive tiers:

| leancode_lint Usage | saropa_lints Tier | Description |
|------------------------|-------------------|--------------|
| Default rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Full config | **Recommended** (~900 rules) | Balanced coverage, includes Bloc/hooks rules |
| Strict naming | **Professional** (~1600 rules) | Enterprise-grade |

**Start with `recommended`** — it covers leancode_lint's Bloc, hooks, and Equatable checks plus everything outside leancode_lint's scope.

## Rule Mapping

Coverage: 23 rules — 9 HAVE (39%), 5 PARTIAL, 9 TODO (39%)

| leancode_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `add_cubit_suffix_for_your_cubits` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_add_cubit_suffix_for_your_cubits.md) |
| `avoid_build_context_in_blocs` | HAVE | `avoid_passing_build_context_to_blocs` |
| `avoid_catch_error` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_avoid_catch_error.md). saropa's `prefer_then_catcherror` recommends the opposite pattern (a documented philosophical conflict, not a gap) |
| `avoid_conditional_hooks` | HAVE | `avoid_conditional_hooks` |
| `avoid_context_read_in_build` | PARTIAL | `avoid_provider_in_init_state` / `prefer_context_read_in_callbacks` — saropa has initState-only and callbacks-only variants, none covers general `context.read` during `build()` |
| `avoid_direct_collection_equality_checks` | HAVE | `avoid_collection_equality_checks` |
| `avoid_single_child_in_multi_child_widgets` | PARTIAL | `avoid_single_child_column_row` — covers only Column/Row, not the sliver-group family |
| `bloc_related_class_naming` | PARTIAL | `prefer_bloc_event_suffix` / `prefer_bloc_state_suffix` — saropa only checks suffix presence, not that the name matches the related Bloc's subject |
| `bloc_subclasses_naming` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_bloc_subclasses_naming.md) |
| `catch_parameter_names` | PARTIAL | `prefer_correct_error_name` — checks only the exception parameter name, not the stack-trace parameter, and isn't configurable |
| `constructor_parameters_and_fields_should_have_the_same_order` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_constructor_parameters_and_fields_should_have_the_same_order.md) |
| `hook_widget_does_not_use_hooks` | HAVE | `avoid_unnecessary_hook_widgets` |
| `never_discard_build_context` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_never_discard_build_context.md) |
| `prefer_abstract_final_class` | PARTIAL | `prefer_extension_over_utility_class` — detects the same static-methods-only class shape but recommends `extension` instead of `abstract final class` |
| `prefer_center_over_align` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_center_over_align.md) (not active upstream in leancode_lint either) |
| `prefer_equatable_mixin` | HAVE | `require_extend_equatable` |
| `prefix_widgets_returning_slivers` | HAVE | `prefer_sliver_prefix` |
| `start_comments_with_space` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_start_comments_with_space.md) |
| `use_align` | HAVE | `prefer_align_over_container` |
| `use_dedicated_media_query_methods` | HAVE | `avoid_deprecated_use_inherited_media_query` |
| `use_design_system_item` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_design_system_item.md) |
| `use_padding` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_padding.md) |
| `missing_equatable_props` | HAVE | `list_all_equatable_fields` |

## What You Gain

leancode_lint covers Bloc, hooks, and Equatable conventions plus design-system enforcement. saropa_lints matches that ground and adds:

**State Management**
- Full Riverpod and Provider rule sets — leancode_lint has no equivalent since it targets Bloc/Cubit specifically
- `avoid_bloc_public_fields`, `avoid_bloc_public_methods`, `avoid_duplicate_bloc_event_handlers`, and 15+ more Bloc-specific rules

**Security & Accessibility**
- `avoid_hardcoded_credentials`, `require_semantics_label`, `avoid_small_touch_targets`, and 2000+ more rules outside leancode_lint's scope

## What You Lose

| leancode_lint Feature | Alternative |
|--------------------------|--------------|
| `use_design_system_item` — configurable widget→design-system-replacement mapping | No direct equivalent; enforce via code review or a project-specific lint |
| Programmatic `LeanCodeLintConfig` (e.g. `catchParameterNames`, `applicationPrefix`) | saropa_lints configuration is tier + YAML overrides, not a companion Dart plugin package |
| `constructor_parameters_and_fields_should_have_the_same_order` | No saropa_lints equivalent yet |

## Suppressing Rules

Both packages target the analyzer-plugin API, so the syntax is identical:

```dart
// leancode_lint / saropa_lints style (same)
// ignore: avoid_passing_build_context_to_blocs
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
