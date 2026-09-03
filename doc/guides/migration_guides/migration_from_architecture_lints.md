# Migrating from architecture_lints

This guide helps you migrate from `architecture_lints` (part of the `architecture_workspace` monorepo) to `saropa_lints`.

## Why Migrate?

| Feature | architecture_lints | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 23 rules | 2300+ custom rules |
| **Focus** | Config-driven architecture-component-graph engine (dependency, type, member, annotation, naming, exception, and parameter/return "safety" rules) | Fixed architecture rules + full-codebase quality, security, accessibility, library-specific patterns |
| **Configuration** | Per-project component/type/member graph definitions in YAML | 5 progressive tiers |
| **Maintenance** | Small workspace package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: `architecture_lints` is a generic, project-configurable architecture-component-graph engine — you declare components, their allowed dependencies, required base types/members/annotations, and naming grammars, and it enforces them. saropa_lints does not have an equivalent generic graph engine; it ships fixed, opinionated layer/DI rules that cover the same *intent* (layering, dependency direction, singleton/DI hygiene) without per-project component configuration. This is the single biggest structural gap identified in saropa_lints' competitor audit by rule count.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  architecture_lints: ^1.0.0
  custom_lint: ^0.8.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

Remove the `architecture_lints` component-graph config block, then generate saropa_lints config:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Rule Mapping

Coverage: 26 rules — 4 PARTIAL, 22 TODO (84%)

| architecture_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `arch_dep_component` | PARTIAL | `avoid_cross_feature_dependencies` — fixed cross-feature check, not a configurable component graph |
| `arch_dep_external` | PARTIAL | `avoid_direct_data_access_in_ui` / `prefer_abstract_dependencies` — fixed layer rules, not configurable per external package |
| `arch_dep_module` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_orphan_file` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_parity_missing` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_type_strict_inheritance` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_type_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_type_missing_base` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_member_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_member_missing` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_annot_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_annot_missing` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_annot_strict` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_naming_grammar` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_naming_antipattern` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_naming_pattern` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_exception_conversion` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_exception_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_exception_missing` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_safety_param_strict` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_safety_param_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_safety_return_strict` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_safety_return_forbidden` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_usage_instantiation` | TODO | TODO — see [proposal](../../../bugs/proposal_architecture_lints_enforcement_rules.md) |
| `arch_location` | PARTIAL | `match_lib_folder_structure` — fixed folder-structure check, not a configurable per-component location rule |
| `arch_usage_global_access` | PARTIAL | `avoid_service_locator_in_widgets` / `avoid_global_state` — fixed service-locator/global-state checks, not a configurable global-access graph |

All 19 `TODO` rows depend on a generic, config-driven component-graph engine (declared components, allowed dependencies, required base types/members/annotations, naming grammars) that saropa_lints does not currently implement.

## What You Gain

Beyond fixed layer/DI architecture rules (`avoid_ui_in_domain_layer`, `avoid_business_logic_in_ui`, `avoid_circular_dependencies`, `avoid_circular_imports`, `avoid_singleton_pattern`, `require_typed_di_registration`, `prefer_constructor_injection`), saropa_lints covers security, accessibility, performance, and 2300+ rules across GetX, Riverpod, Bloc, Provider, Firebase, Isar, and Hive that `architecture_lints` does not attempt.

## What You Lose

| architecture_lints Feature | Alternative |
|------------------------------|-------------|
| Configurable component/dependency graph (per-project component names and allowed edges) | None in saropa_lints today — keep `architecture_lints` alongside for project-specific graphs |
| Required-base-type / required-member / required-annotation enforcement per component | None in saropa_lints today |
| Naming grammar/pattern/antipattern rules scoped to declared components | saropa_lints' `match_class_name_pattern` covers project-wide naming patterns, not per-component grammars |
| Exception conversion/forbidden/missing rules scoped to declared components | saropa_lints' generic exception rules (`avoid_only_rethrow`, `prefer_public_exception_classes`) are not component-scoped |
| Parameter/return "safety" strictness rules scoped to declared components | None in saropa_lints today |

If your project relies heavily on `architecture_lints`' component-graph configuration, keep it alongside `saropa_lints` — the two are complementary, not competing, for this rule set.

## Suppressing Rules

```dart
// architecture_lints style
// ignore: arch_dep_component

// saropa_lints style
// ignore: avoid_cross_feature_dependencies
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
