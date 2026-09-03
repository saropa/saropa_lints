# Migrating from flutter_custom_lints

This guide helps you migrate from [`flutter_custom_lints`](https://pub.dev/packages/flutter_custom_lints)
(github.com/bahricanyesil/flutter-custom-lints) to `saropa_lints`.

## Why Migrate?

| Feature | flutter_custom_lints | saropa_lints |
|---------|------------------------|--------------|
| **Rule count** | 5 rules | 2300+ custom rules |
| **Focus** | General-purpose disposal, type-safety, and null-safety checks | Comprehensive security, accessibility, performance, and Flutter-specific analysis |
| **Configuration** | Flat rule set | 5 progressive tiers + rule packs |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_custom_lints: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - flutter_custom_lints

# After
analyzer:
  plugins:
    - saropa_lints
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart analyze
```

## Rule Mapping

Coverage: 5 rules — 2 HAVE (40%), 1 PARTIAL, 2 TODO (40%)

| flutter_custom_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `dispose_controllers` | HAVE | `dispose_class_fields` / `dispose_widget_fields` |
| `no_as_type_assertion` | PARTIAL | `avoid_unsafe_cast` — only flags casts that can actually fail at runtime (more precise than flutter_custom_lints' unconditional flag on every `as`, but misses the "any `as` at all" strict-mode case) |
| `no_direct_iterable_access` | TODO | Flags any direct `[]` index access on `Iterable`/`List`, suggesting a project-defined `safeAt()` extension. TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_no_direct_iterable_access.md) |
| `no_null_force` | HAVE | `avoid_non_null_assertion` |
| `use_compare_without_case` | TODO | Flags `==`/`!=` between `String` operands, suggesting a `compareWithoutCase()` extension; saropa's `avoid_case_sensitive_path_comparison` is scoped to file paths only, not general string comparison. TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_use_compare_without_case.md) |

## What You Lose

`no_direct_iterable_access` and `use_compare_without_case` have no saropa_lints
equivalent — see the TODO rows above. Both are narrow, opinionated checks (index-access
style, string-comparison style) rather than correctness or security issues; if they are
load-bearing for your team's style guide, consider keeping flutter_custom_lints installed
alongside saropa_lints for just those two rules.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
