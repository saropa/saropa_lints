# Migrating from flutter_refactor_plugin

This guide helps you migrate from
[`flutter_refactor_plugin`](https://pub.dev/packages/flutter_refactor_plugin) to
`saropa_lints`.

> **This package is abandoned.** The `flutter_refactor_plugin` source repository
> returns a 404 — the code is no longer available, and the package receives no
> updates. Remove it from your `pubspec.yaml`. Keeping a dependency whose source has
> vanished is a supply-chain risk with zero upside.

**Confidence note**: Everything below is derived from the pub.dev package description
only — it is unverified and should be treated as low-confidence.

## Why Migrate?

| Feature | flutter_refactor_plugin | saropa_lints |
|---------|--------------------------|--------------|
| **Rule count** | 1 rule (unverified) | 2300+ custom rules |
| **Focus** | Automatic widget-extraction refactor for deep widget nesting | Full-spectrum security, accessibility, performance, and library-specific analysis |
| **Quick fixes** | Content-based automatic widget extraction | 221+ quick fixes across the whole rule set |

`flutter_refactor_plugin`'s described purpose is a single rule —
`prefer_declarative_over_widget_nesting` — that both detects deep widget nesting and offers an
automatic refactor: extracting the nested subtree into a new widget, with a name generated from
its content. saropa_lints' `avoid_excessive_widget_depth` detects the same underlying problem but
does not offer an equivalent extraction quick fix.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_refactor_plugin: ^<version>

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

Coverage: 1 rules — 1 PARTIAL

| flutter_refactor_plugin Rule | Status | Saropa Rule / Action |
|---|---|---|
| `prefer_declarative_over_widget_nesting` | PARTIAL | `avoid_excessive_widget_depth` — detects the depth violation but has no automatic widget-extraction refactor; extraction must be done by hand |

## What You Lose

If your team relies on the automatic extract-widget refactor (rather than just the depth
diagnostic), there is no saropa_lints equivalent — extract the nested subtree into its own widget
manually, or use your IDE's built-in "Extract Widget" refactor action.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
