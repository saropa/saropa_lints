# scan --files: out-of-root files skipped silently; redundant contextFor lookup

**Status: Fixed**
**Component:** `lib/src/scan/scan_runner.dart`, `bin/scan.dart`

## Problem

1. Files passed to `scan --files` that lie outside the analysis context root are skipped with only a stderr line. The scan still exits 0, so CI can pass having scanned nothing.
2. `contextFor` is probed per file, then called again in `_scanSingleFileResolved`. The second lookup is redundant, and only `StateError` is caught.

## Expected

1. Exit non-zero (or at least a distinct, documented code) when any requested file was skipped for being outside the root, or when zero files were scanned.
2. Resolve the context once per file and pass it through.

## Fix

1. Added `skippedFileCount` field on `ScanRunner` that tracks files skipped for being outside the analysis root. `bin/scan.dart` now exits 2 when all requested files were skipped, and promotes exit code to 1 when some were skipped (so CI never silently passes on a partial scan). A stderr warning names the count.
2. `_scanSingleFileResolved` now accepts an `AnalysisContext` instead of `AnalysisContextCollection` — the caller resolves the context once and passes it through. The redundant second `contextFor` call in `runResolvedWithCollection` (which also rebuilt the affected-contexts set via a second loop) is eliminated.

## Finish Report (2026-11-20)

### Defect

The resolved scan path (`--resolve`) called `AnalysisContextCollection.contextFor()` up to three times per file: once to guard against `StateError`, once to build the affected-contexts set, and once inside `_scanSingleFileResolved`. The guard catch emitted a stderr message but the scan still exited 0, allowing CI pipelines using `--files` to pass having scanned zero files.

### Changes

**`lib/src/scan/scan_runner.dart`:**
- Added `_skippedFileCount` field (reset at the start of `runResolved` and `runResolvedWithCollection`) and a public `skippedFileCount` getter.
- `_scanFilesResolved`: saves the `AnalysisContext` from the guard `contextFor` call and passes it to `_scanSingleFileResolved`; increments `_skippedFileCount` on skip.
- `runResolvedWithCollection`: stores contexts in a `Map<String, AnalysisContext>` keyed by file path, eliminating the second `contextFor` set-comprehension and the third lookup inside `_scanSingleFileResolved`.
- `_scanSingleFileResolved` signature changed from `AnalysisContextCollection` to `AnalysisContext`, removing the redundant `collection.contextFor(filePath)` call.
- Added import for `package:analyzer/dart/analysis/analysis_context.dart`.

**`bin/scan.dart`:**
- After the scan, checks `runner.skippedFileCount`. When files were explicitly requested (`dartFiles.isNotEmpty`) and any were skipped: prints a stderr warning with the count; exits 2 when `skipped >= dartFiles.length` (all skipped — input error) or when `--strict-files` is set (any skip); promotes `exitCode` to 1 when the computed exit code would otherwise be 0 (partial skip without `--strict-files`).

**`lib/src/scan/scan_cli_args.dart`:**
- Added `strictFiles` boolean field (default false), `--strict-files` parser case.

**`test/scan/scan_runner_test.dart`:**
- Existing `excluded file is skipped, not a StateError` test updated to also assert `runner.skippedFileCount == 1`.
- New test `runResolved tracks skippedFileCount for out-of-root files` exercises the `_scanFilesResolved` skip path.

**`test/scan/scan_cli_args_test.dart`:**
- Two new tests: `--strict-files` defaults to false and parses to true.

### Hardening

- `_skippedFileCount` reset added to `run()` for symmetry with the resolved paths.
- `fileContexts[f]!` force-unwrap in `runResolvedWithCollection` replaced with assert + null guard.
- Code review finding fixed: `diagnostics.isEmpty` check replaced with `skipped >= dartFiles.length` to correctly distinguish "no issues found" from "nothing was scanned."

### Verification

- `dart compile kernel bin/scan.dart` — clean.
- `dart test test/scan/scan_runner_test.dart --name skippedFileCount` — 1/1 pass.
- `dart test test/scan/scan_runner_test.dart --name runResolvedWithCollection` — 3/3 pass.
- `dart test test/scan/scan_cli_args_test.dart` — 103/103 pass.
- Pre-existing test failures in `git_changed_files_test`, `scan_analyzer_exclude_test`, and `scan_runner_test` (resolved superset) confirmed unrelated by stash-pop comparison.
