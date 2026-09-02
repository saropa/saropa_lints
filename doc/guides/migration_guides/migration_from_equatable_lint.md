# Migrating from equatable_lint

This guide helps you migrate from `equatable_lint` (bamlab) to `saropa_lints`.

## Why Migrate?

| Feature | equatable_lint | saropa_lints |
|---------|-----------------|--------------|
| **Rule count** | 2 rules | 2300+ custom rules |
| **Focus** | `Equatable` correctness only (missing props, missing `super.props` call) | `Equatable` correctness plus 2300+ rules across security, accessibility, performance, and library-specific patterns |
| **Configuration** | Enable/disable per rule | 5 progressive tiers |
| **Maintenance** | Small, single-purpose package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  equatable_lint: ^1.0.0
  custom_lint: ^0.8.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

Remove the `equatable_lint` plugin entry, then generate saropa_lints config:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Rule Mapping

Coverage: 1 HAVE (50%), 0 PARTIAL (0%), 1 TODO (50%) — audited 2026-09-02 against github.com/bamlab/equatable_lint.

| equatable_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `missing_field_in_equatable_props` | HAVE | `list_all_equatable_fields` |
| `always_call_super_props_when_overriding_equatable_props` | TODO | TODO — no proposal filed yet (checked existing Equatable proposals — `proposal_avoid_equatable_call_on_equality_base_class.md` covers a different concept, incorrectly *calling* base equality members, not a missing `super.props` call when overriding `props` in a subclass chain; `proposal_prefer_equatable_key_name.md` and `proposal_prefer_sorted_equatable_props.md` are unrelated) |

## What You Gain

Beyond `Equatable` field coverage, saropa_lints ships additional Equatable correctness rules — `require_equatable_props_override`, `avoid_mutable_field_in_equatable`, `require_extend_equatable` — plus 2300+ rules across security, accessibility, performance, and library-specific patterns (GetX, Riverpod, Bloc, Provider, Firebase, Isar, Hive) that `equatable_lint` doesn't attempt.

## What You Lose

| equatable_lint Feature | Alternative |
|--------------------------|-------------|
| `super.props` chain-call enforcement when overriding `props` in a subclass | Manual review until a saropa_lints rule is filed |

## Suppressing Rules

```dart
// equatable_lint style
// ignore: missing_field_in_equatable_props

// saropa_lints style
// ignore: list_all_equatable_fields
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
