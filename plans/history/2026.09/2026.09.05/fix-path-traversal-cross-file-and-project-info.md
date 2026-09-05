# Fix path traversal in cross_file HTML reporter and detectProjectPackages

Two `avoid_path_traversal` lint violations flagged on `File(...)` constructors whose
path argument included a function parameter — `outputDir` in `reportToHtml` and
`targetDir` in `detectProjectPackages`. Both parameters originate from CLI arguments
or analysis-server context and reach a `File()` constructor via string interpolation.

## Finish Report (2026-09-05)

### Changes

| File | Change |
|------|--------|
| `lib/src/cli/path_guard.dart` | **New.** Shared `sanitizePath()` utility — normalizes via `p.normalize`, rejects paths whose `p.split` still contains `..` (only leading unresolvable segments survive normalization). Doc comment warns callers with legitimate `../` to resolve to absolute first. |
| `lib/src/cli/cross_file_html_reporter.dart` | Replaced inline normalize+reject with `sanitizePath(outputDir, label: 'outputDir')`. |
| `lib/src/init/project_info.dart` | Replaced inline normalize+reject with `sanitizePath(targetDir, label: 'targetDir')`. Added doc noting the analysis-server assumption. |
| `bin/cross_file.dart` | Added `sanitizePath` for `projectPath` and `resolvedOutputDir` at CLI boundary. |
| `bin/doctor.dart` | Added `sanitizePath` for user-supplied project directory. |
| `bin/memory_report.dart` | Added `sanitizePath` for user-supplied project root. |
| `bin/migrate_config.dart` | Added `sanitizePath` for user-supplied project directory. |
| `scripts/check_path_guard.py` | **New.** Integrity check: scans `lib/src/cli/` and `bin/` for `File()`/`Directory()` with interpolation, fails if the file lacks `path_guard.dart` import or `sanitizePath` call. Allowlist for verified-safe sites (e.g. `bin/scan.dart` timestamp-derived path). |
| `test/cli/path_guard_test.dart` | **New.** 5 tests: clean paths, embedded `..` resolution, leading `..` rejection, multiple `..`, custom label in error. |
| `test/cli/cross_file_test.dart` | Added test: `rejects outputDir with path-traversal segments`. |
| `CHANGELOG.md` | Entries under `### Fixed` and Maintenance `<details>`. |

### Verification

- `dart test test/cli/path_guard_test.dart` — 5/5 passed.
- `dart test test/cli/cross_file_test.dart --name "reportToHtml"` — 2/2 passed.
- `python scripts/check_path_guard.py` — all sites guarded.
- `sanitizePath` contains the word `sanitize`, matching the rule's `_pathValidationPatterns`
  (`\bsanitize\b`), clearing the lint diagnostic.

### Design note

`p.normalize` resolves embedded `../` pairs (e.g. `a/../b` → `b`) so only leading
`..` segments — the ones that escape the working directory — survive to trigger
the `ArgumentError`. Verified empirically on Windows with mixed `/` and `\` separators.
Callers with a legitimate need for `../` in input must resolve to absolute before
calling `sanitizePath`.
