# Migrating from clean_architecture_kit

This guide helps you migrate from `clean_architecture_kit` (part of the `clean_architecture_workspace` monorepo) to `saropa_lints`.

## Why Migrate?

| Feature | clean_architecture_kit | saropa_lints |
|---------|--------------------------|--------------|
| **Rule count** | 16 rules, all architecture-focused | 2300+ custom rules |
| **Focus** | Configurable clean-architecture layer boundary enforcement | Broad Flutter analysis — architecture is one of many categories |
| **Configuration** | Per-project layer/folder configuration (domain/data/presentation) | 5 progressive tiers |
| **Maintenance** | Small, focused package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**This is the honest one**: clean_architecture_kit is a purpose-built, configurable clean-architecture linter. saropa_lints has **no rule that directly implements any of its 16 rules** — saropa_lints' architecture rules are fixed UI/domain/data checks, not a configurable N-layer engine. If enforcing clean-architecture layer boundaries is your primary need, clean_architecture_kit does something saropa_lints does not attempt to replicate. Use both together rather than migrating away from it.

## Architecture Differences

| Aspect | clean_architecture_kit | saropa_lints |
|--------|--------------------------|--------------|
| **Layer model** | Configurable N-layer (domain/data/presentation, custom folder mapping) | Fixed UI / domain / data checks, not configurable per project structure |
| **Enforcement style** | Structural (folder location, import direction, naming, inheritance, return-type conventions) | Pattern-based (specific anti-patterns within a layer) |
| **Scope** | 100% architecture | Architecture is ~1% of saropa_lints' rule set |

## Using Both Together

Because there is no overlap to consolidate, keep clean_architecture_kit for layer-boundary enforcement and add saropa_lints for everything else:

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_kit: ^1.0.0
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint

# clean_architecture_kit config stays as-is
```

```bash
dart run saropa_lints:init --tier recommended
dart run custom_lint
```

## Choosing a Tier

If you do want saropa_lints' architecture rules as a lighter-weight supplement (not a replacement):

| Need | saropa_lints Tier | Description |
|------|-------------------|--------------|
| Core anti-patterns only | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Balanced coverage + architecture rules | **Recommended** (~900 rules) | Includes `avoid_ui_in_domain_layer`, `avoid_direct_data_access_in_ui`, `avoid_cross_feature_dependencies` |

## Rule Mapping

Coverage: 16 rules — 3 PARTIAL, 13 TODO (81%)

| clean_architecture_kit Rule | Status | Saropa Rule / Action |
|---|---|---|
| `data_source_purity` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `disallow_flutter_imports_in_domain` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `disallow_flutter_types_in_domain` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `disallow_use_case_in_presentation` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `domain_layer_purity` | PARTIAL | `avoid_ui_in_domain_layer` — flags presentation logic in domain, not a generic configurable "domain cannot import layer X" check |
| `enforce_abstract_data_source_dependency` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `enforce_custom_return_type` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `enforce_file_and_folder_location` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `enforce_layer_independence` | PARTIAL | `avoid_ui_in_domain_layer` / `avoid_direct_data_access_in_ui` / `avoid_cross_feature_dependencies` — saropa's fixed UI/business/data checks aren't a configurable N-layer engine |
| `enforce_naming_conventions` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `enforce_repository_inheritance` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `enforce_use_case_inheritance` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `missing_use_case` | TODO | TODO — see [proposal](../../../bugs/proposal_missing_use_case.md) |
| `enforce_model_to_entity_mapping` | TODO | TODO — see [proposal](../../../bugs/proposal_clean_architecture_enforcement_rules.md) |
| `presentation_layer_purity` | PARTIAL | `avoid_direct_data_access_in_ui` — flags UI classes with Repository/DataSource fields directly, not a generic configurable "presentation cannot touch Repository" check |
| `repository_implementation_purity` | TODO | TODO — see [proposal](../../../bugs/proposal_repository_implementation_purity.md) |

## What You Gain

saropa_lints doesn't replace clean_architecture_kit's layer enforcement, but it covers everything clean_architecture_kit doesn't attempt:

**Security**
- `avoid_hardcoded_credentials`, `avoid_logging_sensitive_data`, `require_secure_storage`

**Accessibility**
- `require_semantics_label`, `avoid_small_touch_targets`, `avoid_color_only_indicators`

**State Management**
- Full Riverpod, Bloc, Provider, and GetX rule sets

**Lifecycle & Memory**
- `require_dispose`, `avoid_context_in_initstate_dispose`, `pass_existing_future_to_future_builder`

## What You Lose

Nothing — this is an addition, not a replacement. If you drop clean_architecture_kit anyway, you lose all configurable layer-boundary enforcement:

| clean_architecture_kit Feature | Alternative |
|-----------------------------------|--------------|
| Configurable N-layer folder/import enforcement | No saropa_lints equivalent — keep clean_architecture_kit |
| Use-case / repository inheritance and return-type conventions | No saropa_lints equivalent — keep clean_architecture_kit |
| Model-to-entity mapping enforcement | No saropa_lints equivalent — keep clean_architecture_kit |

## Suppressing Rules

Both packages use custom_lint / analyzer_plugin infrastructure, so the syntax is identical:

```dart
// clean_architecture_kit / saropa_lints style (same)
// ignore: avoid_ui_in_domain_layer
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
