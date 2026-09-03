# Migrating from subpackage_lint

This guide helps you migrate from [`subpackage_lint`](https://pub.dev/packages/subpackage_lint) to `saropa_lints`.

## Why Migrate?

| Feature | subpackage_lint | saropa_lints |
|---------|------------------|--------------|
| **Rule count** | 3 rules | 2300+ custom rules |
| **Focus** | Monorepo/subpackage import boundaries only | Security, accessibility, performance, and 2300+ Flutter-specific patterns, plus general import hygiene |
| **Configuration** | Single-purpose plugin | 5 progressive tiers |
| **Scope** | `/src/` boundary enforcement for monorepo subpackages | Broad, general-purpose lint coverage |

**Note**: `subpackage_lint` is a narrow, single-purpose tool for enforcing that a subpackage's `/src/` directory stays private within a monorepo. If that is your only need, keep it running alongside `saropa_lints` — the two do not conflict.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  subpackage_lint: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

Coverage: 3 rules — 1 HAVE (33%), 2 TODO (66%)

| subpackage_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_package_import_for_same_package` | HAVE | `prefer_relative_imports_enforced` |
| `avoid_src_import_from_other_subpackage` | TODO | TODO — see [proposal](../../../plans/tier_3_infrastructure/proposal_avoid_src_import_from_other_subpackage.md) |
| `avoid_src_import_from_same_package` | TODO | TODO — see [proposal](../../../plans/tier_3_infrastructure/proposal_avoid_src_import_from_same_package.md) |

**Note**: saropa's `prefer_relative_imports_enforced` catches absolute `package:`-style imports reaching into the same package generally — it is not scoped to `/src/` specifically, so it is a broader (not narrower) match for `avoid_package_import_for_same_package`. The two `/src/`-boundary rules (blocking imports that reach into another subpackage's, or the same package's, private `/src/` directory instead of its public barrel file) have no saropa equivalent yet; if this monorepo boundary enforcement is load-bearing for your project, keep `subpackage_lint` installed alongside `saropa_lints`.

## Suppressing Rules

```dart
// subpackage_lint style
// ignore: avoid_src_import_from_other_subpackage

// saropa_lints style
// ignore: prefer_relative_imports_enforced
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
