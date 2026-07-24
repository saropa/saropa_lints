# Plugin Isolate Restart Storm — Mitigations

The Dart analysis server respawned the saropa_lints plugin isolate hundreds of times per day (13,660 over 91 days on the `contacts` project), invalidating all diagnostics from the VS Code Problems tab each time. Root cause investigation identified three contributing factors: the analysis server's own isolate recycling, the plugin writing log files into directories visible to the file watcher, and non-project working directories (VS Code install dir) causing noisy 0-rules config loads.

## Finish Report (2026-07-24)

### Changes

**`lib/src/native/plugin_logger.dart`** — `setProjectRoot()` now validates that the candidate root contains `pubspec.yaml` before writing the session header or flushing buffered log entries. Prevents log writes into non-project directories (VS Code install dir appeared 1,636 times in the 91-day log).

**`lib/main.dart`** — `Plugin.start()` checks for `pubspec.yaml` in `Directory.current` before calling `loadNativePluginConfig()`. When cwd is not a Dart project, the initial config load is skipped; real config loads lazily from the project root on the first analyzed file via `SaropaContext._ensureConfigLoadedFromProjectRoot()`. `markNativePluginStarted()` is called unconditionally so the essential-tier default is preserved on the lazy reload.

**`lib/src/native/config_loader.dart`** — Added `markNativePluginStarted()` public setter for the `_nativePluginStarted` flag. Updated the stale comment on `loadNativePluginConfig()` to reflect the new dual-set path.

**`lib/saropa_lints.dart`** — Exported `markNativePluginStarted`.

**`lib/src/init/config_writer.dart`** — Added `ensureNonDartExcludes()` which ensures common non-Dart directories (`bugs/**`, `doc/**`, `docs/**`, `output/**`, `plans/**`, `reports/**`, `tmp/**`) are in the `analyzer > exclude` list. Operates on both existing `exclude:` sections and `analyzer:` sections without an exclude. No-op when no `analyzer:` key exists (by design — the init tool does not create that section from scratch).

**`lib/src/init/init_runner.dart`** — Wired `ensureNonDartExcludes()` into the CLI init runner, called after writing the plugins section.

**`lib/src/init/write_config_runner.dart`** — Wired `ensureNonDartExcludes()` into the headless config writer (used by the VS Code extension).

### Bug Report

Updated `bugs/infra_plugin_session_restart_loop_clears_diagnostics.md`:
- Corrected source file references (session log is in `plugin_logger.dart:116`, not `saropa_lint_rule.dart`; register log is in `main.dart:115`)
- Replaced `custom_lint version: ^0.8.0` with `native analysis_server_plugin`
- Rewrote Root Cause section with source-verified analysis and lifecycle trace
- Confirmed Hypothesis B: contacts project `analysis_options.yaml` does NOT exclude `reports/`
- Promoted Hypothesis B from "unlikely" to "likely primary cause"
- Rewrote Suggested Fix section with source-informed mitigations
- Added Changes Made section documenting all code changes
- Updated Related section with full archive paths
- Status set to `Investigating` (verification pending)

### Tests

- `test/native/plugin_logger_test.dart` — 7 tests pass (1 new: `setProjectRoot rejects directories without pubspec.yaml`; 4 existing updated to create `pubspec.yaml` in temp dirs)
- `test/init/ensure_non_dart_excludes_test.dart` — 6 tests pass (new file covering: add to existing excludes, skip already-present, no analyzer section, create exclude section, empty input, partial dedup)
- `test/native/config_loader_project_root_test.dart` — 5 tests pass (unchanged)

### Known Limitations

- `ensureNonDartExcludes` is a no-op when no `analyzer:` key exists in the YAML. This is by design (the init tool manages only the `plugins:` section), but new projects that have never run `dart create` or similar tooling will not get the excludes until they add an `analyzer:` section.
- Flow-style `exclude: [...]` is detected and left unchanged (no insertion attempted). The function does not merge entries into flow-style lists — flow-style is extremely rare in Dart projects.
- The feedback-loop hypothesis (Hypothesis B) still requires verification: adding `reports/**` to the contacts project's `analysis_options.yaml` excludes and observing whether the restart storm stops.
- In a sustained restart storm, `_checkRestartRate` and `_rotateIfNeeded` could theoretically fight: rotation discards old session markers, suppressing the warning. At the 512 KB cap, ~8,700 session headers fit — far above the 10/10min threshold — so this is implausible in practice.

## Finish Report (2026-07-24) — Hardening Pass

### Changes

**`lib/src/init/config_writer.dart`** — `ensureNonDartExcludes()` hardened with three guards: (1) flow-style `exclude: [...]` detection now scoped to the `analyzer:` section body (including blank lines within it) so an unrelated flow-style key under a different top-level section does not trigger the early return; (2) the block-style exclude regex widened from `r'^(\s+exclude:\s*)$'` to `r'^(\s+exclude:\s*)(?:#.*)?$'` so trailing comments after `exclude:` are matched; (3) the analyzer section regex captures blank lines within the section so a visual separator does not terminate the match early and hide a flow-style exclude below it.

**`lib/src/native/plugin_logger.dart`** — Session header string `'--- saropa_lints plugin session started ---'` extracted to `_sessionHeader` constant, shared between `setProjectRoot()` (writer) and `_checkRestartRate()` (reader), eliminating the duplicated literal. `_checkRestartRate()` uses `RegExp.escape(_sessionHeader)` so a future header edit containing regex metacharacters cannot silently break the pattern.

