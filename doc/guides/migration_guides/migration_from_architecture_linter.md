# Migrating from architecture_linter

This guide helps you migrate from `architecture_linter` (Iteo) to `saropa_lints`.

## Why Migrate?

| Feature | architecture_linter | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 1 functional rule (banned-layer-import) + 3 self-diagnostics | 2300+ custom rules |
| **Focus** | Configurable N-layer banned-import graph | Fixed UI/domain/data layering + full-codebase quality, security, accessibility |
| **Configuration** | YAML-defined layers and banned import pairs | 5 progressive tiers |
| **Maintenance** | Small, single-purpose package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: `architecture_linter` is a narrow, single-purpose tool — a generic, user-configurable "layer A must not import layer B" engine plus its own config-error diagnostics. saropa_lints doesn't attempt a generic per-project layer graph; instead it ships fixed, opinionated architecture rules (UI/domain/data separation, cross-feature dependencies) that fire without any layer-graph configuration.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  architecture_linter: ^1.0.0
  custom_lint: ^0.8.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

Remove the `architecture_linter` layer-graph config block, then generate saropa_lints config:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Rule Mapping

Coverage: 3 rules — 3 TODO (100%)

| architecture_linter Rule | Status | Saropa Rule / Action |
|---|---|---|
| Banned-layer-import check (dynamic, one lint per configured layer pair) | PARTIAL | `avoid_ui_in_domain_layer` / `avoid_direct_data_access_in_ui` — fixed UI/domain/data rules, not a generic user-configurable N-layer engine |
| `architecture_linter_config_file_error` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_architecture_linter_config_file_error.md) (tool self-diagnostic, not a code-quality rule) |
| `architecture_linter_layers_not_found` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_architecture_linter_layers_not_found.md) (tool self-diagnostic, not a code-quality rule) |
| `architecture_linter_banned_imports_not_found` | TODO | TODO — see [proposal](../../../bugs/declined/proposal_architecture_linter_banned_imports_not_found.md) (tool self-diagnostic, not a code-quality rule) |

The three `TODO` rows are meta-diagnostics for `architecture_linter`'s own config file, not comparable code-quality checks — there is nothing for saropa_lints to reproduce.

## What You Gain

saropa_lints has no per-project layer-graph configuration, but it ships fixed architecture rules that need zero setup: `avoid_ui_in_domain_layer`, `avoid_direct_data_access_in_ui`, `avoid_business_logic_in_ui`, `avoid_cross_feature_dependencies`, `avoid_circular_dependencies`, `avoid_circular_imports` — plus 2300+ rules covering security, accessibility, performance, and library-specific patterns (GetX, Riverpod, Bloc, Provider, Firebase, Isar, Hive) that `architecture_linter` doesn't attempt.

## What You Lose

| architecture_linter Feature | Alternative |
|------------------------------|-------------|
| Generic, user-configurable N-layer banned-import graph (any layer names, any banned pairs) | Use saropa_lints' fixed UI/domain/data rules, or keep `architecture_linter` alongside for custom layer graphs |

If your project defines custom layer names beyond UI/domain/data, consider keeping `architecture_linter` alongside `saropa_lints`.

## Suppressing Rules

```dart
// architecture_linter style
// ignore: architecture_linter_banned_import

// saropa_lints style
// ignore: avoid_ui_in_domain_layer
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
