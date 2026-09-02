# Migrating from context_plus_lint

This guide helps you migrate from `context_plus_lint` to `saropa_lints`.

## Why Migrate?

| Feature | context_plus_lint | saropa_lints |
|---------|--------------------|--------------|
| **Rule count** | 4 rules | 2300+ custom rules |
| **Focus** | `context_plus` package API correctness | Flutter-specific analysis, broad coverage |
| **Configuration** | Single config | 5 progressive tiers |
| **Scope** | `context.use()` / `Ref` lifecycle only | Security, accessibility, performance, state management, and more |
| **Cost** | Free & open source | Free & open source |

**Note**: `context_plus_lint` is a narrow, single-purpose companion package for [`context_plus`](https://pub.dev/packages/context_plus) — it does not compete with saropa_lints on general-purpose coverage. If your project depends on `context_plus`, keep `context_plus_lint` installed alongside saropa_lints; there is no overlap to resolve.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Add saropa_lints alongside context_plus_lint (do not remove context_plus_lint)
dev_dependencies:
  context_plus_lint: ^<current>
  custom_lint: ^0.8.0
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

Both plugins run under the same `custom_lint` analyzer plugin host, so no further wiring is needed.

## Rule Mapping

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 4 TODO (100%).

`context_plus_lint`'s 4 rules are all specific to the `context_plus` package's `context.use()` / `Ref` API and have no saropa_lints equivalent — saropa_lints has no `context_plus` integration today.

| context_plus_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `context_use_unique_key` | TODO | TODO — no proposal filed yet |
| `context_ref_reassignment` | TODO | TODO — no proposal filed yet |
| `wrong_ref_declaration` | TODO | TODO — no proposal filed yet |
| `wrong_ref_type` | TODO | TODO — no proposal filed yet |

## What You Gain

saropa_lints adds broad Flutter, security, accessibility, and state-management coverage that `context_plus_lint` does not attempt — see the [DCM migration guide](migration_from_dcm.md#what-you-gain) for representative examples across security, accessibility, and lifecycle rules.

## What You Lose

Nothing — `context_plus_lint` is a `context_plus`-specific companion, not a general-purpose linter. Keep it installed if you use `context_plus`; saropa_lints does not replace it.

## Suppressing Rules

```dart
// context_plus_lint style
// ignore: context_use_unique_key

// saropa_lints style (same syntax, both use custom_lint)
// ignore: avoid_returning_widgets
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
