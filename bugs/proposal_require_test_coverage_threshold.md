# PROPOSAL: Require Test Coverage Threshold

**Status: Open**

Created: 2026-09-02

## Summary

Flags a project whose aggregate line/branch coverage, read from `coverage/lcov.info`, falls below a configured threshold.

## Motivation

Coverage regressions creep in file-by-file and are invisible without a project-wide summary gate. Teams that set a coverage floor need it enforced automatically as part of the standard tooling rather than eyeballing a separate Codecov badge.

## Cross-File Requirement

Cannot be implemented as a per-file analyzer rule — needs aggregate LCOV coverage output (`coverage/lcov.info`, produced by `dart test --coverage`/`flutter test --coverage`) summed across the whole project; a single file's AST has no notion of which lines were executed by the test suite. Build as a `dart run saropa_lints:cross_file` check rather than a `custom_lint` visitor. See `plans/cross_file_cli_design.md`.

## Detection / Behavior

Parses LCOV `lcov.info`, sums `LF`/`LH` (lines found/hit) across all `SF` records, and compares the resulting percentage against a configured minimum (e.g. 80%).

#### BAD:
```
# coverage/lcov.info shows 62% aggregate line coverage
# configured threshold: 80%
```

#### GOOD:
```
# coverage/lcov.info shows 84% aggregate line coverage
# configured threshold: 80% — passes
```

## Quick Fix

None — manual refactor required. Writing tests to raise coverage is not automatable.

## Alternatives Considered

Per-file coverage thresholds instead of an aggregate were considered and rejected as the primary mode — a new file with low initial coverage would fail immediately. An aggregate check with an optional per-file floor was noted as a possible future refinement.
