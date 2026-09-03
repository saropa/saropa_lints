# Migrating from design_system_lints

This guide helps you migrate from `design_system_lints` (Sidecar framework) to `saropa_lints`.

> **This package is defunct.** `design_system_lints` is built on the Sidecar analysis
> framework, which has been abandoned since 2022. It does not compile against current
> Dart or Flutter SDKs and will never receive a fix. Remove it from your `pubspec.yaml`
> immediately — keeping a dead dependency creates false confidence that design-token
> checks are running when they are not.

## Why Migrate?

| Feature | design_system_lints | saropa_lints |
|---------|----------------------|--------------|
| **Rule count** | 7 active rules | 2300+ custom rules |
| **Focus** | Flags hardcoded design values (color, edge insets, box shadow, radius, text style, theme data, box constraints) against a project's `@designSystem`-annotated source | Flags hardcoded design values against Flutter's own `Theme.of(context)` |
| **Architecture** | **Sidecar framework (defunct since 2022)** | custom_lint plugin (actively maintained) |
| **Configuration** | Per-project `@designSystem` annotation on a source class | 5 progressive tiers |
| **Maintenance** | **Abandoned — does not run on current SDKs** | Actively maintained |
| **Cost** | Free & open source | Free & open source |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  design_system_lints: ^0.1.0
  sidecar: ^0.1.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

Remove the Sidecar plugin configuration, then generate saropa_lints config:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Rule Mapping

Coverage: 7 rules — 1 PARTIAL, 6 TODO (85%)

| design_system_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `color` | PARTIAL | `avoid_hardcoded_colors` — flags `Color(0x...)`/`Colors.x` against `Theme.of(context)`, not an arbitrary `@designSystem`-annotated source class |
| `edge_insets` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_design_system.md) |
| `box_shadow` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_edge_insets.md) |
| `radius` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_design_system.md) |
| `text_style` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_text_style.md) (saropa's similarly-named `avoid_hardcoded_text_styles` is a false cognate about `onHover`, not a match) |
| `theme_data` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_theme_data.md) |
| `box_constraints` | TODO | TODO — see [proposal](../../../bugs/tier_3_infrastructure/proposal_use_design_system.md) |

All 6 `TODO` rows depend on a generic `@designSystem`-annotated source class mechanism that saropa_lints does not implement; saropa_lints' `avoid_hardcoded_colors` instead checks against Flutter's built-in `Theme.of(context)`.

## What You Gain

An actively maintained plugin architecture (Sidecar is defunct), plus 2300+ rules covering security, accessibility, performance, and library-specific patterns (GetX, Riverpod, Bloc, Provider, Firebase, Isar, Hive) that `design_system_lints` never attempted even at its peak.

## What You Lose

| design_system_lints Feature | Alternative |
|------------------------------|-------------|
| `@designSystem`-annotated arbitrary source class recognition | saropa_lints checks against `Theme.of(context)` directly; annotate your design-system class as a `ThemeExtension` to get coverage |
| Hardcoded edge insets / box shadow / radius / box constraints detection | Manual review, or a project-specific custom_lint rule |

If your project has a bespoke `@designSystem` source class it can't migrate onto `ThemeExtension`, there is no drop-in saropa_lints equivalent for those checks yet.

## Suppressing Rules

```dart
// design_system_lints style
// ignore: color

// saropa_lints style
// ignore: avoid_hardcoded_colors
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
