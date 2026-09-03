# Migrating from flutter_best_practices_lints

This guide helps you migrate from `flutter_best_practices_lints` to `saropa_lints`.

## Why Migrate?

| Feature | flutter_best_practices_lints | saropa_lints |
|---------|-------------------------------|--------------|
| **Rule count** | 5 rules | 2300+ custom rules |
| **Focus** | File structure and class-naming conventions | Flutter-specific analysis, broad coverage |
| **Configuration** | Single config | 5 progressive tiers |
| **Cost** | Free & open source | Free & open source |

**Note**: `flutter_best_practices_lints` is a small, focused package covering file/class naming and a few widget-hygiene rules. On two of its five rules it takes a documented, opposite position to saropa_lints — see the Rule Mapping table below before enabling both.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_best_practices_lints: ^0.5.0

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
    - custom_lint
custom_lint:
  rules:
    - matching_class_and_file_name
    - single_class_per_file
    - prefer_widget_class_over_widget_helper
    - avoid_widget_operator_equals
    - prefer_media_query_partial_methods

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

## Rule Mapping

Coverage: 5 rules — 2 HAVE (40%), 1 PARTIAL, 2 TODO (40%)

| flutter_best_practices_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `single_class_per_file` | PARTIAL | `prefer_one_widget_per_file` — only counts Widget classes and lacks the abstract-interface/impl exception; also opt-in in saropa_lints vs. default-on here |
| `matching_class_and_file_name` | HAVE | `prefer_match_file_name` |
| `prefer_widget_class_over_widget_helper` | TODO | N/A — philosophical conflict: saropa_lints' `prefer_widget_methods_over_classes` recommends the **opposite** (private `_build*` methods over extracted widget classes) |
| `avoid_widget_operator_equals` | TODO | N/A — philosophical conflict: saropa_lints' `require_extend_equatable` fires on any `==` override and suggests extending Equatable, which this rule argues against for widgets specifically |
| `prefer_media_query_partial_methods` | HAVE | `prefer_dedicated_media_query_method` |

## What You Gain

saropa_lints covers file/class naming plus everything else — security, accessibility, performance, lifecycle, and state-management rules (see the [DCM migration guide](migration_from_dcm.md#what-you-gain) for representative examples).

## What You Lose

| flutter_best_practices_lints Feature | Alternative |
|---|---|
| `prefer_widget_class_over_widget_helper` (extract `_build*` methods into widget classes) | saropa_lints takes the opposite position via `prefer_widget_methods_over_classes` — pick one and disable the other |
| `avoid_widget_operator_equals` (discourages `operator ==` on widgets) | saropa_lints' `require_extend_equatable` is more general and doesn't carve out a widget exception — disable it on widget files if you want this behavior |
| `single_class_per_file`'s `State`-class exception | `prefer_one_widget_per_file` doesn't special-case abstract interface/impl pairs |

## Suppressing Rules

```dart
// flutter_best_practices_lints style
// ignore: matching_class_and_file_name

// saropa_lints style
// ignore: prefer_match_file_name
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
