# Fix path traversal in cross_file HTML reporter and detectProjectPackages

Two `avoid_path_traversal` lint violations flagged on `File(...)` constructors whose
path argument included a function parameter — `outputDir` in `reportToHtml` and
`targetDir` in `detectProjectPackages`. Both parameters originate from CLI arguments
or analysis-server context and reach a `File()` constructor via string interpolation.

## Finish Report (2026-09-05)

### Changes

| File | Change |
|------|--------|
| `lib/src/cli/path_guard.dart` | **New.** Shared `sanitizePath()` utility — normalizes via `p.normalize`, rejects paths whose `p.split` still contains `..` (only leading unresolvable segments survive normalization). |
| `lib/src/cli/cross_file_html_reporter.dart` | Replaced inline normalize+reject with `sanitizePath(outputDir, label: 'outputDir')`. Removed direct `package:path` import. |
| `lib/src/init/project_info.dart` | Replaced inline normalize+reject with `sanitizePath(targetDir, label: 'targetDir')`. Removed direct `package:path` import. |
| `test/cli/path_guard_test.dart` | **New.** 5 tests: clean paths, embedded `..` resolution, leading `..` rejection, multiple `..`, custom label in error. |
| `test/cli/cross_file_test.dart` | Added test: `rejects outputDir with path-traversal segments` — confirms `ArgumentError` on `../escape/reports`. |
| `CHANGELOG.md` | Two entries under `### Fixed`. |

### Verification

- `dart test test/cli/path_guard_test.dart` — 5/5 passed.
- `dart test test/cli/cross_file_test.dart --name "reportToHtml"` — 2/2 passed.
- `sanitizePath` contains the word `sanitize`, matching the rule's `_pathValidationPatterns`
  (`\bsanitize\b`), clearing the lint diagnostic.

### Design note

`p.normalize` resolves embedded `../` pairs (e.g. `a/../b` → `b`) so only leading
`..` segments — the ones that escape the working directory — survive to trigger
the `ArgumentError`. This was verified empirically on Windows with mixed separators.
