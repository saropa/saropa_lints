# Migrating from df_safer_dart_lints

This guide helps you migrate from `df_safer_dart_lints` to `saropa_lints`.

## Why Migrate?

| Feature | df_safer_dart_lints | saropa_lints |
|---------|----------------------|--------------|
| **Rule count** | 9 rule classes / 18 lint codes (WARNING + ERROR variant of each) | 2300+ custom rules |
| **Focus** | Annotation-gated safety markers (`@mustAwaitAllFutures`, `@sendable`, `@unsafe`, `Outcome` monad) | General-purpose Flutter-specific analysis without annotation gating |
| **Configuration** | Opt in per-declaration via the package's own annotations | 5 progressive tiers |
| **Maintenance** | Small, single-purpose package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: `df_safer_dart_lints` is built around its own annotation vocabulary (`@mustAwaitAllFutures`, `@sendable`, `@unsafe`, `Outcome`) with two severity tiers (WARNING/ERROR) per concept. saropa_lints' equivalents fire generically — every discarded return value or un-awaited future, not just annotation-marked ones — and don't offer a separate error-severity variant per rule.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  df_safer_dart_lints: ^1.0.0
  custom_lint: ^0.8.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

Remove the `df_safer_dart_lints` plugin entry, then generate saropa_lints config:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Rule Mapping

Coverage: 9 rules — 3 PARTIAL, 6 TODO (66%)

| df_safer_dart_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `must_use_outcome` | PARTIAL | `avoid_ignoring_return_values` — flags any discarded return value generically, not specifically an `Outcome` monad type |
| `must_await_all_futures` | PARTIAL | `avoid_unawaited_future` — fires generally; theirs is annotation-scoped (`@mustAwaitAllFutures`) with a separate error-severity tier |
| `must_handle_return` | PARTIAL | `avoid_ignoring_return_values` / `missing_use_result_annotation` — same generic-discard concept, not annotation-driven with two severity tiers |
| `no_future_outcome_type` | TODO | TODO — see [proposal](../../../plans/deferred/fpdart/proposal_no_future_outcome_type.md) |
| `must_be_anonymous` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_must_be_anonymous.md) |
| `must_be_strong_ref` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_must_be_strong_ref.md) |
| `no_futures` | TODO | TODO — see [proposal](../../../plans/deferred/fpdart/proposal_no_futures.md) |
| `must_use_unsafe_wrapper` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_must_use_unsafe_wrapper.md) |
| `sendable` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_sendable.md) |

All 6 `TODO` rows are gated on `df_safer_dart_lints`' own annotation markers (`@sendable`, `@unsafe`, etc.) that saropa_lints does not recognize.

## What You Gain

saropa_lints' `avoid_ignoring_return_values` and `avoid_unawaited_future` fire everywhere without requiring per-declaration annotations, plus 2300+ rules across security, accessibility, performance, and library-specific patterns (GetX, Riverpod, Bloc, Provider, Firebase, Isar, Hive) that `df_safer_dart_lints` doesn't attempt.

## What You Lose

| df_safer_dart_lints Feature | Alternative |
|------------------------------|-------------|
| Annotation-scoped opt-in enforcement (`@mustAwaitAllFutures`, `@sendable`, `@unsafe`) | saropa_lints' generic rules fire unconditionally; use `// ignore:` on the line for exceptions |
| Separate WARNING/ERROR severity variant per rule | Configure severity per rule in `analysis_options.yaml` via saropa_lints' severity overrides |
| `Outcome`-monad-specific discard checking | saropa_lints' `avoid_ignoring_return_values` covers all discarded returns, not `Outcome`-specific |

If your project relies on the annotation-gated opt-in model, keep `df_safer_dart_lints` alongside `saropa_lints`.

## Suppressing Rules

```dart
// df_safer_dart_lints style
// ignore: must_use_outcome

// saropa_lints style
// ignore: avoid_ignoring_return_values
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
