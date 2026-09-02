# Migrating from team_guard

This guide helps you migrate from [`team_guard`](https://github.com/HazemHamdy7/team_guard) to `saropa_lints`.

## Why Migrate?

| Feature | team_guard | saropa_lints |
|---------|-----------|--------------|
| **Rule count** | 1 configurable mechanism | 2300+ custom rules |
| **Focus** | Project-configurable widget/class ban-and-replace | Full-spectrum security, accessibility, performance, and library-specific analysis |
| **Configuration** | `team_guard.yaml` widget/class replacement map | 5 progressive tiers |
| **Scaffolding** | Generates replacement stub files in `lib/core` | N/A — saropa_lints does not scaffold code |

`team_guard` is a narrowly-scoped plugin: it exists to let a team ban specific widgets/classes
(for example `Text`, `Colors`, `Dio`, `GetIt`) and require a project-specific replacement, with a
quick fix that rewrites the import and constructor call. saropa_lints covers a much broader
surface but does not (yet) offer an equivalent generic, project-configurable ban-and-replace engine.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  team_guard: ^1.0.17

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - custom_lint

team_guard:
  # team_guard.yaml holds the widget/class ban-and-replace map

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

## Using Both Together

`team_guard`'s widget/class-replacement mechanism has no saropa_lints equivalent, so keep it
alongside saropa_lints if your project relies on it:

```yaml
# pubspec.yaml
dev_dependencies:
  team_guard: ^1.0.17
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

Both plugins run under the same `custom_lint` umbrella, so no `analysis_options.yaml` conflict
exists between them.

## Rule Mapping

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%).

| team_guard Rule | Status | Saropa Rule / Action |
|---|---|---|
| `team_guard.forbidden_widget` — generic project-configurable "ban this widget/class, suggest this replacement" mechanism with an import-fixing quick fix | TODO | TODO — no proposal filed yet (see [GAP_ANALYSIS.md](../../../plans/GAP_ANALYSIS.md) Gap Theme 2 — generic, user-configurable architecture/import-boundary engines) |

saropa_lints' closest fixed-relationship equivalent is `banned_identifier_usage`
(name-only matching, no replacement-import quick fix, not project-configurable via a
separate YAML file). It does not cover `team_guard`'s use case of scaffolding a replacement
widget/class and auto-fixing every call site's import.

## Suppressing Rules

```dart
// team_guard style
// ignore: team_guard.forbidden_widget

// saropa_lints style (for the closest equivalent)
// ignore: banned_identifier_usage
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
