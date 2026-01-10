# Migrating from solid_lints

This guide helps you migrate from `solid_lints` to `saropa_lints`.

## Why Migrate?

| Feature | solid_lints | saropa_lints |
|---------|-------------|--------------|
| **Custom rules** | 16 rules | 821+ custom rules |
| **Framework** | custom_lint | custom_lint |
| **Focus** | Clean code principles | Flutter-specific analysis |
| **Configuration** | Single config | 5 progressive tiers |
| **Specialization** | SOLID principles | Security, accessibility, state management |
| **Cost** | Free & open source | Free & open source |

**Good news**: saropa_lints implements 15 of solid_lints' 16 custom rules (94% coverage), plus 800+ additional rules.

**Note**: Both packages use custom_lint, so you can only use one at a time (or carefully merge configurations).

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  solid_lints: ^0.2.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^1.3.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - custom_lint

# solid_lints uses custom_lint.yaml for config

# After
analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### Step 3: Remove solid_lints config

Delete or rename your `custom_lint.yaml` file if it contained solid_lints configuration.

### Step 4: Run the linter

```bash
dart run custom_lint
```

## Choosing a Tier

solid_lints has one configuration. saropa_lints offers progressive tiers:

| solid_lints Usage | saropa_lints Tier | Description |
|-------------------|-------------------|-------------|
| Basic | **Essential** (~100 rules) | Critical bugs, memory leaks, security |
| Full config | **Recommended** (~280 rules) | Balanced coverage |
| + strict mode | **Professional** (~560 rules) | Enterprise-grade |
| Maximum | **Comprehensive** (~700 rules) | Quality obsessed |
| Everything | **Insanity** (821+ rules) | Every single rule |

**Start with `recommended`** - it provides similar coverage to solid_lints plus Flutter-specific rules.

## Rule Mapping

All 16 solid_lints custom rules are mapped below. saropa_lints implements 15 of them (94%):

### Complete solid_lints Coverage

| solid_lints Rule | saropa_lints Equivalent | Status |
|------------------|------------------------|--------|
| `cyclomatic_complexity` | `avoid_long_functions` | ✅ Different approach (line-based) |
| `function_lines_of_code` | `avoid_long_functions` | ✅ Implemented |
| `number_of_parameters` | `avoid_long_parameter_list` | ✅ Implemented |
| `avoid_returning_widgets` | `avoid_returning_widgets` | ✅ Implemented |
| `avoid_unnecessary_type_assertions` | `avoid_unnecessary_type_assertions` | ✅ Implemented |
| `avoid_unnecessary_type_casts` | `avoid_unnecessary_type_casts` | ✅ Implemented |
| `avoid_unused_parameters` | `avoid_unused_parameters` | ✅ Implemented |
| `avoid_late_keyword` | `avoid_late_keyword` | ✅ Implemented |
| `avoid_using_api` | — | ❌ Not implemented (layer architecture) |
| `avoid_final_with_getter` | `avoid_unnecessary_getter` | ✅ Implemented |
| `avoid_unnecessary_return_variable` | `prefer_immediate_return` | ✅ Implemented |
| `member_ordering` | `member_ordering` | ✅ Implemented |
| `newline_before_return` | `newline_before_return` | ✅ Implemented |
| `no_empty_block` | `no_empty_block` | ✅ Implemented |
| `no_magic_number` | `no_magic_number` | ✅ Implemented |
| `avoid_debug_print_in_release` | `avoid_debug_print` | ✅ Implemented |

### The Missing Rule: avoid_using_api

solid_lints' `avoid_using_api` is a configurable rule that restricts API usage by:
- Source package
- Class name
- Identifier / named parameter
- Glob patterns for file inclusion/exclusion

This is useful for enforcing architectural boundaries (e.g., "UI layer cannot call database directly").

saropa_lints provides similar functionality through specific rules:
- `avoid_direct_data_access_in_ui` - UI shouldn't access data layer directly
- `avoid_ui_in_domain_layer` - Domain layer shouldn't reference UI
- `avoid_cross_feature_dependencies` - Features should be isolated

