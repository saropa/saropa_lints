# Bug: Analysis report session management

## Status: Fixed

## Summary

`AnalysisReporter` has no reliable mechanism for detecting when a new analysis
session begins (e.g. user hits F5 to build and run). This causes two classes of
problems:

1. **Split reports** -- a single analysis run produces multiple report files
   because the 3-second debounce fires during a gap between file batches
2. **Stale single report** -- after removing the debounce-based session
   detection (the attempted fix for #1), the reporter now overwrites a single
   file forever, losing the ability to compare reports across builds

## Desired behavior

- Each build/run cycle (F5) produces **one new report file**
- Late-arriving files within the same analysis pass are included in that report
- The user can compare successive reports to track progress
- Reports do not grow unbounded (cap the inline violation list for large
  projects)

## Root cause

The analyzer server (`custom_lint`) is a long-lived process. It does not
receive build or launch notifications from the IDE. The reporter has no
external signal for "a new build started."

The original code used a debounce timeout as a proxy for session boundaries:

```text
_writeReport() sets _sessionEnded = true
scheduleWrite() checks _sessionEnded → calls _startNewSession()
_startNewSession() resets all trackers + generates new timestamp
```

This fails because the analyzer can have gaps > 3 seconds **within** a single
analysis pass (observed: 83-second gap between batch 1 of 35 files and batch 2
of 2 files). When the debounce fires mid-run, the tracker reset wipes
accumulated data, and the new timestamp creates a second report file containing
only the straggler results.

## Observed behavior (original code)

```text
reports/20260207_134211_saropa_lint_report.log  →  705 issues, 37 files
reports/20260207_134334_saropa_lint_report.log  →    2 issues,  2 files
```

The second file is a straggler fragment from the same analysis run. Combined
they should be one report with 707 issues across 39 files.

## Current state (after partial fix)

The `_sessionEnded` flag and `_startNewSession()` method were removed from
`AnalysisReporter`. Now `scheduleWrite()` simply resets the debounce timer and
the same timestamped file is overwritten on each write.

This fixes the split-report problem but introduces new issues:

- **No session boundaries** -- the report file is never replaced with a fresh
  one. The timestamp in the filename is from when the analyzer server first
  started (could be hours or days ago).
- **No progress tracking across builds** -- the user cannot compare "before"
  and "after" reports because there is only ever one file.
- **Unbounded report size** -- for large projects with thousands of violations,
  the full violation list is rewritten to disk on every debounce cycle (every
  3 seconds of idle during analysis). A 17,000-violation project would produce
  a ~5 MB file rewritten repeatedly.
- **`reset()` is dead code** -- `AnalysisReporter.reset()`,
  `ProgressTracker.reset()`, and `ImpactTracker.reset()` are defined but never
  called anywhere in the codebase.

## Proposed fix: re-analysis-based session detection

Instead of using a timeout, detect session boundaries by observing when the
analyzer **re-visits files it has already analyzed**. This is the natural signal
that a new build/analysis pass has started.

The mechanism already exists: `ProgressTracker._clearFileData(path)` is called
when `recordFile()` sees a previously-completed file being analyzed again
(`wasNew == false && path != _currentFile`). This only fires during
re-analysis, never for first-time stragglers.

### Detection logic

| Scenario                          | `_clearFileData` called? | Action            |
|-----------------------------------|--------------------------|-------------------|
| Initial analysis, all files new   | No                       | Same report       |
| Straggler files arriving late     | No (first time seen)     | Same report       |
| F5 build, files re-analyzed       | Yes                      | **New report**    |

### Implementation outline

1. **Add a flag to `ProgressTracker`**: `static bool _hasReanalyzedFile = false`
2. **Set it in `_clearFileData()`**: `_hasReanalyzedFile = true`
3. **Expose it**: `static bool get hasReanalyzedFile => _hasReanalyzedFile`
4. **Add a reset for the flag**: clear it in a new
   `static void clearReanalysisFlag()` method
5. **In `AnalysisReporter.scheduleWrite()`**: if a report has already been
   written (`_reportWritten == true`) AND `ProgressTracker.hasReanalyzedFile`
   is true, start a new session:
   - Call `ProgressTracker.reset()` and `ImpactTracker.reset()`
   - Generate a new timestamp
   - Set `_pathsLogged = false`
   - Clear the re-analysis flag
6. **In `AnalysisReporter._writeReport()`**: set `_reportWritten = true` after
   writing
7. **Cap the violation list**: for large projects, truncate inline violations
   (e.g. top 500 per impact level) with a count of omitted items. Optionally
   write the full list to a separate CSV.

### Key files to modify

| File | Change |
|------|--------|
| `lib/src/saropa_lint_rule.dart` | Add `_hasReanalyzedFile` flag to `ProgressTracker`, set in `_clearFileData()`, expose getter, add `clearReanalysisFlag()` |
| `lib/src/report/analysis_reporter.dart` | Add `_reportWritten` flag, check re-analysis flag in `scheduleWrite()`, start new session when detected, add violation list cap |

### Edge cases to consider

- **Analyzer restarts**: all static state is lost, so `initialize()` naturally
  starts a fresh session. No special handling needed.
- **Single file re-analysis** (user saves one file): `_clearFileData` fires
  for that file, triggering a new session. This is correct -- the user gets a
  fresh report reflecting the fix.
- **No re-analysis** (user opens project, analyzer runs once, never builds):
  one report file, never replaced. Correct.
- **Rapid successive builds**: each build triggers re-analysis, each gets its
  own report. The debounce ensures the report isn't written until analysis
  settles. Correct.
- **Report file retention**: old report files accumulate. Consider adding a
  retention policy (e.g. keep last 10 reports, configurable).

## Files referenced

- `lib/src/report/analysis_reporter.dart` -- report writer, session management
- `lib/src/saropa_lint_rule.dart` -- `ProgressTracker._clearFileData()` (line
  ~814), `ProgressTracker.recordFile()` (line ~393), `scheduleWrite()` call
  sites (lines ~2333, ~2747)
- `bin/init.dart` -- `_writeLogFile()` (init log), analysis prompt (line ~978)
