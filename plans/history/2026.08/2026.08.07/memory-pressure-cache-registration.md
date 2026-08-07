# Memory Pressure: Register Unbounded Caches for Eviction

The saropa_lints analyzer plugin maintained ~70 static `Map`/`Set`/`List` caches keyed by file path, but only 10 were registered with `MemoryPressureHandler` for eviction under memory pressure. On a 3,900-file project, this caused the analysis server to grow to 7.8 GB resident memory with no relief path.

## Finish Report (2026-08-07)

### Root Cause

Investigation of `bugs/infra_analysis_server_7gb_memory_with_plugin.md` identified three contributing factors:

1. **~60 unregistered static caches**: `DiffBasedAnalysis._previousContent` (full source text per file), `IncrementalAnalysisTracker._state`, `ParallelAnalyzer._resultCache`, `BaselineAwareEarlyExit._fullyBaselinedRules`, and ~15 other per-file maps in `project_context_*.dart` and `saropa_lint_rule.dart` — all grow linearly with file count and are never evicted.

2. **Memory estimator 25x underestimate**: `FileContentCache._passedRules` stores a `Set<String>` per file (one entry per rule that passed). With 790 rules x 3,900 files = ~3.1M set entries (~150 MB), but the estimator valued it at 1 KB/file (~3.9 MB).

3. **Priority semantics**: `relieve(clearAll: false)` clears caches with `priority >= 50`, contrary to the "lower = clear first" comment. New registrations assign >= 50 to large per-file caches and < 50 to small stats or expensive-to-rebuild registries.

### Changes

- **`lib/src/config/runtime_tier_cap.dart`**: Added `clearCache()` static method (the only cache class that lacked one).

- **`lib/src/project_context_throttle_memory.dart`**: Registered 15 caches in `initializeCacheManagement()` with priorities aligned to the actual `>= 50` soft-relief threshold. Rewrote the memory estimator to iterate `FileContentCache._passedRules` set cardinality per file, measure `DiffBasedAnalysis._previousContent` string lengths, and account for `IncrementalAnalysisTracker`, `ParallelAnalyzer`, and `HotPathProfiler` sizes. Added automatic cache stats logging to `relieve()` (names of cleared caches, estimated plugin usage, process RSS). Added `processRssMb`, `rssAvailable`, `hardLimitMb`, `hardLimitTripped` to `getStats()`. Fixed stale "low priority = clear first" comment to match actual `>= 50` behavior.

- **`lib/main.dart`**: Registered 3 caches from cross-library sources (`RuleTimingTracker`, `BaselineDate`, `RuntimeTierCap`) that are not reachable from the `project_context` library. Documented why `ProgressTracker`, `ImpactTracker`, `ReportWriter`, `SuppressionTracker`, and `BaselineManager` are explicitly NOT registered (session accumulators / destructive reset).

- **`lib/src/saropa_lint_rule.dart`**: Added MEMORY section to the analysis summary (`reportSummary`) showing estimated plugin cache usage, process RSS (color-coded: red > 4 GB, yellow > 2 GB), and cache eviction count.

- **Startup diagnostic**: `initializeCacheManagement()` now logs whether `ProcessInfo.currentRss` is available on the current platform. If unavailable, emits a WARNING that the hard RSS safety valve is inert.

### Excluded from Eviction (Intentional)

- **ProgressTracker, ImpactTracker, ReportWriter, SuppressionTracker**: Forward-accumulating session counters. Clearing mid-session silently truncates analysis summary data.
- **BaselineManager**: `reset()` nulls `_config` with no lazy re-init path, permanently disabling baseline suppression.

### Not Fixed (Separate Scope)

- Pre-existing priority inversion in `relieve()` — the comment said "low = clear first" but the code does `priority >= 50`. Comment corrected; priorities assigned to match actual code behavior.
- Control experiment (memory with vs without plugin) not yet performed (Phase 4 in bug report).
- LRU eviction for `FileContentCache._passedRules` (Phase 2 in bug report).
- `AstNodeTypeRegistry` appears to be dead infrastructure (no `register`/`add` call sites found in `lib/`) — not cleaned up in this change.

### Verification

- `dart analyze` on changed files: 0 issues.
- `test/config/runtime_tier_cap_test.dart`: 8/8 passed.
- No existing test assertions broken (confirmed by grep + inspection of 4 matching test files).