For configurable API restriction, this remains a gap. See our [ROADMAP](../../ROADMAP.md) for `avoid_banned_api`.

### SOLID Principles Coverage

solid_lints focuses on SOLID principles. saropa_lints covers these through different rules:

| SOLID Principle | saropa_lints Rules |
|-----------------|-------------------|
| Single Responsibility | `avoid_god_class`, `avoid_long_functions`, `avoid_long_files` |
| Open/Closed | `prefer_abstract_dependencies`, `prefer_interface_class` |
| Liskov Substitution | Type safety rules, `avoid_unsafe_cast` |
| Interface Segregation | `avoid_too_many_dependencies`, architecture rules |
| Dependency Inversion | `avoid_direct_data_access_in_ui`, `avoid_service_locator_in_widgets` |

## What You Gain

### Rules solid_lints Doesn't Have

saropa_lints includes Flutter-specific rules beyond solid_lints' scope:

**Security (15+ rules)**
- `avoid_hardcoded_credentials` - Catches secrets in code
- `avoid_logging_sensitive_data` - PII protection
- `require_secure_storage` - SharedPreferences warnings
- `avoid_token_in_url` - Auth token exposure
- `require_certificate_pinning` - HTTPS security

**Accessibility (15+ rules)**
- `require_semantics_label` - Screen reader support
- `avoid_small_touch_targets` - Touch target sizing
- `avoid_color_only_indicators` - Color blindness support
- `require_minimum_contrast` - WCAG compliance

**Memory Management (20+ rules)**
- `require_dispose` - Full resource disposal tracking
- `require_timer_cancellation` - Timer leak prevention
- `require_stream_controller_dispose` - Stream cleanup
- `always_remove_listener` - Listener leak prevention

**State Management (25+ rules)**
- `avoid_bloc_event_in_constructor` - Bloc anti-patterns
- `avoid_watch_in_callbacks` - Riverpod best practices
- `require_notify_listeners` - ChangeNotifier checks
- `require_mounted_check` - Async setState protection

**Lifecycle Safety (10+ rules)**
- `avoid_context_in_initstate_dispose` - Prevents common Flutter bug
- `pass_existing_future_to_future_builder` - Prevents rebuild loops
- `avoid_recursive_widget_calls` - Infinite loop prevention

## What You Lose

solid_lints has some features saropa_lints approaches differently:

| solid_lints Feature | saropa_lints Alternative |
|---------------------|-------------------------|
| Cyclomatic complexity metric | `avoid_long_functions`, `avoid_complex_conditions` |
| Lines of executable code | `avoid_long_files`, `avoid_long_functions` |
| Number of parameters metric | `avoid_long_parameter_list` |
| SOLID-focused messaging | Architecture rules with different naming |

## Suppressing Rules

The syntax is identical (both use custom_lint):

```dart
// solid_lints style
// ignore: avoid_returning_widgets

// saropa_lints style (same!)
// ignore: avoid_returning_widgets
```

## Configuration Differences

### solid_lints Configuration

```yaml
# custom_lint.yaml
custom_lint:
  rules:
    - avoid_returning_widgets
    - cyclomatic_complexity:
        max_complexity: 10
    - number_of_parameters:
        max_parameters: 5
```

### saropa_lints Configuration

```yaml
# analysis_options.yaml
custom_lint:
  saropa_lints:
    tier: professional

  # Disable specific rules if needed
  rules:
    - avoid_returning_widgets: false
```

## Using Both (Not Recommended)

While technically possible, using both packages simultaneously is not recommended because:
- Both use custom_lint, potentially causing conflicts
- Duplicate rule coverage increases noise
- Configuration becomes complex

If you need specific solid_lints rules, saropa_lints likely has equivalents. Check our [full rule list](https://pub.dev/packages/saropa_lints).

## Migration Checklist

- [ ] Remove `solid_lints` from pubspec.yaml
- [ ] Add `saropa_lints` to pubspec.yaml
- [ ] Update analysis_options.yaml with tier config
- [ ] Remove or archive custom_lint.yaml
- [ ] Run `dart run custom_lint` to verify
- [ ] Address any new lint warnings
- [ ] Update CI pipeline if needed

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
