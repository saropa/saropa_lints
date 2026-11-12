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

Status: fixed on branch, not merged. Issue reply after release, with owner say-so.

## Reconciled with main (2026-11-12)

The relative-pattern part (second problem) landed on main as #405
(`bugs/2026-11-12_scan_exclude_globs_match_relative_to_scanned_folder.md`). This branch's own
relative-matching change was dropped; it now covers `analyzer: exclude:` only, feeding
`loadAnalyzerExcludes` into the existing exclude list in `bin/scan.dart`. The "Implemented"
section above describes the first version; the relative-matching bullets there are superseded by
#405. Tests: `test/scan/scan_analyzer_exclude_test.dart` (3 tests: reader, empty cases, end-to-end
drop). Changelog: one bullet under `## [17.2.0]` / Fixed.
