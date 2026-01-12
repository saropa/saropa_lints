# Migrating from DCM (Dart Code Metrics)

This guide helps you migrate from `dart_code_metrics` (DCM) to `saropa_lints`.

## Why Migrate?

| Feature | DCM | saropa_lints |
|---------|-----|--------------|
| **Rule count** | ~70 rules + metrics | 1450+ custom rules |
| **Focus** | Code metrics & complexity | Flutter-specific analysis |
| **Configuration** | Extensive YAML options | 5 progressive tiers |
| **Maintenance** | DCM Classic discontinued | Actively maintained |
| **Cost** | DCM v2+ requires license | Free & open source |

**Note**: If you're using DCM primarily for metrics (cyclomatic complexity, lines of code, etc.), saropa_lints focuses more on Flutter-specific patterns. Consider your primary use case.

## Architecture Differences

DCM and saropa_lints take different approaches to performance:

| Aspect | DCM | saropa_lints |
|--------|-----|--------------|
| **Architecture** | Precompiled binary | custom_lint plugin |
| **IDE integration** | Separate CLI tool | Real-time IDE feedback |
| **Performance** | Fast CLI, limited IDE | Full IDE support, memory scales with tier |
| **Installation** | Global binary + project config | Package dependency only |

**DCM's approach**: DCM moved to a precompiled binary to solve performance issues with running many rules in the Dart Analysis Server. This makes CLI analysis fast but limits real-time IDE feedback.

**saropa_lints' approach**: Uses the custom_lint plugin architecture for full IDE integration (squiggles, quick fixes, hover info). The tier system lets you control memory usage - start with `essential` (~256 rules) for lighter resource usage, scale up as needed.

**Recommendation**: For large codebases concerned about IDE performance, start with `essential` or `recommended` tier. Use higher tiers in CI where memory isn't constrained.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  dart_code_metrics: ^5.7.0

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
    - dart_code_metrics

dart_code_metrics:
  anti-patterns:
    - long-method
    - long-parameter-list
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
  rules:
    - avoid-returning-widgets
    - prefer-conditional-expressions

# After
analyzer:
  plugins:
    - custom_lint

custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Using Both Together

If you still need DCM's metrics alongside saropa_lints' rules:

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - dart_code_metrics
    - custom_lint

dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    lines-of-code: 100

custom_lint:
  saropa_lints:
    tier: recommended
```

```yaml
# pubspec.yaml
dev_dependencies:
  dart_code_metrics: ^5.7.0
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

## Choosing a Tier

DCM has granular metric thresholds. saropa_lints uses progressive tiers:

| DCM Usage | saropa_lints Tier | Description |
|-----------|-------------------|-------------|
| Minimal rules | **Essential** (~256 rules) | Critical bugs, memory leaks, security |
| Default config | **Recommended** (~573 rules) | Balanced coverage |
| Strict metrics | **Professional** (~979 rules) | Enterprise-grade |
| All rules enabled | **Comprehensive** (~1202 rules) | Quality obsessed |
| Maximum everything | **Insanity** (1450+ rules) | Every single rule |

**Start with `recommended`** - it provides broad coverage without overwhelming noise.

**Plus 114 optional stylistic rules** for team preferences (trailing commas, sorting, etc.) - see [stylistic rules](../../README_STYLISTIC.md).

## Rule Mapping

Many DCM rules have saropa_lints equivalents or enhancements:

### Anti-Patterns

| DCM Anti-Pattern | saropa_lints Equivalent | Enhancement |
|------------------|------------------------|-------------|
| `long-method` | `avoid_large_functions` | Context-aware thresholds |
| `long-parameter-list` | `avoid_many_parameters` | Builder pattern suggestions |

### Common Rules

