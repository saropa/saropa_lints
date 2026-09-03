# Migrating from dart_code_metrics_annotations

This guide helps you migrate from [`dart_code_metrics_annotations`](https://pub.dev/packages/dart_code_metrics_annotations) to `saropa_lints`.

## Why Migrate?

| Feature | dart_code_metrics_annotations | saropa_lints |
|---------|-------------------------------|--------------|
| **Rule count** | 3 annotation-driven rule groups | 2300+ custom rules |
| **Focus** | Annotations consumed by DCM's rule engine | Broad Dart/Flutter analysis, unconditional (no opt-in annotations required) |
| **Configuration** | Requires `@Throws`/`@AcceptedTypes`/`@mutated` annotations in your code | 5 progressive tiers, works on unmodified code |
| **Maintenance** | Companion package to DCM | Actively maintained, standalone |
| **Cost** | Free & open source | Free & open source |

`dart_code_metrics_annotations` isn't a linter itself — it's an annotations package. Adding `@Throws`, `@AcceptedTypes`, or `@mutated` to your code opts specific declarations into stricter checking by DCM's own rules (`handle-throwing-invocations`, `prefer-correct-throws`, `pass-correct-accepted-types`, `prefer-correct-mutated`). saropa_lints has no equivalent annotation-consuming framework — its rules run unconditionally on unmodified code.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dependencies:
  dart_code_metrics_annotations: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

Coverage: 1 HAVE (33%), 2 PARTIAL (67%), 0 TODO (0%).

| Annotation / DCM Rule | Status | Saropa Rule / Action |
|---|---|---|
| `@Throws` (`handle-throwing-invocations` / `prefer-correct-throws`) | HAVE | `handle_throwing_invocations` / `prefer_correct_throws` — saropa flags unhandled throwing invocations without requiring an opt-in annotation. |
| `@AcceptedTypes` (`pass-correct-accepted-types`) | PARTIAL | No saropa rule performs annotation-driven runtime-type-set narrowing on `Object`-typed parameters/fields. see [proposal](../../../plans/tier_3_infrastructure/proposal_infra_configurable_widget_ban_mechanism.md) (accepted-types pattern tracked under configurable ban mechanism). |
| `@mutated` (`prefer-correct-mutated`) | PARTIAL | `avoid_parameter_mutation` / `avoid_collection_mutating_methods` are unconditional heuristics with no opt-out annotation mechanism, and `avoid_collection_mutating_methods` is narrower in scope (setState-only) than the general-purpose competitor rule. Declined as a dedicated annotation — see [proposal](../../../plans/declined/proposal_infra_prefer_correct_mutated_na.md): building a saropa-specific `@mutated`-style annotations package for one rule was judged out of scope. |

## What You Gain

saropa_lints' equivalents work on unmodified code — no annotation adoption required. `handle_throwing_invocations` and `prefer_correct_throws` catch unhandled exceptions across your whole codebase immediately, without you first having to annotate every throwing declaration with `@Throws`.

## What You Lose

The `@AcceptedTypes` narrowing check and `@mutated`'s annotation-driven mutation tracking have no saropa equivalent. If your project already annotates `Object`-typed parameters with `@AcceptedTypes` or intentionally-mutated parameters with `@mutated`, keep `dart_code_metrics_annotations` (and the corresponding DCM rules) running alongside saropa_lints — the packages don't conflict.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
