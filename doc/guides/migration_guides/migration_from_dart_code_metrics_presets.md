# Migrating from dart_code_metrics_presets

This guide helps you migrate from [`dart_code_metrics_presets`](https://pub.dev/packages/dart_code_metrics_presets) to `saropa_lints`.

## Why Migrate?

| Feature | dart_code_metrics_presets | saropa_lints |
|---------|----------------------------|--------------|
| **Rule count** | 15 package-specific preset YAMLs, ~85 rule references | 2300+ custom rules, incl. deep Bloc/Riverpod/Provider/GetX/Equatable coverage |
| **Focus** | Curated DCM rule subsets per third-party package (bloc, riverpod, flame, intl, mocktail, ...) | Broad Dart/Flutter analysis, package-specific rules built in |
| **Configuration** | Import one preset YAML per package you use | 5 progressive tiers, all package rules included automatically |
| **Maintenance** | Companion presets to DCM | Actively maintained, standalone |
| **Cost** | Free & open source | Free & open source |

`dart_code_metrics_presets` doesn't define new rules — it re-packages `dart_code_metrics`' existing rule catalog into 15 opinionated, package-specific YAML presets (`bloc.yaml`, `riverpod.yaml`, `provider.yaml`, `flame.yaml`, `intl.yaml`, `easy_localization.yaml`, `mocktail.yaml`, `patrol.yaml`, `flutter_hooks.yaml`, `equatable.yaml`, `getx.yaml`, `firebase_analytics.yaml`, `fake_async.yaml`, `get_it.yaml`, `json_serializable.yaml`) so a project can enable "all the DCM rules relevant to bloc" in one line instead of hand-picking them. See [Migrating from DCM](migration_from_dcm.md) for the general dart_code_metrics rule mapping — this guide covers the package-specific presets that DCM migration doesn't break out individually.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  dart_code_metrics: ^5.7.0
  dart_code_metrics_presets: ^1.0.0

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
    - dart_code_metrics

include: package:dart_code_metrics_presets/lib/bloc.yaml
include: package:dart_code_metrics_presets/lib/riverpod.yaml

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

Coverage: 62 HAVE (73%), 3 PARTIAL (4%), 20 TODO (23%) — across all 15 presets, 85 rule references.

### bloc.yaml (22 rules — 21 HAVE, 1 PARTIAL)

Identical to the DCM Bloc rule set — see [Migrating from DCM: Bloc](migration_from_dcm.md#bloc) for the full mapping. Only `handle-bloc-event-subclasses` is PARTIAL (`require_bloc_event_sealed` — TODO extend, see [proposal](../../../bugs/proposal_extend_require_bloc_event_sealed_dcm_parity.md)); the remaining 21 rules are all HAVE.

### riverpod.yaml (18 rules — 11 HAVE, 7 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-ref-read-inside-build` | HAVE | `avoid_ref_read_inside_build` |
| `avoid-ref-watch-outside-build` | HAVE | `avoid_ref_watch_outside_build` |
| `avoid-unnecessary-consumer-widgets` | HAVE | `avoid_unnecessary_consumer_widgets` |
| `use-ref-read-synchronously` | HAVE | `use_ref_read_synchronously` |
| `avoid-calling-notifier-members-inside-build` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_calling_notifier_members_inside_build.md) |
| `avoid-notifier-constructors` | HAVE | `avoid_notifier_constructors` |
| `dispose-provided-instances` | HAVE | `dispose_provided_instances` |
| `prefer-immutable-provider-arguments` | HAVE | `prefer_immutable_provider_arguments` |
| `avoid-public-notifier-properties` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_public_notifier_properties.md) |
| `avoid-ref-inside-state-dispose` | HAVE | `avoid_ref_inside_state_dispose` |
| `avoid-nullable-async-value-pattern` | HAVE | `avoid_nullable_async_value_pattern` |
| `use-ref-and-state-synchronously` | HAVE | `use_ref_and_state_synchronously` |
| `avoid-assigning-notifiers` | HAVE | `avoid_assigning_notifiers` |
| `prefer-single-notifier-per-file` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_single_notifier_per_file.md) |
| `prefer-riverpod-provider-suffix` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_riverpod_provider_suffix.md) |
| `prefer-riverpod-notifier-suffix` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_riverpod_notifier_suffix.md) |
| `prefer-correct-notifier-file-name` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_correct_notifier_file_name.md) |
| `prefer-correct-provider-file-name` | TODO | TODO — see [proposal](../../../bugs/proposal_prefer_correct_provider_file_name.md) |

### provider.yaml (7 rules — 5 HAVE, 2 PARTIAL)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-watch-outside-build` | PARTIAL | `avoid_ref_watch_outside_build` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_ref_watch_outside_build_dcm_parity.md) |
| `avoid-read-inside-build` | PARTIAL | `avoid_ref_read_inside_build` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_ref_read_inside_build_dcm_parity.md) |
| `dispose-providers` | HAVE | `dispose_provider_instances` / `require_provider_dispose` |
| `prefer-multi-provider` | HAVE | `prefer_multi_provider` |
| `avoid-instantiating-in-value-provider` | HAVE | `avoid_instantiating_in_value_provider` |
| `prefer-provider-extensions` | HAVE | `prefer_provider_extensions` |
| `prefer-immutable-selector-value` | HAVE | `prefer_immutable_selector_value` |

