# Migrating from equatable_lint_ultimate

This guide helps you migrate from `equatable_lint_ultimate` (a maintained fork of `equatable_lint`) to
`saropa_lints`.

## Why Migrate?

| Feature | equatable_lint_ultimate | saropa_lints |
|---------|--------------------------|--------------|
| **Rule count** | 2 rules + 1 assist (Equatable only) | 2300+ rules across security, a11y, performance, and 15+ libraries |
| **Scope** | `equatable` package correctness only | Whole-project static analysis, including Equatable |
| **Configuration** | Single flat rule list | 5 progressive tiers |
| **Maintenance** | Community fork of an unmaintained original | Actively maintained |

If `equatable_lint_ultimate` is the only lint plugin in your project, `saropa_lints` is a superset: it covers
the same Equatable ground plus everything else. If you use both today for their `custom_lint` plugin
architecture, they can keep running side by side.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  custom_lint:
  equatable_lint_ultimate:

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
  rules:
    - always_call_super_props_when_overriding_equatable_props: false

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

Coverage: 2 rules — 1 HAVE (50%), 1 TODO (50%)

| equatable_lint_ultimate Rule | Status | Saropa Rule / Action |
|---|---|---|
| `missing_field_in_equatable_props` | HAVE | `list_all_equatable_fields` |
| `always_call_super_props_when_overriding_equatable_props` | TODO | TODO — closest existing proposal (not an exact scope match): [proposal](../../../bugs/tier_2_high_value/proposal_avoid_equatable_call_on_equality_base_class.md) |
| "Make class extend Equatable" (assist) | PARTIAL | `require_extend_equatable` — proactively fires only on a class that manually overrides `==`/`hashCode`; it has no unprompted "convert any plain class to extend Equatable" assist |

## Suppressing Rules

```dart
// equatable_lint_ultimate style
// ignore: always_call_super_props_when_overriding_equatable_props

// saropa_lints style (once the gap rule ships)
// ignore: <saropa_rule_name>
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
