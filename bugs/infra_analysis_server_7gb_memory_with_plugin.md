# BUG: Infrastructure — Dart analysis server consumes 7.8 GB with saropa_lints plugin

**Status: Open — Root cause identified**

Created: 2026-08-07
Rule: N/A (infrastructure / performance — affects the plugin as a whole)
File: N/A
Severity: Critical (OOM crashes)
Rule version: N/A | Since: unknown | Updated: 2026-08-07

---

## Summary

The Dart language server (`dart language-server --protocol=lsp`) grows to
7.8 GB resident memory when analyzing the `contacts` project (~3,900 Dart
files) with the `saropa_lints` analyzer plugin loaded. This is the single
largest memory consumer on the system and contributes to OOM crashes that
kill the VS Code extension host.

---

## Attribution Evidence

saropa_lints is loaded via `pubspec.yaml` as `saropa_lints: ^14.4.3`.
The `analysis_options.yaml` plugin block references version `"14.3.13"`
(out of sync with pubspec). The `custom_lint.log` shows repeated
`PLUGIN_ERROR` / `"Invalid overlay change: no content to change"` errors.
custom_lint is NOT in pubspec.lock (commented out) — the plugin runs on the
native analyzer plugin API.

---

## Root Cause Analysis

**Confirmed: ~70 static unbounded caches in the plugin, most keyed by file
path, with only 10 of them registered for eviction.**

### Finding 1: Massive O(n×m) cache — `FileContentCache._passedRules`

`lib/src/project_context_project_file.dart:548` stores a `Set<String>` of
passed rule names **per file**. With "recommended" tier (790 rules) and
3,900 files, this creates up to 790 × 3,900 = ~3.1M set entries. The
memory estimator (`_estimateMemoryUsageMb`) values this at "~1KB per file"
(3.9 MB total) — a ~25× underestimate.

### Finding 2: ~60 unregistered static caches

Only 10 caches are registered with `MemoryPressureHandler` for eviction.
The remaining ~60 static `Map`/`Set`/`List` collections grow unbounded:

| Category | Files | Key caches (all per-file) |
|----------|-------|--------------------------|
| ProgressTracker | saropa_lint_rule.dart:212-250 | `_seenFiles`, `_issuesByFile`, `_issuesByFileBySeverity`, `_issuesByFileByRule`, `_fileViolationKeys`, `_slowFiles` |
| ImpactTracker | saropa_lint_rule.dart:1740 | 3 `Set<ViolationRecord>` (5 strings each per violation) |
| RulePerformance | saropa_lint_rule.dart:1139-1146 | `_totalTime`, `_callCount`, `_slowRules`, `_slowExecutionCount` |
| ReAnalysis | saropa_lint_rule.dart:2843-2910 | `_recentAnalysis`, `_fileEditHistory`, `_lastPassUnitId`, `_fileRapidMode` |
| BaselineManager | baseline_manager.dart:56 | `_dateCache` (Map file → Map line → bool) |
| BaselineDate | baseline_date.dart:43 | `_cache` (Map file → FileDateCache) |
| IncrementalPriority | project_context_incremental_priority.dart:36 | `_state` (per-file analysis state) |
| ParallelBatch | project_context_parallel_batch.dart:148,666 | `_resultCache`, `_fileToApplicableRules` |
| DispatchBaseline | project_context_dispatch_baseline.dart:140-264 | `_fullyBaselinedRules`, `_baselinedViolationCounts`, `_changedRegions`, `_previousContent` |
| Throttle/Memory | project_context_throttle_memory.dart:15-180 | `_lastEdit`, `_lastAnalysis`, `_associations`, `_openHistory`, `_activeGroups` |
| Profiling | project_context_throttle_memory.dart:635 | `_measurements` (List per rule) |
| AstViolations | project_context_ast_violations.dart:120,206,307,362 | `_pending`, `_cache`, `_dependents`, `_dependencies`, `_stats` |
| PathBloomGit | project_context_path_bloom_git.dart:181-184 | `_modifiedFiles`, `_stagedFiles` |
| RuntimeTierCap | config/runtime_tier_cap.dart:157 | `_allowedCache` |
| AndroidManifest | android_manifest_utils.dart:22 | `_cache` |
| InfoPlist | info_plist_utils.dart:45 | `_cache` |

### Finding 3: Hard RSS valve may be inert on Windows

The valve (`_hardLimitMb = 6144`) uses `ProcessInfo.currentRss`. If this
returns -1 on Windows (catch-all in `_currentRssMb()`), the valve never
trips and the 7.8 GB growth continues unchecked. Even if it does trip at
6 GB, it only pauses rule execution — it does NOT release the analyzer's
own resolved element model, which is the bulk of the memory.

### Finding 4: Double rule instantiation at startup

`_buildRuleFactoriesMap()` (line 3317) instantiates all 2,342 rules to
extract names, then `registerSaropaLintRules` (line 3407) instantiates
them all again. Fixed cost (~5-10 MB), not the main driver.

### Finding 5: `_previousContent` stores full file source text

`project_context_dispatch_baseline.dart:264` — `Map<String, String>`
keyed by file path, storing the **entire previous source content**. For
3,900 Dart files averaging ~5 KB each, this is ~19.5 MB of retained source
text that is never evicted.

---

## Reproducer

1. Open `D:\src\contacts` in VS Code with the Dart extension.
2. Wait for analysis to complete (~3,900 files).
3. Observe the `dart.exe language-server` process in Task Manager.

```
PID 8884: 7,796 MB working set
Started: 8/7/2026 11:28:41 AM
Command: dart.exe language-server --protocol=lsp --client-id=VS-Code ...
```

**Control experiment still needed:** measure memory with and without the
plugin to determine what fraction of the 7.8 GB is plugin caches vs the
analyzer's own resolved model.

**Frequency:** Always (observed across multiple sessions)

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Analysis server stays under ~2 GB for a 3,900-file project |
| **Actual** | 7.8 GB resident memory, contributing to system OOM |

---

## Fix Plan

### Phase 1: Immediate — register all caches for eviction

1. Add `clearCache` static methods to every class with static collections
   listed above (ProgressTracker, ImpactTracker, etc.)
2. Register them all in `initializeCacheManagement()`
3. Fix the memory estimator to account for actual `_passedRules` size
   (per-file set cardinality, not flat 1KB)

### Phase 2: Cap unbounded caches

4. Add LRU eviction to `FileContentCache._passedRules` — cap at N files
   (e.g., 500), evict oldest. The rule-skip optimization is a nice-to-have,
   not a correctness requirement.
5. Add LRU eviction to `_previousContent` — cap at ~100 files, this stores
   full source text.
6. Cap ProgressTracker maps — summary data for 3,900 files is pure waste
   after analysis completes.

### Phase 3: Verify Windows RSS valve

7. Add a startup log line that prints `ProcessInfo.currentRss` to confirm
   it works on Windows. If it returns -1, implement a fallback via
   `Process.run('tasklist', ...)` or similar.

### Phase 4: Control experiment

8. Measure memory with plugin removed to separate plugin contribution from
   analyzer baseline. Results determine whether to file upstream.

---

## Environment

- saropa_lints version: 14.4.3 (pubspec), 14.3.13 (analysis_options — stale)
- Dart SDK version: 3.12.2 (stable)
- custom_lint: NOT loaded (commented out in pubspec.yaml)
- Plugin API: native analyzer plugin
- Triggering project: `D:\src\contacts` (~3,900 Dart files, 11 GB total)
- Tier: recommended (790 of 2,342 rules)
- OS: Windows 11 Pro, 32 GB RAM
- VS Code with Dart extension
