# Migrating from import_lint

This guide helps you migrate from [`import_lint`](https://pub.dev/packages/import_lint) to `saropa_lints`.

## Why Migrate?

| Feature | import_lint | saropa_lints |
|---------|-------------|--------------|
| **Rule count** | 1 configurable rule-engine | 2300+ custom rules |
| **Focus** | Generic import-boundary DSL | Broad Dart/Flutter analysis, incl. fixed-layer import rules |
| **Configuration** | `target`/`from`/`except` glob rules in YAML | 5 progressive tiers, minimal setup |
| **Maintenance** | Actively maintained, narrow scope | Actively maintained, broad scope |
| **Cost** | Free & open source | Free & open source |

`import_lint` is a single-purpose plugin: it lets a project define arbitrary `target`/`from`/`except` glob rules that forbid one part of a codebase from importing another (e.g. "features must not import other features directly"). saropa_lints does not ship an equivalent generic DSL — it has fixed rules for a few common layering violations instead.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  import_lint: ^1.0.0

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
    - import_lint

import_lint:
  rules:
    - target: "lib/features/**"
      from: "lib/features/**"
      except: ["lib/shared/**"]

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

Coverage: 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%).

| import_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `target`/`from`/`except` glob DSL (user-defined import-boundary rules) | TODO | TODO — no proposal filed yet. saropa_lints has no generic, project-configurable import-boundary DSL; it ships fixed rules for specific layering patterns instead (see below). |

## What You Gain

saropa_lints doesn't replicate `import_lint`'s generic DSL, but it does enforce several common import/layering violations out of the box, with no configuration required:

- `avoid_importing_entrypoint_exports` — prevents importing a package's barrel/entrypoint file when a narrower import is available
- `avoid_barrel_files` — flags barrel files that re-export unrelated modules, a common source of accidental cross-layer imports
- `avoid_double_slash_imports` / `avoid_duplicate_named_imports` / `prefer_named_imports` — import hygiene rules that catch many of the same mistakes a hand-written boundary rule would

## What You Lose

`import_lint`'s core value is its **arbitrary, project-defined** boundary DSL — teams can encode any layering rule specific to their architecture (e.g. "feature A must not import feature B", "data layer must not import UI layer"). saropa_lints has no equivalent mechanism; only its fixed, built-in import rules apply.

If your project relies on custom architectural boundaries beyond what saropa_lints' fixed rules cover, keep `import_lint` running alongside saropa_lints — the two plugins don't conflict.

```yaml
# analysis_options.yaml — running both
analyzer:
  plugins:
    - import_lint
    - custom_lint

import_lint:
  rules:
    - target: "lib/features/**"
      from: "lib/features/**"
      except: ["lib/shared/**"]
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
