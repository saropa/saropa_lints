# PROPOSAL: Prefer Correct Screenshots

**Status: Open**

Created: 2026-09-02

## Summary

Flags screenshot/golden test files whose name or directory location doesn't match the project's expected naming or layout convention.

## Existing Coverage

`RequireGoldenTestRule` (`lib/src/rules/testing/testing_best_practices_rules.dart`) checks that a golden test exists for a widget. It does not validate the naming or directory convention of the produced screenshot/golden file, which this rule covers.

## Motivation

Goldens that drift from a shared naming/directory convention are hard to locate, get orphaned when a widget is renamed (the old `.png` stays committed but unreferenced), and break tooling that assumes a fixed layout — golden-diff review scripts, CI artifact upload, cleanup scripts.

## Detection / Behavior

Fires when a golden asset's filename or directory doesn't match the project-configured convention (e.g. `test/goldens/<test_file_stem>/<variant>.png` mirroring the test file that references it via `matchesGoldenFile()`).

#### BAD:
```
test/widgets/login_screen_test.dart
test/screenshot1.png          // wrong location, non-descriptive name
```

#### GOOD:
```
test/widgets/login_screen_test.dart
test/goldens/login_screen_test/default.png
```

## Quick Fix

None — manual refactor required. Renaming or moving a golden asset must stay in sync with its `matchesGoldenFile()` call site; an automatic move risks silently breaking golden comparisons.

## Alternatives Considered

Enforcing a single fixed convention was considered and rejected — teams differ (flat `goldens/` directory vs. per-test subfolder), so the rule should read the convention from project config rather than hardcode one.
