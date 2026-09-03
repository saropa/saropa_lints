# Migrating from flutter_hooks_lint

This guide helps you migrate from `flutter_hooks_lint` to `saropa_lints`.

## Why Migrate?

| Feature | flutter_hooks_lint | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 7 rules | 2300+ custom rules (5+ Flutter Hooks-specific) |
| **Focus** | `flutter_hooks` API correctness | Flutter-specific analysis, broad coverage |
| **Configuration** | Single config | 5 progressive tiers |
| **Quick fixes** | 5 of 7 rules | Yes, per-rule (see mapping below) |
| **Cost** | Free & open source | Free & open source |

**Good news**: saropa_lints implements the core `flutter_hooks` correctness rules (hooks-outside-build, unused HookWidget, `use`-prefix naming) plus broader coverage across the rest of the codebase.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_hooks_lint: ^0.x.0

# After
dev_dependencies:
  custom_lint:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

Coverage: 7 rules — 4 HAVE (57%), 1 PARTIAL, 2 TODO (28%)

| flutter_hooks_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `hooks_avoid_nesting` | HAVE | `avoid_hooks_outside_build` |
| `hooks_avoid_within_class` | HAVE | `avoid_hooks_outside_build` (same detection: a hook call not directly inside a widget's `build()` method, including one wrapped in a class method) |
| `hooks_name_convention` | HAVE | `prefer_use_prefix` |
| `hooks_extends` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_hooks_extends.md) (checks the widget extends `HookWidget`/`HookConsumerWidget`, not just call location) |
| `hooks_unuse_widget` | HAVE | `avoid_unnecessary_hook_widgets` |
| `hooks_memoized_consideration` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_hooks_memoized_consideration.md) (flags expensive initializers not wrapped in `useMemoized()`) |
| `hooks_callback_consideration` | PARTIAL | `prefer_use_callback` — only flags inline closures passed directly as callback props, not `useMemoized(() => fn, [...])` rewritten as `useCallback` |

## What You Gain

Beyond `flutter_hooks` correctness, saropa_lints covers the rest of your codebase — security, accessibility, performance, and state-management rules for Bloc, Riverpod, Provider, and GetX (see the [DCM migration guide](migration_from_dcm.md#what-you-gain) for representative examples).

## What You Lose

| flutter_hooks_lint Feature | Alternative |
|---|---|
| `hooks_extends` — verifies widget inheritance (`HookWidget`/`HookConsumerWidget`), not just call location | No direct equivalent; `avoid_hooks_outside_build` catches misplaced calls but not the missing base class |
| `hooks_memoized_consideration` — suggests wrapping expensive initializers in `useMemoized()` | No direct equivalent |
| Auto-fix on `hooks_callback_consideration`'s `useMemoized(() => fn)` → `useCallback` rewrite | `prefer_use_callback` covers inline closures only, with no fix for the `useMemoized`-wrapped-function case |

## Suppressing Rules

```dart
// flutter_hooks_lint style
// ignore: hooks_unuse_widget

// saropa_lints style
// ignore: avoid_unnecessary_hook_widgets
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
