# Migrating from all_observer_lint

This guide helps you migrate from `all_observer_lint` to `saropa_lints`.

## Why Migrate?

| Feature | all_observer_lint | saropa_lints |
|---------|--------------------|--------------|
| **Rule count** | 20 rules (`all_observer` reactive-state library only) | 2300+ rules across security, a11y, performance, and 15+ libraries |
| **Scope** | The niche `all_observer` package | Whole-project static analysis |
| **Configuration** | `include: package:all_observer_lint/recommended.yaml` | 5 progressive tiers |

**Important**: `all_observer` is a niche reactive-state library and none of its 20 lint rules have a saropa
equivalent — saropa_lints' state-management coverage targets Provider, Riverpod, Bloc, GetX, and
`ChangeNotifier`/`ValueNotifier`, not `all_observer`'s `Observable`/`Computed`/`Observer` API. If your project
uses `all_observer`, keep `all_observer_lint` installed alongside `saropa_lints` — there is currently no
overlap to deduplicate.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  custom_lint: ^0.8.0
  all_observer_lint: ^0.6.0

# After (add, don't replace, if you still use all_observer)
dev_dependencies:
  custom_lint: ^0.8.0
  all_observer_lint: ^0.6.0
  saropa_lints: ^15.0.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:all_observer_lint/recommended.yaml

# After (keep the include, saropa_lints runs through the same custom_lint plugin)
include: package:all_observer_lint/recommended.yaml

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

## Rule Mapping

Coverage: 21 rules — 21 TODO (100%)
reactive-state library and unrecognized by saropa_lints today.

| all_observer_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_reactive_creation_in_build` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_reactive_creation_in_build.md) |
| `avoid_effect_creation_in_build` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_effect_creation_in_build.md) |
| `watch_only_inside_build` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_watch_only_inside_build.md) |
| `dispose_reactive_resources` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_dispose_reactive_resources.md) |
| `avoid_reactive_write_in_computed` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_set_state_in_computed.md) |
| `avoid_set_state_in_computed` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_set_state_in_computed.md) |
| `avoid_worker_creation_in_computed` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_worker_creation_in_computed.md) |
| `avoid_io_in_computed` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_io_in_computed.md) |
| `avoid_observable_write_during_observer_build` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_avoid_observable_write_during_observer_build.md) |
| `self_referencing_computed` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_self_referencing_computed.md) |
| `invalid_history_limit` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_invalid_history_limit.md) |
| `async_inside_batch` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_async_inside_batch.md) |
| `prefer_computed_for_derived_state` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_prefer_computed_for_derived_state.md) |
| `prefer_batch_for_multiple_related_writes` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_prefer_batch_for_multiple_related_writes.md) |
| `prefer_assign_all_for_reactive_list_replace` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_prefer_assign_all_for_reactive_list_replace.md) |
| `unused_reactive_state` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_unused_reactive_state.md) |
| `unobserved_reactive_read_in_build` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_unobserved_reactive_read_in_build.md) |
| `observer_without_reactive_read` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_observer_without_reactive_read.md) |
| `computed_without_reactive_read` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_computed_without_reactive_read.md) |
| `effect_without_reactive_read` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_effect_without_reactive_read.md) |
| `copied_reactive_collection_outside_tracking` | TODO | TODO — see [proposal](../../../bugs/tier_5_niche/proposal_copied_reactive_collection_outside_tracking.md) |

## What You Gain

saropa_lints adds broad, library-agnostic coverage `all_observer_lint` doesn't attempt: security (secrets,
weak crypto, insecure storage), accessibility (semantics, touch targets, color contrast), and correctness
rules for Provider, Riverpod, Bloc, and GetX — useful if your project mixes `all_observer` with any of those.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
