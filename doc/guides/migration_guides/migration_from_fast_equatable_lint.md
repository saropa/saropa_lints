# Migrating from fast_equatable_lint

This guide helps you migrate from `fast_equatable_lint` to `saropa_lints`.

## Why Migrate?

| Feature | fast_equatable_lint | saropa_lints |
|---------|----------------------|--------------|
| **Rule count** | 2 rules (`fast_equatable` package only) | 2300+ rules across security, a11y, performance, and 15+ libraries |
| **Scope** | `FastEquatable`/`hashParameters` correctness only | Whole-project static analysis |
| **Architecture** | Dart analyzer plugin (`analysis_server_plugin`) | `custom_lint` plugin |
| **Configuration** | Two rules, on by default | 5 progressive tiers |

**Important**: saropa_lints' Equatable rules are keyed to the `equatable` package's `props` getter — none
currently recognize `fast_equatable`'s `FastEquatable` mixin or `hashParameters` getter. If your project uses
`fast_equatable`, keep `fast_equatable_lint` installed alongside `saropa_lints`; migrating away today would
lose both of its checks with no saropa equivalent yet.

## Quick Migration

### Step 1: Update pubspec.yaml / plugins

`fast_equatable_lint` is a Dart analyzer plugin (no `pubspec.yaml` entry, configured under the top-level
`plugins:` key), while `saropa_lints` runs on `custom_lint`:

```yaml
# Before (analysis_options.yaml)
plugins:
  fast_equatable_lint: ^2.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^15.0.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 2: Run the linter

```bash
dart run custom_lint
```

## Using Both Together

Because saropa_lints has no `fast_equatable`-aware rules, projects using `fast_equatable` should run both
plugins side by side rather than replacing one with the other — `fast_equatable_lint` as an analyzer plugin,
`saropa_lints` as a `custom_lint` plugin; they do not conflict.

## Rule Mapping

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 2 TODO (100%).

| fast_equatable_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `missing_field_in_equatable_props` (flags an instance field missing from `hashParameters`) | TODO | TODO — no proposal filed yet |
| `always_call_super_props_when_overriding_equatable_props` (flags a `hashParameters` override that drops the parent's fields) | TODO | TODO — no proposal filed yet |

## Suppressing Rules

```dart
// fast_equatable_lint style (analyzer-plugin prefix)
// ignore: fast_equatable_lint/missing_field_in_equatable_props

// saropa_lints style (once a fast_equatable-aware rule ships)
// ignore: <saropa_rule_name>
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
