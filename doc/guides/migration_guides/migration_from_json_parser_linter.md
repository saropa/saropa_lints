# Migrating from json_parser_linter

This guide helps you migrate from [`json_parser_linter`](https://pub.dev/packages/json_parser_linter)
(github.com/Ragibn5/dart-flutter-packages — part of the `json_coder` suite) to `saropa_lints`.

## Why Migrate?

| Feature | json_parser_linter | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 1 combined rule (2 independent sub-checks) | 2300+ custom rules |
| **Focus** | `@GenerateJsonParser`-annotated class contract validation for the `json_coder` codegen suite | Comprehensive security, accessibility, performance, and Flutter-specific analysis |
| **Configuration** | Single opt-in rule | 5 progressive tiers + rule packs |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  json_parser_linter: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - json_parser_linter

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

```bash
dart analyze
```

## Rule Mapping

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%).

| json_parser_linter Rule | Status | Saropa Rule / Action |
|---|---|---|
| `json_parser_requirements` (toJson half + fromJson half) | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_json_parser_requirements.md) |

`json_parser_requirements` verifies that a `@GenerateJsonParser`-annotated class has a
`Map<String, dynamic> toJson()` instance method and a matching factory/static
`fromJson(Map<String, dynamic> json)` constructor with correct signatures, so generated
code from the `json_coder` package compiles against a valid contract. This is the same
class of check as `json_serializable_lints`' pair of rules (see
[migration_from_json_serializable_lints.md](migration_from_json_serializable_lints.md))
— saropa_lints has no annotation-contract checker for either codegen package today.

## What You Lose

`json_parser_linter` is a narrow, single-purpose rule scoped to `json_coder` codegen.
It has no overlap against saropa_lints' broader rule set, so keep it installed alongside
saropa_lints if your project uses `json_coder` and relies on this check.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