`prefer-nullable-provider-types` is explicitly disabled in this preset's own YAML, so it is excluded from the 7-rule count.

### getx.yaml (5 rules — 5 HAVE)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `always-remove-getx-listener` | HAVE | `always_remove_getx_listener` |
| `dispose-getx-fields` | HAVE | `dispose_getx_fields` |
| `avoid-getx-rx-inside-build` | HAVE | `avoid_getx_rx_inside_build` |
| `proper-getx-super-calls` | HAVE | `proper_getx_super_calls` |
| `avoid-mutable-rx-variables` | HAVE | `avoid_mutable_rx_variables` |

### equatable.yaml (4 rules — 4 HAVE)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `extend-equatable` | HAVE | `require_extend_equatable` |
| `list-all-equatable-fields` | HAVE | `list_all_equatable_fields` |
| `prefer-equatable-mixin` | HAVE | `prefer_equatable_mixin` |
| `add-equatable-props` | HAVE | `list_all_equatable_fields` |

### flutter_hooks.yaml (6 rules — 6 HAVE)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `prefer-use-prefix` | HAVE | `prefer_use_prefix` |
| `avoid-conditional-hooks` | HAVE | `avoid_conditional_hooks` |
| `avoid-hooks-outside-build` | HAVE | `avoid_hooks_outside_build` |
| `avoid-unnecessary-hook-widgets` | HAVE | `avoid_unnecessary_hook_widgets` |
| `prefer-use-callback` | HAVE | `prefer_use_callback` |
| `avoid-misused-hooks` | HAVE | `avoid_misused_hooks` |

### intl.yaml (6 rules — 4 HAVE, 2 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `prefer-intl-name` | HAVE | `prefer_intl_name` |
| `prefer-providing-intl-description` | HAVE | `prefer_providing_intl_description` |
| `provide-correct-intl-args` | HAVE | `provide_correct_intl_args` |
| `prefer-providing-intl-examples` | HAVE | `prefer_providing_intl_examples` |
| `prefer-number-format` | TODO | TODO — no proposal filed yet. |
| `prefer-date-format` | TODO | TODO — no proposal filed yet. |

### flame.yaml (4 rules — 2 HAVE, 2 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-creating-vector-in-update` | HAVE | `avoid_creating_vector_in_update` |
| `avoid-redundant-async-on-load` | HAVE | `avoid_redundant_async_on_load` |
| `avoid-initializing-in-on-mount` | TODO | TODO — no proposal filed yet. |
| `correct-game-instantiating` | TODO | TODO — no proposal filed yet. |

### firebase_analytics.yaml (2 rules — 2 HAVE)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `incorrect-firebase-event-name` | HAVE | `incorrect_firebase_event_name` |
| `incorrect-firebase-parameter-name` | HAVE | `incorrect_firebase_parameter_name` |

### fake_async.yaml (1 rule — 1 HAVE)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-async-callback-in-fake-async` | HAVE | `avoid_async_callback_in_fake_async` |

### patrol.yaml (2 rules — 1 HAVE, 1 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `prefer-symbol-over-key` | HAVE | `prefer_symbol_over_key` |
| `prefer-custom-finder-over-find` | TODO | TODO — no proposal filed yet. |

### mocktail.yaml (4 rules — 4 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `use-then-answer` | TODO | TODO — no proposal filed yet. |
| `pass-mock-object` | TODO | TODO — no proposal filed yet. |
| `avoid-implementation-in-mocks` | TODO | TODO — no proposal filed yet. |
| `prefer-correct-any-matcher` | TODO | TODO — no proposal filed yet. |

### easy_localization.yaml (2 rules — 2 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-missing-tr` | TODO | TODO — no proposal filed yet. |
| `avoid-missing-tr-on-strings` | TODO | TODO — no proposal filed yet. |

### get_it.yaml (1 rule — 1 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid-functions-in-register-singleton` | TODO | TODO — no proposal filed yet. |

### json_serializable.yaml (1 rule — 1 TODO)

| Preset Rule | Status | Saropa Rule / Action |
|---|---|---|
| `specify-unknown-enum-value` | TODO | TODO — no proposal filed yet. |

## What You Gain

saropa_lints applies its package-specific rules (Bloc, Riverpod, Provider, GetX, Equatable, Flutter Hooks) automatically at every tier — there's no separate preset YAML to `include:` per package. You also get 2300+ rules covering areas none of these presets touch: security, general accessibility, performance, and Dart language-level code quality.

## What You Lose

Several package integrations that `dart_code_metrics_presets` covers have no saropa equivalent at all: **mocktail** (mock-object correctness), **patrol** (finder preferences beyond `prefer_symbol_over_key`), **get_it** (singleton-registration checks), **json_serializable** (unknown-enum-value handling), and **easy_localization** (missing-translation detection). If your project relies on these presets, keep `dart_code_metrics` and `dart_code_metrics_presets` running alongside saropa_lints for those specific packages — the two plugins don't conflict.

```yaml
# analysis_options.yaml — running both
analyzer:
  plugins:
    - dart_code_metrics
    - custom_lint

include: package:dart_code_metrics_presets/lib/mocktail.yaml
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
