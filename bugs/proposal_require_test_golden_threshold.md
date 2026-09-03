# PROPOSAL: Require Test Golden Threshold

**Status: Open**

Created: 2026-09-02

## Summary

Flags a project whose ratio of golden test files to widget classes falls below a configured minimum threshold.

## Existing Coverage

`RequireGoldenTestRule` (`lib/src/rules/testing/testing_best_practices_rules.dart`) requires an individual widget to have an associated golden test, checked per file. `require_test_golden_threshold` is the project-wide complement — it doesn't check any single widget, it enforces that the overall golden-to-widget ratio meets a configured minimum, catching gradual drift even where no single missing golden trips the per-widget rule (e.g. widget count growing faster than the golden suite).

## Motivation

Per-widget golden checks catch individual omissions but not slow drift where widget count grows faster than the golden suite is maintained. A project-wide ratio threshold catches that drift directly instead of relying on every individual addition being caught.

## Cross-File Requirement

Cannot be implemented as a per-file analyzer rule — needs a project-wide count of both widget classes (or screens) and existing golden test files to compute a ratio; a single file's AST only ever sees one widget or one test file at a time, never the totals needed for a ratio. Build as a `dart run saropa_lints:cross_file` check rather than a `custom_lint` visitor. See `plans/cross_file_cli_design.md`.

## Detection / Behavior

Counts widget classes (`extends StatelessWidget`/`StatefulWidget`) across `lib/`, counts golden files (`*.png` under a configured goldens directory, or `matchesGoldenFile()` call sites), and compares golden-count / widget-count against a configured minimum ratio (e.g. 0.3).

#### BAD:
```
# lib/: 120 widget classes
# test/goldens/: 12 golden files → ratio 0.10, below configured 0.30 threshold
```

#### GOOD:
```
# lib/: 120 widget classes
# test/goldens/: 40 golden files → ratio 0.33, meets 0.30 threshold
```

## Quick Fix

None — manual refactor required. Adding golden tests is not automatable.

## Alternatives Considered

Gating on an absolute golden-file count instead of a ratio was considered and rejected — it doesn't scale with project size the way a ratio does.
