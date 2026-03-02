# Bug: Report showed duplicate issues (same violation, relative vs absolute path)

**Resolved:** 2026-03-02

## Summary

The analysis report (`*_saropa_lint_report.log`) inflated issue counts because the same violation could appear twice: once with a relative path (e.g. `lib/foo.dart`) and once with an absolute path (e.g. `D:\src\proj\lib\foo.dart`). Deduplication used the raw path in the key `(file, line, rule)`, so both were kept. Users saw e.g. "2,716 issues across 40 files" when a large share were duplicates.

## Root cause

- Violations are recorded with `unit.file.path` from the analyzer, which can differ by context (absolute in some code paths, relative in others).
- `ReportConsolidator._deduplicateViolations` built the dedup key from `v.file` without normalizing, so the same physical file under two path forms produced two keys.
- `issuesByFile` and analyzed-files union also used raw paths, so file counts could be inflated.

## Fix

In `lib/src/report/report_consolidator.dart`:

1. **Path normalization:** Added `_normalizePath(path, projectRoot)` to convert any path to project-relative form with forward slashes (same semantics as `toRelativePath()` in `violation_export.dart`; not shared to avoid circular dependency).

2. **Merge:** `_merge(projectRoot, batches)` now normalizes every file path when building the analyzed-files set and passes `projectRoot` into deduplication.

3. **Deduplication:** `_deduplicateViolations(projectRoot, batches)` builds the dedup key from the normalized path and stores `ViolationRecord` with normalized `file`, so one entry per (file, line, rule) and downstream (report, JSON export) see a single canonical path.

4. **Consolidate:** `consolidate(projectRoot, sessionId)` passes `projectRoot` into `_merge`.

Result: totals, files-with-issues, and per-file counts reflect unique issues; no logic duplication, no new race conditions (consolidation runs on a single isolate after batch writes). Unit test added in `test/report_consolidator_test.dart` (path deduplication across batches).