| DCM Rule | saropa_lints Equivalent | Enhancement |
|----------|------------------------|-------------|
| `avoid-returning-widgets` | `avoid_returning_widgets` | Includes more patterns |
| `avoid-unnecessary-setstate` | `require_mounted_check`, `avoid_setstate_in_callbacks` | Async safety |
| `avoid-wrapping-in-padding` | `prefer_padding_property` | Auto-fix available |
| `prefer-const-border-radius` | `prefer_const_constructors` | Broader const detection |
| `avoid-shrink-wrap-in-lists` | `avoid_shrinkwrap_in_lists` | Performance warnings |
| `prefer-single-widget-per-file` | `one_widget_per_file` | Configurable exceptions |
| `avoid-expanded-as-spacer` | `prefer_spacer_over_expanded` | Clear guidance |
| `prefer-extracting-callbacks` | `avoid_large_closures` | Threshold-based |
| `avoid-border-all` | `prefer_border_symmetric` | Performance focus |
| `avoid-duplicate-exports` | `avoid_duplicate_exports` | Full detection |
| `prefer-correct-identifier-length` | `avoid_short_names`, `avoid_long_names` | Configurable |
| `avoid-nested-conditional-expressions` | `avoid_nested_ternaries` | Readability focus |
| `avoid-throw-in-catch-block` | `avoid_rethrow_without_context` | Stack trace preservation |
| `avoid-unnecessary-type-casts` | `unnecessary_cast` | Part of standard rules |
| `avoid-unrelated-type-assertions` | `avoid_impossible_type_checks` | Deep type analysis |
| `no-magic-number` | `avoid_magic_numbers` | Exemption support |
| `prefer-async-await` | `prefer_async_await` | Consistency focus |

### Flutter-Specific Rules

| DCM Rule | saropa_lints Equivalent | Enhancement |
|----------|------------------------|-------------|
| `avoid-unnecessary-stateful-widgets` | `prefer_stateless_widgets` | Detects unused state |
| `use-setstate-synchronously` | `require_mounted_check` | Async setState protection |
| `avoid-recursive-widget-calls` | `avoid_recursive_builds` | Infinite loop prevention |

## What You Gain

### Rules DCM Doesn't Have

saropa_lints includes Flutter-specific rules beyond DCM's scope:

**Lifecycle & State**
- `avoid_context_in_initstate_dispose` - Prevents common Flutter bug
- `pass_existing_future_to_future_builder` - Prevents rebuild loops
- `require_dispose` - Full resource disposal tracking

**Security**
- `avoid_hardcoded_credentials` - Catches secrets in code
- `avoid_logging_sensitive_data` - PII protection
- `require_secure_storage` - SharedPreferences warnings
- `avoid_http_urls` - HTTPS enforcement

**Accessibility**
- `require_semantics_label` - Screen reader support
- `avoid_small_touch_targets` - Touch target sizing
- `avoid_color_only_indicators` - Color blindness support

**State Management**
- `avoid_bloc_event_in_constructor` - Bloc anti-patterns
- `avoid_watch_in_callbacks` - Riverpod best practices
- `require_notify_listeners` - ChangeNotifier checks

## What You Lose

DCM provides some features saropa_lints doesn't focus on:

<!-- cspell:ignore cloc Halstead -->
| DCM Feature | Alternative |
|-------------|-------------|
| Cyclomatic complexity metrics | Use `dart analyze` or IDE plugins |
| Lines of code metrics | Use `cloc` or IDE extensions |
| Technical debt estimation | Manual review or other tools |
| HTML/JSON reports | Custom lint output formatting |
| Halstead metrics | Specialized metrics tools |

If metrics are critical, consider keeping DCM alongside saropa_lints.

## Suppressing Rules

The syntax is similar:

```dart
// DCM style
// ignore: avoid-returning-widgets

// saropa_lints style
// ignore: avoid_returning_widgets
```

Note: DCM uses hyphens, saropa_lints uses underscores in rule names.

## Configuration Differences

### DCM's Metric Thresholds

```yaml
# DCM style
dart_code_metrics:
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
    maximum-nesting-level: 5
```

### saropa_lints Tier Selection

```yaml
# saropa_lints style - choose a tier
custom_lint:
  saropa_lints:
    tier: professional  # essential | recommended | professional | comprehensive | insanity

# Or disable specific rules
custom_lint:
  rules:
    - avoid_magic_numbers: false
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
