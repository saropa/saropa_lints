# Migrating from very_good_analysis

This guide helps you migrate from `very_good_analysis` to `saropa_lints`.

## Why Migrate?

| Feature | very_good_analysis | saropa_lints |
|---------|-------------------|--------------|
| **Rule count** | 174 standard rules | 500+ custom rules |
| **Rule types** | Dart linter rules | Deep custom analysis |
| **Configuration** | Single file | 5 progressive tiers |
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
  saropa_lints: ^0.1.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:very_good_analysis/analysis_options.yaml

# After
analyzer:
  plugins:
    - custom_lint

include: package:saropa_lints/tiers/recommended.yaml
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Using Both Together

If you want both VGA's standard Dart rules AND saropa's custom rules:

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  plugins:
    - custom_lint
```

```yaml
# pubspec.yaml
dev_dependencies:
  very_good_analysis: ^6.0.0
  custom_lint: ^0.8.0
  saropa_lints: ^0.1.0
```

This gives you:
- 174 standard Dart linter rules from VGA
- 500+ custom rules from saropa_lints

## Choosing a Tier

VGA has one configuration. saropa_lints has five tiers to match your team's needs:

| VGA Equivalent | saropa_lints Tier | Description |
|----------------|-------------------|-------------|
| Basic usage | **Essential** (~50 rules) | Critical bugs, memory leaks, security |
| Full VGA | **Recommended** (~150 rules) | Similar coverage + Flutter-specific |
| Stricter | **Professional** (~300 rules) | Enterprise-grade |
| Maximum | **Comprehensive** (~400 rules) | Quality obsessed |
| Everything | **Insanity** (500+ rules) | Every single rule |

**Start with `recommended`** - it's the closest to VGA's philosophy.

## Rule Mapping

Many VGA rules have saropa equivalents that go deeper:

| VGA Rule | saropa_lints Equivalent | Enhancement |
|----------|------------------------|-------------|
| `cancel_subscriptions` | `avoid_unassigned_stream_subscriptions`, `require_stream_controller_dispose` | Catches more patterns |
| `close_sinks` | `require_dispose`, `dispose_fields` | Full disposal tracking |
| `avoid_print` | `avoid_print_in_production`, `avoid_debug_print` | Context-aware |
| `use_key_in_widget_constructors` | `avoid_duplicate_widget_keys`, `require_keys_in_animated_lists` | More specific cases |
| `unawaited_futures` | `require_future_error_handling`, `avoid_async_call_in_sync_function` | Error handling focus |

## What You Gain

### Flutter-Specific Rules

saropa_lints includes rules VGA doesn't have:

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

// saropa_lints style
// ignore: avoid_hardcoded_strings_in_ui
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
