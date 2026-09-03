# Migrating from jsdaddy_custom_lints

This guide helps you migrate from `jsdaddy_custom_lints` to `saropa_lints`.

## Why Migrate?

| Feature | jsdaddy_custom_lints | saropa_lints |
|---------|------------------------|--------------|
| **Rule count** | 1 rule (file naming) | 2300+ rules across security, a11y, performance, and 15+ libraries |
| **Scope** | Kebab-case file naming only | Whole-project static analysis |
| **Distribution** | Git dependency (not published on pub.dev) | Published on pub.dev |
| **Configuration** | Single opt-in rule | 5 progressive tiers |

`jsdaddy_custom_lints` ships exactly one rule: `file_naming_kebab_case`, requiring hyphen-separated file names
(`my-file.dart`). This is a deliberate house-style choice that actively conflicts with Dart's own `snake_case`
file-naming convention (enforced by the core `file_names` lint and Effective Dart) — saropa_lints does not
mirror it, and doing so would contradict the rest of the ecosystem's naming rules.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  jsdaddy_custom_lints:
    git:
      url: https://github.com/JsDaddy/dart-linter-rules

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^15.0.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - custom_lint
custom_lint:
  enable_all_lint_rules: false
  rules:
    - file_naming_kebab_case

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

Coverage: 1 rules — 1 TODO (100%)

| jsdaddy_custom_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `file_naming_kebab_case` | TODO | TODO — see [proposal](../../../plans/declined/proposal_file_naming_kebab_case.md); conflicts with Dart's standard `snake_case` file-naming convention, so this is a deliberate house-style gap rather than an oversight |

If your team relies on kebab-case file names as a hard requirement, keep `jsdaddy_custom_lints` installed
alongside `saropa_lints` — there is no conflict between the two plugins at runtime.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
