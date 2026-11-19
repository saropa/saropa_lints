# GitHub #403: scan command ignores `analyzer.exclude`

Issue: https://github.com/saropa/saropa_lints/issues/403 (open, labeled enhancement)

## Report

The user lists `"packages/**"` and `"**/packges/**"` under `analyzer.exclude` in
`analysis_options.yaml`, yet `saropa_lints scan` still scans files under `packages/`.
They ask whether `--exclude-globs` is the only way.

## Verdict: the report is correct

- The scan command reads `analysis_options.yaml` only for rule settings
  (`lib/src/scan/scan_config.dart`). It never reads `analyzer.exclude`.
- Files are dropped only by the built-in list (`_isExcluded`,
  `lib/src/scan/scan_runner.dart:964`) and by `--exclude-globs`.
- `dart analyze` / IDE (plugin mode) does honor `analyzer.exclude`, because the Dart
  analyzer applies it before plugins run. Only the standalone scan command is affected.

## Second problem found

`--exclude-globs` patterns are anchored to the whole path (`_globToRegex`,
`scan_runner.dart:990`, starts with `^`). Discovered paths are absolute when the target is
absolute, so a relative pattern such as `packages/**` silently matches nothing. Only
`**/packages/**` works reliably. The analyzer treats `analyzer.exclude` patterns as relative
to the folder holding `analysis_options.yaml`, so a fix must match the same way.

Note: the user's second pattern has a typo (`packges`), so it would not match even in the
analyzer.

## Fix (approved by owner 2026-11-12)

1. Read `analyzer.exclude` from the project's `analysis_options.yaml` in the scan command and
   add those patterns to the exclude list.
2. Match exclude patterns against the path relative to the project root, so `packages/**`
   works for both `analyzer.exclude` and `--exclude-globs`.
3. `--no-exclude` keeps its current meaning (skip built-in list only); `--include-globs`
   still overrides.
4. Tests in the scan test suite; changelog entry; reply on the issue after release.

## Owner decisions

- 2026-11-12: Fix both parts (read `analyzer.exclude`; match patterns relative to the
  project root). Recommended option; chosen because users expect the scan to skip what the
  analyzer skips. The issue reply is posted only after release, with owner say-so.

- 2026-11-12: analyzer.exclude comes from the nearest analysis_options.yaml at or above the
  scanned folder, with patterns relative to that file's folder, matching dart analyze.
  Recommended option, chosen so the scan skips the same files as dart analyze.

## Review follow-up (2026-11-12)

- `loadAnalyzerExcludes(scanRoot)` walks up from the scan target to the nearest
  `analysis_options.yaml` and returns each pattern joined to that file's folder as an absolute
  glob. Chosen because main's #405 matcher already tests the absolute path, so no matcher change
  is needed and subfolder targets work. `bin/scan.dart` now passes an absolute `targetPath` so
  discovered paths are absolute too.
- `--find-stale-ignores` / `--fix-stale-ignores` file discovery (three
  `ScanRunner.discoverDartFiles` calls) now gets the same combined exclude list (built once)
  and the include globs, so excluded files are not treated as scanned and their ignore comments
  are not reported or removed.
- Non-string list items are skipped. `--files` lists are not filtered (same as
  `--exclude-globs`).
- Known limit: `include:` chains in analysis_options.yaml are not followed.
- Known limit: matching is case-insensitive (the analyzer is case-sensitive).
- Tests added: negative control, subfolder target, non-string items, `discoverDartFiles` with
  analyzer excludes (the function the stale-ignore path calls; the CLI wiring itself is not
  covered by a test).

## Fresh-eyes round 2 fixes (2026-11-12)

- Reverted `targetPath: p.absolute(path)` in `bin/scan.dart` (it made JSON `filePath` and report
  grouping absolute for relative targets). `ScanRunner._matchesExcludeGlob` now also tests the
  absolute form of each candidate path, so absolute analyzer-exclude globs match while displayed
  paths stay as before. #405 matching is unchanged.
- `loadAnalyzerExcludes` normalizes each joined pattern, so `./packages/**` works.
- A pattern not ending in `**` (a folder such as `packages/a`) also emits `<pattern>/**`, as
  `dart analyze` excludes the folder's contents.
