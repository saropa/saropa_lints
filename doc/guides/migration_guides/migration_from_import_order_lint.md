# Migrating from import_order_lint

This guide helps you migrate from `import_order_lint` to `saropa_lints`.

## Why Migrate?

| Feature | import_order_lint | saropa_lints |
|---------|--------------------|--------------|
| **Rule count** | 1 check (import ordering) | 2300+ rules across security, a11y, performance, and 15+ libraries |
| **Architecture** | Standalone CLI tool (not a `custom_lint` plugin) | `custom_lint` plugin, real-time IDE feedback |
| **Import ordering** | `dart:` → `flutter/` → external packages → project → relative, alphabetized, blank-line-separated groups | Same grouping/ordering enforced as IDE diagnostics |
| **Auto-fix** | `import_order_lint:import_order` rewrites files in place | Quick fixes per-violation, no standalone rewrite command |
| **CI mode** | `--set-exit-if-changed` (mirrors `dart format`'s exit-code contract) | No CLI exit-code equivalent — diagnostics surface through `dart run custom_lint` / `dart analyze` |

`import_order_lint` is not a `custom_lint` rule — it is a standalone CLI (`dart run
import_order_lint:import_order`) that rewrites import blocks and returns a `dart format`-style exit code for
CI. saropa_lints covers the same violations as live analyzer diagnostics with quick fixes, but has no
standalone auto-fix executable or `--set-exit-if-changed` CI contract.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  import_order_lint: ^0.2.2

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^15.0.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

If your CI pipeline depends on `import_order_lint`'s `--set-exit-if-changed` exit-code gate, keep it installed
for that step and add `saropa_lints` for everything else — the two do not conflict, since one is a CLI tool
and the other a `custom_lint` plugin:

```yaml
# GitHub Actions
- name: Check import ordering
  run: dart run import_order_lint:import_order --set-exit-if-changed

- name: Run custom_lint
  run: dart run custom_lint
```

## Rule Mapping

Coverage: 0 HAVE (0%), 1 PARTIAL (100%), 0 TODO (0%).

| import_order_lint Check | Status | Saropa Rule / Action |
|---|---|---|
| Import ordering/grouping (`dart:` / `flutter/` / external / project / relative, alphabetized) | PARTIAL | `prefer_grouped_imports` / `prefer_sorted_imports` / `prefer_import_group_comments` flag the same violations as lint diagnostics, but saropa_lints has no `--set-exit-if-changed` auto-fix CLI equivalent to `dart format`'s exit-code contract |

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
