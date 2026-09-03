# Migrating from bloc_lint

This guide helps you migrate from `bloc_lint` (the official [bloc](https://bloclibrary.dev) lint package) to `saropa_lints`.

## Why Migrate?

| Feature | bloc_lint | saropa_lints |
|---------|-----------|--------------|
| **Rule count** | 9 rules | 2300+ custom rules (20+ Bloc-specific) |
| **Focus** | Bloc/Cubit API correctness and style | Flutter-specific analysis, broad coverage |
| **Configuration** | `package:bloc_lint/recommended.yaml`, or the `bloc` CLI | 5 progressive tiers |
| **CLI** | Standalone `bloc lint` binary (via `bloc_tools`) | `custom_lint` plugin (IDE + CLI) |
| **Cost** | Free & open source | Free & open source |

**Note**: bloc_lint is the official, actively maintained package from the bloc library author. saropa_lints reimplements most of its rules as part of a much larger Bloc rule set (`avoid_bloc_public_fields`, `emit_new_bloc_state_instances`, `prefer_immutable_bloc_state`, and 15+ more — see the [Bloc section of the DCM migration guide](migration_from_dcm.md#bloc) for the full list saropa_lints covers). If you use bloc/flutter_bloc and want a single linter for both Bloc conventions and everything else (security, accessibility, performance), saropa_lints consolidates that; if you want the canonical, framework-author-maintained ruleset, keep bloc_lint.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  bloc_lint: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
include: package:bloc_lint/recommended.yaml

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
# Before
bloc lint .

# After
dart run custom_lint
```

## Using Both Together

bloc_lint runs as a standalone CLI (`bloc lint`) via `bloc_tools`, separate from the `custom_lint` analyzer plugin that saropa_lints uses. There is no plugin conflict — you can keep `bloc lint` in CI for the official rule set while running saropa_lints for everything else, including its broader Bloc coverage.

## Rule Mapping

Coverage: 8 rules — 3 HAVE (37%), 5 PARTIAL

| bloc_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_build_context_extensions` | N/A | Philosophical conflict: saropa_lints' `prefer_bloc_extensions` recommends the opposite style (`context.read`/`watch` over `BlocProvider.of`) |
| `avoid_flutter_imports` | HAVE | `avoid_ui_in_domain_layer` |
| `avoid_public_bloc_methods` | PARTIAL | `avoid_bloc_public_methods` — narrower (stricter) allowlist than bloc_lint's |
| `avoid_public_fields` | PARTIAL | `avoid_bloc_public_fields` — Bloc-only in saropa docs; Cubit coverage unconfirmed |
| `prefer_bloc` | HAVE | `avoid_cubit_usage` |
| `prefer_build_context_extensions` | PARTIAL | `prefer_bloc_extensions` — only covers `BlocProvider.of` → `context.read`/`watch`, not `BlocBuilder`/`BlocSelector`/`context.select` |
| `prefer_cubit` | PARTIAL | `prefer_cubit_for_simple_state` — only fires for single-event-type Blocs, not every Bloc |
| `prefer_file_naming_conventions` | PARTIAL | `prefer_snake_case_files` — general naming check, doesn't verify the file matches its specific Bloc/Cubit class |
| `prefer_void_public_cubit_methods` | HAVE | `avoid_returning_value_from_cubit_methods` |

## What You Gain

saropa_lints' Bloc coverage extends well beyond bloc_lint's 9 rules — `emit_new_bloc_state_instances`, `prefer_immutable_bloc_state`, `avoid_passing_bloc_to_bloc`, `check_is_not_closed_after_async_gap`, and more (see the [full Bloc table](migration_from_dcm.md#bloc)) — plus unrelated security, accessibility, and lifecycle rules across the whole codebase, not just Bloc files.

## What You Lose

| bloc_lint Feature | Alternative |
|---|---|
| Standalone `bloc lint` CLI, independent of `custom_lint` | `dart run custom_lint` (IDE integration included) |
| Framework-author-maintained canonical rule set | saropa_lints' Bloc rules are community-maintained; run both if canonical parity matters |
| `avoid_build_context_extensions` (discourages `context.read`/`watch` for Bloc types) | saropa_lints takes the opposite position via `prefer_bloc_extensions` — pick one and disable the other |

## Suppressing Rules

```dart
// bloc_lint style
// ignore: avoid_public_fields

// saropa_lints style
// ignore: avoid_bloc_public_fields
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
