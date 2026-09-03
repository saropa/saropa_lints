# Migrating from flutter_quality_lints

This guide helps you migrate from [`flutter_quality_lints`](https://pub.dev/packages/flutter_quality_lints) to `saropa_lints`.

## Why Migrate?

| Feature | flutter_quality_lints | saropa_lints |
|---------|------------------------|--------------|
| **Rule count** | 18 rules | 2300+ custom rules |
| **Focus** | Code-health checks (methods, magic numbers, nesting) plus HTML/JSON/Markdown trend reports | Security, accessibility, performance, and 2300+ Flutter-specific patterns |
| **Configuration** | Flat rule list | 5 progressive tiers |
| **Reliability** | Several shipped rules are non-functional stubs (see below) | Actively maintained, verified against fixtures |

**Note**: As shipped, `enforce_layer_dependencies` compares source text instead of file paths and never matches, and `prefer_trailing_commas`'s comma-detection logic is a stub — neither rule actually fires. saropa's equivalents (`avoid_ui_in_domain_layer` / `avoid_cross_feature_dependencies`, `prefer_trailing_comma`) are functioning implementations of the same intent.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_quality_lints: ^1.0.0

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

## Rule Mapping

Coverage: 18 rules — 15 HAVE (83%), 2 PARTIAL, 1 TODO (5%)

| flutter_quality_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_build_context_across_async` | HAVE | `require_mounted_check_after_await` |
| `avoid_empty_catch_blocks` | HAVE | `avoid_swallowing_exceptions` (alias: `avoid_empty_catch`) |
| `avoid_hardcoded_secrets` | HAVE | `avoid_hardcoded_credentials` |
| `avoid_hardcoded_strings` | HAVE | `avoid_hardcoded_strings_in_ui` |
| `avoid_late_keyword` | HAVE | `avoid_late_keyword` |
| `avoid_long_methods` | HAVE | `avoid_long_functions` |
| `avoid_magic_numbers` | HAVE | `no_magic_number` |
| `avoid_nested_conditionals` | PARTIAL | `avoid_deep_nesting` — 3-level if-only threshold in theirs vs. saropa's 5-level all-block-nesting scope |
| `avoid_widget_rebuilds` | PARTIAL | `prefer_const_widgets` covers part of this; no saropa rule flags inline `.map()`/inline closures inside `build()` as a rebuild-cost pattern specifically |
| `enforce_layer_dependencies` | HAVE | `avoid_ui_in_domain_layer` / `avoid_cross_feature_dependencies` (their rule is a non-functional stub as shipped — compares source text, never matches) |
| `maximum_lines_per_file` | HAVE | `avoid_long_length_files` / `avoid_very_long_length_files` |
| `prefer_const_widgets` | HAVE | `prefer_const_widgets` |
| `prefer_early_return` | HAVE | `prefer_early_return` |
| `prefer_named_parameters` | HAVE | `prefer_named_parameters` |
| `prefer_single_widget_per_file` | HAVE | `prefer_single_widget_per_file` |
| `prefer_slivers_over_columns` | HAVE | `prefer_sliver_for_mixed_scroll` |
| `prefer_stateless_widgets` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_stateless_widgets.md). Their rule inspects a `State` class's actual mutable-state usage (setState calls, uninitialized fields, lifecycle methods, controller fields) to suggest converting to `StatelessWidget`; saropa has no rule that performs this specific cross-check. |
| `prefer_trailing_commas` | HAVE | `prefer_trailing_comma` (their comma-detection logic is a stub as shipped and never fires) |

## Suppressing Rules

```dart
// flutter_quality_lints style
// ignore: avoid_magic_numbers

// saropa_lints style
// ignore: no_magic_number
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
