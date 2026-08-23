# Issue #313: Add `--exclude-globs` and `--include-globs` to scan subcommand

The scan CLI scanned platform ephemeral directories (`linux/flutter/ephemeral/.plugin_symlinks/`, `windows/flutter/ephemeral/.plugin_symlinks/`) containing symlinked plugin source code the user has no control over, producing warnings the reporter could not fix. Additionally, there was no mechanism for users to exclude or force-include arbitrary paths beyond the hardcoded defaults.

## Finish Report (2026-08-22)

### Root Cause

The `_isExcluded()` method in `scan_runner.dart` had no entries for `/ephemeral/` or `/.plugin_symlinks/` path segments, and the scan CLI offered no user-configurable path exclusion or inclusion flags.

### Fix

Three changes:

1. **Hardcoded exclusions expanded** — Added `/ephemeral/` and `/.plugin_symlinks/` to `_isExcluded()` so platform ephemeral directories are excluded by default without any user action.

2. **`--exclude-globs` flag added** — A new CLI flag that accepts one or more glob patterns (supporting `**`, `*`, `?`). Patterns are compiled to `RegExp` once at `ScanRunner` construction and applied during file discovery. Backslash separators in patterns are normalized to forward slashes so Windows-native paths work correctly. Exclusion respects `applyExclusionsToFileList` so callers that bypass exclusions (e.g. accuracy reports) get consistent behavior.

3. **`--include-globs` flag added** — An inverse flag that overrides the hardcoded exclusions. When a path matches both a default exclusion (e.g. `ephemeral/`) AND an include-glob, the include wins. This lets users force-scan third-party plugin code they want to audit.

### Files Changed

| File | Change |
|------|--------|
| `lib/src/scan/scan_runner.dart` | Added `/ephemeral/` and `/.plugin_symlinks/` to `_isExcluded()`. Added `_globToRegex()`, `_matchesExcludeGlob()`, `_shouldInclude()`, `excludeGlobs` and `includeGlobs` constructor params. Threaded glob matching into `_findDartFiles()` and `_resolveDartFiles()`. |
| `lib/src/scan/scan_cli_args.dart` | Added `excludeGlobs` and `includeGlobs` fields to `ScanCliArgs` and parsing in `parseScanArgs()`. |
| `bin/scan.dart` | Passes `parsed.excludeGlobs` and `parsed.includeGlobs` to `ScanRunner`. Added both flags to `_printUsage()`. |
| `doc/guides/cli.md` | Added `--exclude-globs` and `--include-globs` rows to the scan flag table. |
| `test/scan/scan_cli_args_test.dart` | 5 tests for `--exclude-globs` parsing, 3 tests for `--include-globs` parsing. |
| `test/scan/scan_runner_test.dart` | 1 test for hardcoded ephemeral exclusion, 2 tests for `excludeGlobs` runtime behavior (including backslash normalization), 1 test for `includeGlobs` overriding hardcoded exclusions. |
| `CHANGELOG.md` | Added entries under `[15.2.3]`. |

### Review Findings Addressed

- **Windows backslash normalization** — The initial `_globToRegex` implementation did not normalize backslash separators in user-supplied patterns, causing silent no-op exclusions on Windows. Fixed by adding `glob.replaceAll('\\', '/')` before pattern compilation.
- **`applyExclusionsToFileList` inconsistency** — Glob exclusions are now gated behind the same `applyExclusionsToFileList` flag as the hardcoded exclusions, so callers that bypass exclusions get consistent behavior.
- **Documentation gap** — `doc/guides/cli.md` was missing the new flags. Added.
- **Missing runtime test coverage** — Added `ScanRunner excludeGlobs` test group exercising the actual file-exclusion path through `ScanRunner`, including backslash normalization and include-glob override.

### Known Limitations

- `ScanRunner.discoverDartFiles` (static) does not accept glob patterns — only the instance code path uses them. The scan daemon gets hardcoded exclusions automatically but not user-supplied globs.
- Glob syntax supports only `**`, `*`, and `?` — POSIX character classes (`[abc]`) and alternations (`{a,b}`) are not supported. Invalid patterns compile to a regex that may match nothing.
- Case-insensitive matching is used for all globs, which is correct for Windows but may surprise Linux users with case-sensitive filesystems.
