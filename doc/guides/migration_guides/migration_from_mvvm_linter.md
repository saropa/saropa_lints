# Migrating from mvvm_linter

This guide helps you migrate from [`mvvm_linter`](https://pub.dev/packages/mvvm_linter) (NerdzFlutter-MVVMLinter) to `saropa_lints`.

## Why Migrate?

| Feature | mvvm_linter | saropa_lints |
|---------|-------------|--------------|
| **Rule count** | 1 rule | 2300+ custom rules |
| **Focus** | MVVM member-ordering enforcement | Broad Dart/Flutter analysis, incl. general member ordering |
| **Configuration** | Single opinionated rule, no options | 5 progressive tiers |
| **Maintenance** | Small, single-purpose package | Actively maintained, broad scope |
| **Cost** | Free & open source | Free & open source |

`mvvm_linter` ships exactly one rule — `class_order_rule` — which enforces a 10-category MVVM-specific member order (constructor → callback fields → repository fields → final/const/static → late → other mutable → getter/backing-field/setter triad → getter/setter → public methods → private methods) with an auto-reorder quick fix.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  mvvm_linter: ^1.0.0

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
    - mvvm_linter

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

Coverage: 1 rules — 1 PARTIAL

| mvvm_linter Rule | Status | Saropa Rule / Action |
|---|---|---|
| `class_order_rule` | PARTIAL | `prefer_member_ordering` — saropa's rule is a flat 3-bucket member order (fields, constructors, methods, roughly) with an autofix, not the 10-category MVVM-specific ordering (constructor → callback fields → repository fields → final/const/static → late → other mutable → getter/backing-field/setter triad → getter/setter → public methods → private methods) that `class_order_rule` enforces. TODO — see [proposal](../../../plans/tier_1_quick_wins/proposal_class_order_rule.md) for the finer-grained MVVM ordering. |

## What You Gain

saropa_lints' general-purpose member-ordering rule (`prefer_member_ordering`) applies to every class in your codebase, not just MVVM view-models — plus 2300+ other rules covering lifecycle, security, accessibility, and performance patterns MVVM-specific tooling doesn't touch.

## What You Lose

`class_order_rule`'s 10-category granularity is MVVM-architecture-specific and stricter than saropa's flat ordering. If your team relies on that exact category breakdown (especially the getter/backing-field/setter triad grouping and the auto-reorder assist for it), keep `mvvm_linter` running alongside saropa_lints — the two plugins don't conflict.

```yaml
# analysis_options.yaml — running both
analyzer:
  plugins:
    - mvvm_linter
    - custom_lint
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
