# Task: `avoid_any_version`

## Summary
- **Rule Name**: `avoid_any_version`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Pubspec Rules

## Problem Statement

Using `any` as a version constraint in `pubspec.yaml`:
```yaml
dependencies:
  some_package: any
```

Allows pub to resolve to ANY version of the package, including major breaking versions. This:
1. Creates non-reproducible builds (different machines may resolve different versions)
2. Allows silent breaking changes when a major version is released
3. Makes it impossible to pin a working dependency graph
4. Can cause transitive dependency conflicts

The `any` constraint is sometimes used as a quick hack to resolve version conflicts but should always be replaced with a proper version range.

## Description (from ROADMAP)

> Avoid `any` version constraint - specify version ranges.

## Trigger Conditions

Detect `any` as the version value in `pubspec.yaml` dependencies, dev_dependencies, or dependency_overrides.

**Note**: This rule requires YAML parsing of `pubspec.yaml`, which is NOT available in the standard `custom_lint` AST model (which only processes `.dart` files). This rule likely needs to be a **custom analysis pass** or implemented as a **separate check in the publish script**.

## Implementation Options

### Option A — Dart File Check (Limited)
Not directly applicable — `pubspec.yaml` is not a `.dart` file.

### Option B — Separate Script Check
Add to the `publish_to_pubdev.py` script or `pre-commit` hook as a yaml-parsing check.

### Option C — Custom Lint via YAML Parsing
If `custom_lint` supports a plugin that can inspect files beyond `.dart`, implement as a custom analysis pass. This requires the `custom_lint` YAML plugin or a separate Dart tool.

### Option D — Pubspec Lint Package
The `pubspec_consistency` / `very_good_analysis` packages may already cover this. Check existing packages before implementing.

## Code Examples

### Bad (pubspec.yaml — Should trigger)
```yaml
dependencies:
  flutter:
    sdk: flutter
  some_package: any  # ← trigger: unpinned
  another_package: any  # ← trigger
```

### Good (pubspec.yaml — Should NOT trigger)
```yaml
dependencies:
  flutter:
    sdk: flutter
  some_package: ^1.2.3  # ✓ caret syntax
  another_package: '>=1.0.0 <2.0.0'  # ✓ range syntax
  pinned_package: 1.2.3  # ✓ pinned version
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `flutter:` with `sdk: flutter` | **Suppress** — SDK dependency, not a pub package | |
| `dart:` with `sdk: dart` | **Suppress** | |
| `path:` dependencies | **Suppress** — path deps don't use version strings | |
| `git:` dependencies | **Suppress** — git deps use `ref`, not version | |
| `dev_dependencies` with `any` | **Trigger** — same concern in dev deps | |
| `dependency_overrides` with `any` | **Trigger** — overrides with `any` are extra dangerous | |

## Unit Tests

### Violations
1. `pubspec.yaml` with `some_package: any` → 1 lint
2. `dev_dependencies` with `test: any` → 1 lint

### Non-Violations
1. `some_package: ^1.2.3` → no lint
2. `flutter: sdk: flutter` → no lint
3. `my_pkg: path: ../my_pkg` → no lint

## Quick Fix

Offer "Replace `any` with `^current_version`" — requires resolving the current version from pub.dev or from `pubspec.lock`. This is not feasible as a static analysis quick fix; recommend as a manual step.

## Notes & Issues

1. **YAML PARSING CHALLENGE**: This rule fundamentally operates on `pubspec.yaml`, not `.dart` files. Standard `custom_lint` processes only Dart source. Implementation requires either:
   - A custom analysis plugin that processes YAML files
   - A separate script/pre-commit hook
   - Integration with `pubspec` package parsing
2. **Check existing solutions**: `package:pubspec_parse` and the official `pubspec_check` / `very_good_analysis` or `pana` checks may already cover this.
3. **The `_analyze_pubspec.py`** script in the project (per git status: `scripts/modules/_analyze_pubspec.py`) may already handle pubspec validation. Check before implementing a new Dart rule.
4. **Related pubspec rules** (`avoid_dependency_overrides`, `prefer_semver_version`, etc.) all face the same YAML parsing challenge. Consider implementing all of them in a single pubspec analysis pass.
