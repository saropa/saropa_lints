# Migrating from hardcoded_strings_lint

This guide helps you migrate from
[`hardcoded_strings_lint`](https://github.com/ShahSomething/hardcoded_strings_lint) to `saropa_lints`.

## Why Migrate?

| Feature | hardcoded_strings_lint | saropa_lints |
|---------|------------------------|--------------|
| **Rule count** | 1 rule | 2300+ custom rules |
| **Focus** | Hardcoded strings in Flutter widget constructors | Full-spectrum security, accessibility, performance, and library-specific analysis |
| **Architecture** | `analysis_server_plugin` (native, no `custom_lint`) | `custom_lint` plugin |
| **Quick fixes** | Ignore comment, ignore-for-file, disable in config, extract-to-variable | 221+ quick fixes across the whole rule set |

`hardcoded_strings_lint` is a single-purpose plugin: it flags string literals passed directly to
Flutter widget constructors, with a technical-string allowlist (URLs, emails, hex colors, file
paths, snake_case/CONSTANT_CASE identifiers) and a callback-body exemption. saropa_lints'
`avoid_hardcoded_strings_in_ui` covers the same underlying concept as part of its i18n rule
family, alongside the rest of saropa's accessibility/security/performance coverage.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before — hardcoded_strings_lint needs no pubspec.yaml entry at all,
# it's declared entirely under the top-level `plugins:` key.

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
plugins:
  hardcoded_strings_lint:
    version: ^2.1.0
    diagnostics:
      avoid_hardcoded_strings_in_widgets: true

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

Coverage: 1 HAVE (100%), 0 PARTIAL (0%), 0 TODO (0%) — unverified precision, see note below.

| hardcoded_strings_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_hardcoded_strings_in_widgets` | HAVE | `avoid_hardcoded_strings_in_ui` |

**Note on precision**: `hardcoded_strings_lint`'s source (`lib/src/`) was not directly readable at
audit time (GitHub tree listing was cut off); its documented behavior — callback-body exemption,
technical-string allowlist (URLs/emails/hex/paths), short-string skip (≤2 chars), and an allowlist
of acceptable widget properties (`semanticsLabel`, `heroTag`, `tooltip`, etc.) — has not been
directly diffed against saropa's `avoid_hardcoded_strings_in_ui` implementation. If your project
depends on precise allowlist parity, verify behavior on your codebase before dropping
`hardcoded_strings_lint`.

## Suppressing Rules

```dart
// hardcoded_strings_lint style
// ignore: hardcoded_strings_lint/avoid_hardcoded_strings_in_widgets

// saropa_lints style
// ignore: avoid_hardcoded_strings_in_ui
```

## What You Gain

`saropa_lints` includes the rest of its i18n rule family beyond hardcoded-string detection —
translation-key validation, unused-locale-key detection, and pluralization checks — plus 2300+
rules covering security, accessibility, and Flutter-specific patterns entirely outside
`hardcoded_strings_lint`'s scope.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
