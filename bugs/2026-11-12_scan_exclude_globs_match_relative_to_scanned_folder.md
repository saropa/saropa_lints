# scan --exclude-globs did not match relative to the scanned folder

Issue: https://github.com/saropa/saropa_lints/issues/405

Status: fixed on branch, awaiting release.

## Cause

`dart run saropa_lints scan . --exclude-globs "packages/**"` kept
`packages/mypackage/lib/src/x.dart`. In `lib/src/scan/scan_runner.dart`,
`_globToRegex` anchors each pattern with `^...$` and `_matchesExcludeGlob`
tested it against the full listed path (`./packages/...` from
`Directory('.').listSync`, or an absolute path). `packages/**` can never match
those, so only `**/packages/**` worked. The same matcher serves
`--include-globs`.

## Fix

`_shouldInclude` and `_matchesExcludeGlob` now receive the scan root
(`targetPath`) and also test each pattern against the path relative to it
(forward slashes, no leading `./`). A file matches if either form matches, so
every pattern that worked before still works. Applies to exclude and include
globs, for directory discovery and for explicit file lists. `--exclude-globs`
help text in `bin/scan.dart` now says patterns are matched relative to the
scanned folder. `ScanRunner.discoverDartFiles` gained optional `excludeGlobs`
and `includeGlobs` so the matching can be tested directly.

## Tests

`test/scan/scan_exclude_globs_relative_test.dart`: `packages/**` excludes
`./packages/a/lib/x.dart` when scanning `.`; same with an absolute target path;
`**/packages/**` still works; a non-matching pattern keeps all files; a
relative include-glob overrides a hardcoded exclusion. Existing
`ScanRunner excludeGlobs` tests in `test/scan/scan_runner_test.dart` still pass.

## Reply to the reporter

Thanks for the report. This was a bug: patterns like `packages/**` were
compared against the full path instead of the path inside the folder you
scanned, so only `**/packages/**` matched. It is fixed and will be in the next
release; until then `--exclude-globs "**/packages/**"` works.
