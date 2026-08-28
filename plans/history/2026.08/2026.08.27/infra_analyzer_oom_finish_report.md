# OOM Crash on Large Projects — Finish Report

The in-process analyzer plugin crashed the Dart analysis server via OOM on projects with 4000+ Dart files because forward-accumulating trackers (violation records, suppression records, per-file maps) were never evicted under memory pressure, the hard RSS safety valve defaulted to 6 GB (above the analysis server's typical heap limit), and violation/suppression tracking continued even after the valve tripped.

## Finish Report (2026-08-27)

### Changes Made

Five mitigations were implemented, all in the plugin's infrastructure layer (no rule logic changed):

1. **Tracker eviction registration** (`lib/main.dart`): `ImpactTracker.reset`, `SuppressionTracker.reset`, and `ProgressTracker.releasePerFileMaps` are now registered with `MemoryPressureHandler` at priority < 50 (hard-relief only). A truncated analysis summary is acceptable when the alternative is an OOM crash. `ProgressTracker.releasePerFileMaps` was renamed from `_releasePerFileMaps` (private→public) to enable external invocation.

2. **Accumulation guard** (`lib/src/saropa_lint_rule.dart`): `_trackViolation` and `_trackSuppression` in `SaropaDiagnosticReporter` now bail early when `MemoryPressureHandler.isOverHardLimit` is true, preventing re-filling trackers that were just cleared during hard relief.

3. **RSS cap reduction** (`lib/src/project_context_throttle_memory.dart`): Default `hardRssLimitMb` lowered from 6144 to 4096. The Dart analysis server's typical heap on 64-bit is ~4 GB; the previous 6 GB cap let the process OOM before the valve could trip. Still overridable via `SAROPA_LINTS_MAX_RSS_MB`.

4. **Large-project warning** (`lib/src/saropa_lint_rule.dart`): `ProgressTracker.discoverFiles()` now emits a stderr warning when the project exceeds 2000 Dart files, advising verification of `lane: light` and the VS Code extension scan-on-save alternative.

5. **Memory estimate expansion** (`lib/src/project_context_throttle_memory.dart`, `lib/main.dart`): Added `estimatedBytes` getters to `ImpactTracker` and `SuppressionTracker`, a `registerEstimator`/`clearEstimators` API on `MemoryPressureHandler`, and wired the tracker footprints into the soft-relief memory estimate. `clearEstimators()` guards against duplicate registration if `Plugin.start()` re-enters.

### Exports Added

`ProgressTracker` and `SuppressionTracker` are now exported from `lib/saropa_lints.dart` so `lib/main.dart` can reference them.

### Tests Added

`test/report/memory_eviction_test.dart` — 8 tests covering `ImpactTracker.estimatedBytes`, `SuppressionTracker.estimatedBytes`, and `ProgressTracker.releasePerFileMaps` public API (zero/populated/reset/dedup/no-throw).

### Hardening Pass

Three additional improvements were applied after the initial review:

6. **Named estimator registration** (`lib/src/project_context_throttle_memory.dart`): `registerEstimator` now takes a name key (map-based) instead of appending to a list. Idempotent: re-registering the same name replaces the previous callback, eliminating the duplicate-estimator risk if `Plugin.start()` re-enters. `clearEstimators()` removed — no longer needed.

7. **Adaptive RSS cap** (`lib/src/project_context_throttle_memory.dart`): The hard RSS cap now adapts to system RAM when detectable. `_totalPhysicalMemoryMb()` reads physical RAM via platform-specific commands (Windows `wmic`, Linux `/proc/meminfo`, macOS `sysctl`). `_computeAdaptiveRssCap()` sets the cap to 60% of physical RAM, clamped to [2048, 4096]. Falls back to the 4096 MB default on systems with <4 GB RAM or when detection fails. The startup diagnostic now logs the cap source (env / adaptive / default).

8. **Doc comment fix** (`lib/src/saropa_lint_rule.dart`): `_largeProjectThreshold` field's doc comment was misattached to `discoverFiles()`'s dartdoc — split into its own doc block.

### What This Does NOT Fix

- The analyzer's own resolved element/AST model remains the dominant memory cost on `lane: full`. Only `lane: light` (the default) avoids that cost entirely.
- Upgrading to `analyzer ^13` is blocked by the `meta` version constraint; tracked on the `analyzer-13-migration` branch.

### Verification

- `dart analyze` on all 4 changed Dart files: 0 errors, 1 pre-existing INFO (curly braces style).
- `dart test test/report/memory_eviction_test.dart`: 8/8 passed.
- Full OOM verification requires testing on the Saropa Contacts project (~4335 files) with the plugin active.