- The `excludeGlobs` comment in `bin/scan.dart` now sits directly above its declaration.
- Tests: `./` pattern, folder pattern, and a relative-target check. A full `run()` on a relative
  target fails in the analyzer file system (existing limitation), so the relative-path test checks
  `ScanRunner.discoverDartFiles` output: paths stay relative and the exclude applies.

## Implemented (2026-11-12)

- `loadAnalyzerExcludes(projectRoot)` in `lib/src/scan/scan_config.dart` (exported from
  `lib/scan.dart`) reads `analyzer: exclude:`; empty on missing file, section or bad YAML.
- `bin/scan.dart` passes `[...analyzerExcludes, ...--exclude-globs]` to `ScanRunner`.
  `audit` and `accuracy_report` are unchanged (they do not read it).
- `ScanRunner._shouldInclude` / `_findDartFiles` match exclude and include globs against the
  path relative to the project root (forward slashes). `**/packages/**` still works;
  include-globs still override; `--no-exclude` still skips only the built-in list.
- Behavior note: a glob that matched only through a folder above the project root no longer
  matches.
- Changelog: `## [17.2.0] — Unreleased`, Fixed.

Tests: new `test/scan/scan_analyzer_exclude_test.dart` (9 tests, exit 0). Also passed:
`scan_cli_args_test.dart` (104, exit 0) and the `excludeGlobs` group of `scan_runner_test.dart`
(3). `dart analyze lib test bin/scan.dart` exit 0; two existing info lints in `bin/scan.dart`
(lines 159, 219) are not from this change.

Known existing limitation (not changed): scanning a relative target whose path has `..`, or
directory discovery on a relative target, fails in the analyzer file system; the
relative-target test uses an explicit file list instead.

Status: superseded by the sections below. Final state: fixed, reviewed and merged to main on
2026-11-12 (commit e7788a2e), shipping in 17.2.0. Issue reply after release.

## Reconciled with main (2026-11-12)

The relative-pattern part (second problem) landed on main as #405
(`bugs/2026-11-12_scan_exclude_globs_match_relative_to_scanned_folder.md`). This branch's own
relative-matching change was dropped; it now covers `analyzer: exclude:` only, feeding
`loadAnalyzerExcludes` into the existing exclude list in `bin/scan.dart`. The "Implemented"
section above describes the first version; the relative-matching bullets there are superseded by
#405. Tests: `test/scan/scan_analyzer_exclude_test.dart` (3 tests: reader, empty cases, end-to-end
drop). Changelog: one bullet under `## [17.2.0]` / Fixed.

## Review

Verdict: no blocking defects; four non-blocking findings. Test run: `dart test test/scan/scan_analyzer_exclude_test.dart`, 3 passed, exit 0.

1. Scan target a subfolder (`bin/scan.dart:~123`, `lib/src/scan/scan_config.dart:122`): the reader looks only in `<target>/analysis_options.yaml`. `scan lib/` in a project whose options file is at the project root reads nothing, so `analyzer.exclude` is silently not applied (the analyzer would apply it). Same limitation as `loadScanConfig`, but the changelog says "the same as `dart analyze`". Either state "the scanned folder's analysis_options.yaml" or accept.
2. `--files` (`bin/scan.dart`, `applyExclusionsToFileList: dartFiles.isEmpty`): with explicit files, analyzer excludes (like `--exclude-globs`) are not applied. Consistent with existing intent; the changelog does not mention it.
3. Reader fidelity (`scan_config.dart:122-130`): does not follow `include:` chains (an exclude defined in an included options file is missed); a non-string list item is turned into junk by `toString()`; matching is case-insensitive while the analyzer is case-sensitive. Rare.
4. Tests: no negative control (same project without excludes yields 2 files), no test of the `bin/scan.dart` wiring or of a subfolder target. The message assertion (`'Scanning 1 files...'`) passes only if the exclude applied, so it is meaningful.

Checked and fine: other `ScanRunner(` callers. `lsp_server.dart:1005` and `scan_daemon.dart:217` pass explicit files with exclusions off by design; `audit.dart` and `accuracy_report.dart` do not read excludes (no impact for IDE flows, where the analyzer already applied the exclude). The `lib/scan.dart` export is additive and consistent with `loadScanConfig`. The `yaml` dependency is already in pubspec. CHANGELOG bullet is otherwise accurate (relative matching comes from #405). The first "Implemented (2026-11-12)" section of this doc is stale and marked superseded.
