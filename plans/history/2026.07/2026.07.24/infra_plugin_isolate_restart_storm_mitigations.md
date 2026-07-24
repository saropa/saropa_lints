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
- `_checkRestartRate` reads the entire log file on every isolate start. No log rotation exists, so in a sustained restart storm the read cost is linear per spawn and cumulative quadratic over the storm's duration. A follow-up adding log rotation or windowed reads (last N KB) would cap this cost.

## Finish Report (2026-07-24) — Hardening Pass

### Changes

**`lib/src/init/config_writer.dart`** — `ensureNonDartExcludes()` hardened with two guards: (1) an early-return when flow-style `exclude: [...]` is detected, preventing insertion of a duplicate `exclude:` YAML key that would produce invalid YAML; (2) the block-style exclude regex widened from `r'^(\s+exclude:\s*)$'` to `r'^(\s+exclude:\s*)(?:#.*)?$'` so trailing comments after `exclude:` (e.g. `exclude: # my excludes`) are matched instead of falling through to the "create exclude section" branch.

**`lib/src/native/plugin_logger.dart`** — Added `_checkRestartRate()`, called after writing the session header in `setProjectRoot()`. Reads the existing log file, counts "session started" entries whose timestamps fall within the last 10 minutes, and emits a `WARNING` line when the count reaches 10 or more. The warning includes remediation advice (check `analysis_options.yaml` excludes for non-Dart directories). Statics reset per isolate, so the log file itself serves as the durable cross-isolate counter. The method is wrapped in `on Object catch` to maintain the "never crash the plugin" contract.

### Tests

- `test/native/plugin_logger_test.dart` — 9 tests (2 new: `emits restart-rate warning when threshold exceeded` seeds 12 recent session headers and asserts the WARNING line appears; `no restart-rate warning when below threshold` seeds 3 recent sessions and asserts no WARNING).
- `test/init/ensure_non_dart_excludes_test.dart` — 8 tests (2 new: `leaves flow-style exclude unchanged` asserts input returned verbatim; `handles trailing comment after exclude:` asserts entries are inserted below the commented exclude line).
