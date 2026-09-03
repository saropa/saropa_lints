# Migrating from riverpod_lint

This guide helps you migrate from `riverpod_lint` (the official Riverpod package's analyzer plugin) to `saropa_lints`.

## Why Migrate?

| Feature | riverpod_lint | saropa_lints |
|---------|----------------|--------------|
| **Rule count** | ~15 rules, Riverpod-only | 2300+ custom rules |
| **Focus** | Riverpod codegen correctness | Flutter-specific analysis across security, accessibility, performance, and every major state-management library |
| **Configuration** | None (fixed rule set) | 5 progressive tiers |
| **Maintenance** | Official (rrousselGit/riverpod monorepo) | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: riverpod_lint is scoped tightly to Riverpod's own codegen and API-misuse checks (some are framework-internal syntax validation, not general code quality). saropa_lints implements the general-purpose subset and covers Bloc, Provider, and GetX with equal depth — but does not replicate Riverpod's codegen-specific validators.

## Using Both Together

riverpod_lint's codegen-validation rules (`riverpod_syntax_error`, `unsupported_provider_value`) have no saropa_lints equivalent and aren't in scope — they validate `@riverpod` annotation syntax that only riverpod_lint's generator understands. If you use `@riverpod` codegen, keep riverpod_lint installed alongside saropa_lints for those checks; both use custom_lint / analyzer_plugin infrastructure and can run together.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  riverpod_lint: ^2.3.0
  custom_lint: ^0.6.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
  # Keep riverpod_lint if you use @riverpod codegen — see "Using Both Together"
  riverpod_lint: ^2.3.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    - riverpod_lint

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

## Choosing a Tier

riverpod_lint's rules are always-on. saropa_lints groups Riverpod coverage into progressive tiers alongside everything else:

| riverpod_lint Usage | saropa_lints Tier | Description |
|----------------------|-------------------|--------------|
| Default rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| Full coverage | **Recommended** (~900 rules) | Balanced coverage, includes Riverpod lifecycle rules |
| Strict naming/structure | **Professional** (~1600 rules) | Enterprise-grade, includes Riverpod naming conventions |

**Start with `recommended`** — it includes saropa_lints' Riverpod lifecycle rules (`avoid_ref_read_inside_build`, `avoid_ref_watch_outside_build`, `dispose_provided_instances`, etc.).

## Rule Mapping

Coverage: 13 rules — 4 HAVE (30%), 9 TODO (69%)

Note: the official riverpod_lint package ships 15 rules, not the 13 quoted by earlier internal audits — this table lists all 15, including the 2 framework-internal codegen validators that aren't code-quality rules and are out of scope for saropa_lints.

| riverpod_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `async_value_nullable_pattern` | HAVE | `avoid_nullable_async_value_pattern` |
| `avoid_build_context_in_providers` | HAVE | `avoid_build_context_in_providers` |
| `avoid_public_notifier_properties` | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_public_notifier_properties.md) |
| `avoid_ref_inside_state_dispose` | HAVE | `avoid_ref_inside_state_dispose` |
| `functional_ref` | TODO | TODO — see [proposal](../../../bugs/proposal_functional_ref.md) |
| `missing_provider_scope` | HAVE | `require_provider_scope` |
| `notifier_build` | TODO | TODO — see [proposal](../../../bugs/proposal_notifier_build.md) |
| `notifier_extends` | TODO | TODO — see [proposal](../../../bugs/proposal_notifier_extends.md) |
| `only_use_keep_alive_inside_keep_alive` | TODO | TODO — see [proposal](../../../bugs/proposal_only_use_keep_alive_inside_keep_alive.md) |
| `protected_notifier_properties` | TODO | TODO — see [proposal](../../../bugs/proposal_protected_notifier_properties.md) |
| `provider_dependencies` | TODO | TODO — see [proposal](../../../bugs/proposal_provider_dependencies.md) |
| `provider_parameters` | TODO | TODO — see [proposal](../../../bugs/proposal_provider_parameters.md) |
| `riverpod_syntax_error` | N/A | Framework-internal `@riverpod` codegen syntax validation — no code-quality equivalent needed |
| `scoped_providers_should_specify_dependencies` | TODO | TODO — see [proposal](../../../bugs/proposal_scoped_providers_should_specify_dependencies.md) |
| `unsupported_provider_value` | N/A | Framework-internal codegen validation — no code-quality equivalent needed |

## What You Gain

riverpod_lint only checks Riverpod. saropa_lints adds Riverpod naming and file-structure conventions that riverpod_lint doesn't attempt, plus everything outside Riverpod:

**Riverpod naming/structure (DCM-parity rules, not in riverpod_lint)**
- `prefer_riverpod_notifier_suffix` (TODO, see [proposal](../../../bugs/proposal_prefer_riverpod_notifier_suffix.md))
- `prefer_riverpod_provider_suffix` (TODO, see [proposal](../../../bugs/proposal_prefer_riverpod_provider_suffix.md))
- `prefer_correct_notifier_file_name` (TODO, see [proposal](../../../bugs/proposal_prefer_correct_notifier_file_name.md))
- `avoid_calling_notifier_members_inside_build` (TODO, see [proposal](../../../bugs/proposal_avoid_calling_notifier_members_inside_build.md))
- `use_ref_and_state_synchronously`, `use_ref_read_synchronously` — HAVE today

**Other state management**
- Full Bloc, Provider, and GetX rule sets — riverpod_lint has no equivalent since it's Riverpod-only

**Security, accessibility, performance**
- `avoid_hardcoded_credentials`, `require_semantics_label`, `avoid_small_touch_targets`, and 2000+ more rules outside riverpod_lint's scope

## What You Lose

| riverpod_lint Feature | Alternative |
|-------------------------|--------------|
| `@riverpod` codegen syntax validation (`riverpod_syntax_error`, `unsupported_provider_value`) | Keep riverpod_lint installed alongside saropa_lints for these two checks |
| `functional_ref`, `notifier_build`, `notifier_extends` (codegen shape enforcement) | No saropa_lints equivalent yet — file a proposal if needed |
| `provider_dependencies`, `provider_parameters`, `scoped_providers_should_specify_dependencies` (dependency-declaration correctness for `@Riverpod(dependencies: [...])`) | No saropa_lints equivalent yet |

## Suppressing Rules

Both packages use custom_lint / analyzer_plugin infrastructure, so the syntax is identical:

```dart
// riverpod_lint / saropa_lints style (same)
// ignore: avoid_ref_watch_outside_build
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
