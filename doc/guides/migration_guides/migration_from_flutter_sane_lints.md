# Migrating from flutter_sane_lints

This guide helps you migrate from
[`flutter_sane_lints`](https://github.com/gbassisp/extra_lints) (the `flutter_sane_lints` package
in the `extra_lints` repo) to `saropa_lints`.

## Why Migrate?

| Feature | flutter_sane_lints | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 2 rules | 2300+ custom rules |
| **Focus** | Ad-hoc string literals in widgets; `if` used instead of exhaustive `switch` on enums | Full-spectrum security, accessibility, performance, and library-specific analysis |
| **Configuration** | On/off via `custom_lint` | 5 progressive tiers |

`flutter_sane_lints` is a small, focused plugin covering two anti-patterns: passing a string
literal directly to a widget constructor (instead of an l10n reference), and using `if` to check
enum values where an exhaustive `switch` would catch missing cases. saropa_lints covers both
concepts natively — this is a clean sweep with no gaps.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  custom_lint:
  flutter_sane_lints:

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before and after — both use custom_lint the same way
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

Coverage: 2 rules — 2 HAVE (100%)

| flutter_sane_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_string_literals_inside_widget` | HAVE | `avoid_hardcoded_strings_in_ui` |
| `avoid_if_with_enum` | HAVE | `prefer_switch_with_enums` |

## Suppressing Rules

```dart
// flutter_sane_lints style
// ignore: avoid_string_literals_inside_widget
// ignore: avoid_if_with_enum

// saropa_lints style
// ignore: avoid_hardcoded_strings_in_ui
// ignore: prefer_switch_with_enums
```

## What You Gain

saropa_lints' i18n rule family covers translation-key validation, unused-locale-key detection, and
pluralization, well beyond the single literal-detection rule `flutter_sane_lints` offers, plus
2300+ rules covering security, accessibility, and Flutter-specific patterns entirely outside
`flutter_sane_lints`'s scope.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
