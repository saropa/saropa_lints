# Migrating from mad_lint

This guide helps you migrate from `mad_lint` (MadBrains' `analysis_server_plugin`-based lint set) to `saropa_lints`.

## Why Migrate?

| Feature | mad_lint | saropa_lints |
|---------|----------|--------------|
| **Rule count** | 13 rules | 2300+ custom rules |
| **Focus** | Internal MadBrains conventions (mappedFields, copyWith completeness) | Full-spectrum Flutter/Dart analysis |
| **Configuration** | Flat `diagnostics` map | 5 progressive tiers |
| **Scope** | Single-team house style | General-purpose, OSS |

**Note**: mad_lint is a small, house-style ruleset built around a specific internal convention (`mappedFields`/stringify mixins). If your project uses that exact convention, keep mad_lint alongside saropa_lints — the 4 `mapped_fields_*` rules have no general-purpose equivalent (see Rule Mapping below).

## Architecture Differences

mad_lint is built on the newer `analysis_server_plugin`/`AnalysisRule` API (the official Dart analyzer plugin system), the same direction saropa_lints has also adopted. Both packages install as `analyzer.plugins` entries in `analysis_options.yaml` rather than through `custom_lint`.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  mad_lint: ^2.0.0

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
plugins:
  mad_lint:
    version: ^2.0.0
    diagnostics:
      stream_subscription_must_be_disposed: true
      no_magic_number: true
      no_bang_operator: true

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

Diagnostics now surface directly through `dart analyze` / your IDE's analyzer integration — no separate CLI invocation needed.

## Using Both Together

If your project depends on the `mappedFields` convention, keep mad_lint installed for those 4 rules alongside saropa_lints for everything else:

```yaml
# pubspec.yaml
dev_dependencies:
  mad_lint: ^2.0.0
  saropa_lints: ^2.6.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - mad_lint
    - saropa_lints
```

## Rule Mapping

Coverage: 7 HAVE (54%), 2 PARTIAL (15%), 4 TODO (31%).

| mad_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `newline_before_return` | HAVE | `NewlineBeforeReturnRule` |
| `no_magic_number` | HAVE | `no_magic_number` |
| `no_bang_operator` | HAVE | `avoid_non_null_assertion` |
| `required_full_props` | HAVE | `list_all_equatable_fields` |
| `ensure_dispose_called` | HAVE | `dispose_class_fields` |
| `use_wildcard_for_unused_parameters` | HAVE | `prefer_wildcard_for_unused_param` |
| `incomplete_copy_with_for_states` | HAVE | `avoid_incomplete_copy_with` |
| `stream_subscription_must_be_disposed` | PARTIAL | `avoid_unassigned_stream_subscriptions` — mad_lint targets a project-specific `.addDisposableTo(this)` helper; saropa expects assignment-to-variable + separate disposal call. Equivalent safety story, different convention. TODO — no proposal filed yet |
| `missing_copy_with_for_states` | PARTIAL | `require_equatable_copy_with` / `prefer_copy_with_for_state` — mad_lint targets any Bloc/state class; saropa's `require_equatable_copy_with` is Equatable-scoped, so a non-Equatable state class could slip through. TODO — no proposal filed yet |
| `mapped_fields_key_value_mismatch` | TODO | TODO — no proposal filed yet (MadBrains-internal `mappedFields` convention, no general-purpose Dart/Flutter analog) |
| `mapped_fields_must_be_expression` | TODO | TODO — no proposal filed yet |
| `mapped_fields_must_return_map` | TODO | TODO — no proposal filed yet |
| `missing_mapped_fields_getter` | TODO | TODO — no proposal filed yet |

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
