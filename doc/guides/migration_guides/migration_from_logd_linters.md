# Migrating from logd_linters

This guide helps you migrate from `logd_linters` to `saropa_lints`.

## Why Migrate?

| Feature | logd_linters | saropa_lints |
|---------|--------------|--------------|
| **Rule count** | 13 rules | 2300+ custom rules |
| **Focus** | `logd` logging library API contracts, arena lifecycle, formatter purity | Flutter-specific analysis, broad coverage |
| **Configuration** | Single config | 5 progressive tiers |
| **Scope** | The `logd` package's pooled `LogDocument`/`LogEngine`/`Logger`/`LogTag`/`Handler` API only | Security, accessibility, performance, state management, and more |
| **Cost** | Free & open source | Free & open source |

**Note**: `logd_linters` is a narrow companion package for the [`logd`](https://pub.dev/packages/logd) logging library — it enforces arena-pooling lifecycle rules (`release`/`releaseRecursive`, `try-finally` wrapping) and formatter-purity constraints specific to that package's design. saropa_lints has no dedicated `logd` support. If your project uses `logd`, keep `logd_linters` installed; it is not a general-purpose competitor to saropa_lints.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Add saropa_lints alongside logd_linters (do not remove logd_linters if you use logd)
dev_dependencies:
  logd_linters: ^<current>
  custom_lint: ^0.8.1
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
analyzer:
  plugins:
    - custom_lint
```

Then generate the saropa_lints configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

Both plugins run under the same `custom_lint` analyzer plugin host.

## Rule Mapping

Coverage: 13 rules — 1 HAVE (7%), 12 TODO (92%)

Twelve of `logd_linters`' 13 rules are specific to the `logd` package's arena-pooled `LogDocument`/`LogEngine`/`Logger`/`LogTag`/`Handler` API and have no saropa_lints equivalent — this is a low-priority gap unless saropa_lints adds dedicated `logd` support.

| logd_linters Rule | Status | Saropa Rule / Action |
|---|---|---|
| `logd_document_retained_across_cycles` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_missing_release_in_engine` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_checkout_without_release` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_formatter_performs_string_rendering` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_decorator_not_immutable` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_formatter_not_immutable` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_avoid_print_sink_in_production` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_logtag_use_bitmask` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_log_buffer_not_sunk` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_handler_missing_engine` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_handler_missing_dispose` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_freeze_on_unconfigured_logger` | TODO | TODO — see [proposal](../../../bugs/proposal_logd_linters_rules.md) (logd-specific) |
| `logd_metadata_set_duplicate` | HAVE | `avoid_duplicate_object_elements` (generic collection-literal duplicate detection covers duplicate metadata Set entries) |

## What You Gain

saropa_lints adds broad Flutter, security, accessibility, and state-management coverage that `logd_linters` does not attempt — see the [DCM migration guide](migration_from_dcm.md#what-you-gain) for representative examples.

## What You Lose

Nothing directly — `logd_linters`' arena-lifecycle and formatter-purity checks (`try-finally` release tracking, `@immutable` enforcement on formatters/decorators, bitmask-comparison detection) are specific to the `logd` package's pooled-object design and have no saropa_lints equivalent. Keep `logd_linters` installed if you use `logd`.

## Suppressing Rules

```dart
// logd_linters style
// ignore: logd_checkout_without_release

// saropa_lints style (same syntax, both use custom_lint)
// ignore: avoid_duplicate_object_elements
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
