# Migrating from very_good_analysis

This guide helps you migrate from `very_good_analysis` to Saropa Lints.

## Why Migrate?

| Feature | very_good_analysis | Saropa Lints |
|---------|-------------------|--------------|
| **Rule count** | 174 standard rules | 1450+ custom rules |
| **Rule types** | Dart linter rules | Deep custom analysis |
| **Configuration** | Single file | 5 progressive tiers + optional stylistic rules |
| **Specialization** | General best practices | Flutter-specific (accessibility, state management, security) |

**Note**: You can also use both packages together. They're complementary, not competing.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  very_good_analysis: ^6.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:very_good_analysis/analysis_options.yaml

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

If you want both VGA's standard Dart rules AND Saropa Lints' custom rules:

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint
```

Then generate saropa_lints configuration:

```bash
dart run saropa_lints:init --tier recommended
```

```yaml
# pubspec.yaml
dev_dependencies:
  very_good_analysis: ^6.0.0
  custom_lint: ^0.8.0
  saropa_lints: ^4.5.7
```

This gives you:
- 174 standard Dart linter rules from VGA
- 1450+ custom rules from saropa_lints

## Choosing a Tier

VGA has one configuration. Saropa Lints has five tiers to match your team's needs:

| VGA Equivalent | Saropa Lints Tier | Description |
|----------------|-------------------|-------------|
| Basic usage | **Essential** (~256 rules) | Critical bugs, memory leaks, security |
| Full VGA | **Recommended** (~573 rules) | Similar coverage + Flutter-specific |
| Stricter | **Professional** (~979 rules) | Enterprise-grade |
| Maximum | **Comprehensive** (~1202 rules) | Quality obsessed |
| Everything | **Insanity** (1450+ rules) | Every single rule |

**Start with `recommended`** - it's the closest to VGA's philosophy.

**Plus 114 optional stylistic rules** for team preferences (trailing commas, sorting, etc.) - see [stylistic rules](../../README_STYLISTIC.md).

## Rule Mapping

Many VGA rules have Saropa Lints equivalents that go deeper:

| VGA Rule | Saropa Lints Equivalent | Enhancement |
|----------|------------------------|-------------|
| `cancel_subscriptions` | `avoid_unassigned_stream_subscriptions`, `require_stream_controller_dispose` | Catches more patterns |
| `close_sinks` | `require_dispose`, `dispose_fields` | Full disposal tracking |
| `avoid_print` | `avoid_print_in_production`, `avoid_debug_print` | Context-aware |
| `use_key_in_widget_constructors` | `avoid_duplicate_widget_keys`, `require_keys_in_animated_lists` | More specific cases |
| `unawaited_futures` | `avoid_uncaught_future_errors`, `avoid_async_call_in_sync_function` | Error handling focus |

## What You Gain

### Flutter-Specific Rules

Saropa Lints includes rules VGA doesn't have:

**Lifecycle & State**
- `avoid_context_in_initstate_dispose` - Prevents common Flutter bug
- `require_mounted_check` - Catches async setState issues
- `pass_existing_future_to_future_builder` - Prevents rebuild loops

**Security**
- `avoid_hardcoded_credentials` - Catches secrets in code
- `avoid_logging_sensitive_data` - PII protection
- `require_secure_storage` - SharedPreferences warnings

**Accessibility**
- `require_semantics_label` - Screen reader support
- `avoid_small_touch_targets` - Touch target sizing
- `avoid_color_only_indicators` - Color blindness support

**State Management**
- `avoid_bloc_event_in_constructor` - Bloc anti-patterns
- `avoid_watch_in_callbacks` - Riverpod best practices
- `require_notify_listeners` - ChangeNotifier checks

## Suppressing Rules

The syntax is the same:

```dart
// VGA style (still works)
// ignore: public_member_api_docs

// Saropa Lints style
// ignore: avoid_hardcoded_strings_in_ui
```

## Related Packages

This guide applies similarly to other standard Dart linter packages:

### lints (Official Dart Package)

The official Dart team's recommended rules. Migration is identical to VGA:

```yaml
# Before
include: package:lints/recommended.yaml

# After (use both)
include: package:lints/recommended.yaml

analyzer:
  plugins:
    - custom_lint
```

Then run: `dart run saropa_lints:init --tier recommended`

### lint (by passsy)

A popular community alternative with opinionated rules:

```yaml
# Before
include: package:lint/analysis_options.yaml

# After (use both)
include: package:lint/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint
```

Then run: `dart run saropa_lints:init --tier recommended`

### pedantic (Deprecated)

Google's internal Dart style guide, now deprecated in favor of `lints`:

```yaml
# Before (deprecated)
include: package:pedantic/analysis_options.yaml

# After - migrate to lints + saropa_lints
include: package:lints/recommended.yaml

analyzer:
  plugins:
    - custom_lint
```

Then run: `dart run saropa_lints:init --tier recommended`

### Comparison

| Package | Maintainer | Status | Rules |
|---------|------------|--------|-------|
| `very_good_analysis` | VGV | Active | 174 |
| `lints` | Dart team | Active (official) | ~60 |
| `lint` | passsy | Active | ~100 |
| `pedantic` | Google | Deprecated | ~30 |
| `flutter_lints` | Flutter team | Active (Flutter default) | ~30 |

All of these are **standard Dart analyzer rules** and work alongside saropa_lints (custom_lint rules). See our [flutter_lints guide](using_with_flutter_lints.md) for more details.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
