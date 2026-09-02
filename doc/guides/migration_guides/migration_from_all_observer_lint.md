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

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 20 TODO (100%) — all 20 rules are specific to the `all_observer`
reactive-state library and unrecognized by saropa_lints today.

| all_observer_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_reactive_creation_in_build` | TODO | TODO — no proposal filed yet |
| `avoid_effect_creation_in_build` | TODO | TODO — no proposal filed yet |
| `watch_only_inside_build` | TODO | TODO — no proposal filed yet |
| `dispose_reactive_resources` | TODO | TODO — no proposal filed yet |
| `avoid_reactive_write_in_computed` | TODO | TODO — no proposal filed yet |
| `avoid_set_state_in_computed` | TODO | TODO — no proposal filed yet |
| `avoid_worker_creation_in_computed` | TODO | TODO — no proposal filed yet |
| `avoid_io_in_computed` | TODO | TODO — no proposal filed yet |
| `avoid_observable_write_during_observer_build` | TODO | TODO — no proposal filed yet |
| `self_referencing_computed` | TODO | TODO — no proposal filed yet |
| `invalid_history_limit` | TODO | TODO — no proposal filed yet |
| `async_inside_batch` | TODO | TODO — no proposal filed yet |
| `prefer_computed_for_derived_state` | TODO | TODO — no proposal filed yet |
| `prefer_batch_for_multiple_related_writes` | TODO | TODO — no proposal filed yet |
| `prefer_assign_all_for_reactive_list_replace` | TODO | TODO — no proposal filed yet |
| `unused_reactive_state` | TODO | TODO — no proposal filed yet |
| `unobserved_reactive_read_in_build` | TODO | TODO — no proposal filed yet |
| `observer_without_reactive_read` | TODO | TODO — no proposal filed yet |
| `computed_without_reactive_read` | TODO | TODO — no proposal filed yet |
| `effect_without_reactive_read` | TODO | TODO — no proposal filed yet |
| `copied_reactive_collection_outside_tracking` | TODO | TODO — no proposal filed yet |

## What You Gain

saropa_lints adds broad, library-agnostic coverage `all_observer_lint` doesn't attempt: security (secrets,
weak crypto, insecure storage), accessibility (semantics, touch targets, color contrast), and correctness
rules for Provider, Riverpod, Bloc, and GetX — useful if your project mixes `all_observer` with any of those.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