Added `_rotateIfNeeded()` — caps `plugin.log` at 512 KB (`_maxLogFileBytes`) by discarding the oldest bytes at each isolate start. Uses byte-level I/O (`readAsBytesSync` / `writeAsBytesSync`) so the cap is measured in actual file bytes, not Dart string code units. Cuts at a newline boundary (0x0A); when no newline exists after the discard point (single huge line), truncates the file entirely rather than leaving it to grow unbounded. Called before the session header write and before `_checkRestartRate`, so the rate check always sees the rotated content plus the new header.

### Tests

- `test/native/plugin_logger_test.dart` — 14 tests (7 new: restart-rate warning above threshold, below threshold, all-old-entries, corrupted log file, log rotation above cap, single-huge-line truncation; 1 existing: pubspec.yaml rejection; 4 updated for pubspec.yaml in temp dirs; 2 original unchanged).
- `test/init/ensure_non_dart_excludes_test.dart` — 11 tests (5 new: flow-style under analyzer with blank line separator, flow-style under non-analyzer key, flow-style guard, trailing comment, partial dedup).

## Finish Report (2026-07-24) — Log Level and Final Hardening

### Changes

**`lib/src/native/plugin_logger.dart`** — Added `PluginLogLevel` enum (`off`, `error`, `warning`, `info`, `debug`) with `tryParse` for config deserialization. `PluginLogger.log()` now accepts an optional `level` parameter (default: `info`). Messages below `minLevel` are sent to `developer.log` but skip the user-visible log file and memory buffer. Session headers and restart-rate warnings bypass the level check (they use `_appendToFile` directly). `resetForTesting()` resets `minLevel` to `info`. CRLF and UTF-8 safety of `_rotateIfNeeded` documented in comments (0x0A cannot appear as a UTF-8 continuation byte; CRLF `\r\n` places `0x0D` before `0x0A` so cutting after `0x0A` never orphans `\r`).

**`lib/src/native/config_loader.dart`** — Added `_loadLogLevel(content)` which parses `log_level:` under `plugins > saropa_lints` in `analysis_options.yaml`. Scoped to the `saropa_lints:` section body to avoid matching a `log_level:` key under an unrelated top-level section. Called before the `diagnostics:` section check so a valid `log_level:` setting is honored even when the `diagnostics:` block is absent. Two catch blocks (`loadNativePluginConfig failed`, `_readProjectFile failed`) tagged with `level: PluginLogLevel.error`.

**`lib/src/init/config_writer.dart`** — `generatePluginsYaml` now emits `log_level: info` after `version:`, so all new and regenerated configs include the setting with a comment listing valid values.

### Tests

- `test/native/plugin_logger_test.dart` — 19 tests total. New: 3 `PluginLogLevel.tryParse` tests (valid names, case-insensitive, invalid input), 2 level-filtering tests (error-only filter, off suppresses all), 1 CRLF rotation test.
- `test/init/write_config_test.dart` — existing test extended with `log_level: info` assertion.
- `test/native/config_loader_project_root_test.dart` — 5 tests pass (unchanged).

## Finish Report (2026-07-24) — Convenience API and Log-Level Hardening

### Changes

**`lib/src/native/plugin_logger.dart`** — Added `debug()`, `warning()`, and `error()` convenience methods wrapping `log()` with the corresponding `PluginLogLevel`. The `error()` method preserves the `error` and `stackTrace` parameters. The underlying `log()` method and its `level:` named parameter remain available for edge cases.

**`lib/src/native/config_loader.dart`** — `_loadLogLevel` regex broadened from `r'^    log_level:\s*(\S+)'` (4-space only) to `r'^[ \t]+log_level:\s*(\S+)'` so tab-indented configs are parsed. When `PluginLogLevel.tryParse` returns null for a non-empty `log_level:` value, a warning is logged naming the unrecognized value and the retained level (previously silent fallback). Warning text uses the live `minLevel.name` rather than hardcoding "info" so it remains accurate on config reloads within the same isolate. All `PluginLogger.log(..., level: PluginLogLevel.error/warning)` calls replaced with `.error()` / `.warning()`. Two config-missing messages (`analysis_options.yaml not found`, `no diagnostics block`) retagged from `.log()` to `.warning()`. Three error catch blocks retagged from `.log()` to `.error()`.

**`lib/main.dart`** — Two error catch blocks retagged to `.error()`. The "cwd is not a Dart project" startup message retagged from `.log()` (info) to `.debug()` — it is noisy startup telemetry, not user-actionable.

**`lib/saropa_lints.dart`** — `registerSaropaLintRules` catch block retagged to `.error()`. Unknown rule-reference log retagged to `.warning()`.

**`lib/src/config/runtime_tier_cap.dart`** — Invalid `SAROPA_TIER` env value retagged to `.warning()`. File-read catch block retagged to `.error()`.

### Tests

- `test/native/plugin_logger_test.dart` — 19 tests pass (unchanged).
- `test/native/config_loader_project_root_test.dart` — 8 tests total (3 new): `log_level is honored even without a diagnostics block` verifies `_loadLogLevel` runs before the diagnostics-section early return; `unrecognized log_level logs a warning and keeps default` verifies both the warning text and that `minLevel` stays at `info`; `tab-indented log_level is parsed correctly` verifies tab indentation is accepted.

### Known Limitations

- `_loadLogLevel` matches `log_level:` in the substring after the `saropa_lints:` key through end-of-file, not bounded to the `saropa_lints:` block's indentation extent. A `log_level:` key under a later, unrelated plugin section could be picked up. This is a pre-existing scope issue (present since the scoped-to-saropa_lints change), not introduced by this diff. Follow-up: bound the match to the next unindented or less-indented line.
