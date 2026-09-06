# BUG: Hard RSS valve pauses rules based on analysis server memory, not plugin memory

**Status: Fixed**

Created: 2026-09-05
Rule: N/A (infrastructure — `MemoryPressureHandler` hard RSS valve)
File: `lib/src/project_context_throttle_memory.dart` (line ~1200)
Severity: High
Since: memory monitor phase 0 (2026-09)

---

## Summary

The hard RSS safety valve reads `ProcessInfo.currentRss` — the **entire analysis
server process** RSS — and pauses all saropa_lints rule execution when that
crosses the cap (default: adaptive 60% of system RAM, ~4096–8192 MB). On large
projects the analysis server's own resolved-element model, AST caches, and
cross-library type graph consume the vast majority of that RSS. The plugin is
pausing its own rules in response to memory it did not allocate and cannot
reclaim.

Observed in VS Code status bar: `Rules paused (8425 MB)`. The plugin's own
estimated cache footprint (`_estimateMemoryUsageMb`) is a small fraction of
that figure. The valve trips because the analysis server's heap grew, not
because the plugin's caches did.

---

## Attribution Evidence

Not a rule bug — infrastructure in `project_context_throttle_memory.dart`.

```
lib/src/project_context_throttle_memory.dart:1200  isOverHardLimit
lib/src/project_context_throttle_memory.dart:1213  _refreshHardLimit
lib/src/project_context_throttle_memory.dart:1251  hard-limit trip branch
```

---

## Reproducer

1. Open a large Flutter project (~1500+ Dart files) in VS Code.
2. Let the analysis server fully resolve the project.
3. Observe the analysis server process RSS climb past the adaptive cap
   (e.g. 8425 MB on a 16 GB machine with cap at ~8192 MB).
4. Status bar shows `Rules paused (8425 MB)` — all saropa_lints diagnostics
   disappear.
5. The plugin's own `_estimateMemoryUsageMb` reports tens of MB at most.

**Frequency:** Reproducible on any project large enough to push the analysis
server past the RSS cap. The larger the project, the more likely the server's
own memory trips the valve regardless of plugin cache size.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | The valve should measure the plugin's OWN memory contribution and pause rules only when the plugin is the dominant consumer. The analysis server's baseline memory is not the plugin's responsibility. |
| **Actual** | `ProcessInfo.currentRss` measures the entire process. The plugin pauses rules when the server's own model grows large, even if the plugin's caches are nearly empty. |

---

## Root Cause

`isOverHardLimit` (line ~1200) calls `_refreshHardLimit` which calls
`_currentRssMb()` → `ProcessInfo.currentRss ~/ (1 << 20)`. This is the
process-wide resident set size. In the LSP/analysis-server context, the plugin
runs in-process as a native analyzer plugin — it shares the same heap as the
analysis server. The server's resolved element model, AST node caches, and
cross-library type resolution data structures are the dominant consumers
(typically 70–90% of RSS on large projects). The plugin cannot distinguish its
own allocations from the server's.

The soft relief path (`_estimateMemoryUsageMb`) already estimates plugin-only
cache sizes. The hard valve ignores that estimate and uses raw RSS instead.

### The fundamental problem

There is no Dart API to measure per-isolate or per-library memory. The plugin
cannot know how much of the process RSS belongs to it vs the analysis server.
The current approach assumes the plugin is the marginal consumer — a reasonable
assumption when the analysis server is well under the cap and the plugin pushes
it over, but wrong when the server is already at the cap before rules even run.

---

## Options to consider

### Option A: Delta-based valve

Measure RSS at plugin startup (before any caches are populated). Trip the valve
only when `currentRss - baselineRss` exceeds a plugin-specific cap. This
isolates the plugin's marginal contribution. Risk: the baseline is a snapshot;
the server continues allocating after startup, so the delta includes some
server-side growth.

### Option B: Use the plugin's own estimate as the primary signal

`_estimateMemoryUsageMb` already tracks plugin-owned cache sizes. Use that
as the primary valve signal instead of process RSS. Fall back to process RSS
only as a last-resort kill switch at a much higher threshold (e.g. 90% of
system RAM) to prevent actual OOM.

### Option C: Proportional valve

Compare `_estimateMemoryUsageMb` against process RSS. Only trip the valve when
the plugin's estimated footprint is a significant fraction (e.g. >20%) of
total RSS. If the plugin is <5% of RSS, pausing rules won't meaningfully
reduce memory pressure.

### Option D: Raise the hard cap floor

The current adaptive cap (60% of system RAM) is too aggressive for a plugin
that shares a process with the analysis server. On a 16 GB machine, the cap
is ~9.8 GB (clamped to 8192 MB) — but the analysis server routinely uses
6–8 GB on large projects before the plugin even loads. Raising the floor
or percentage would delay the trip but not fix the attribution problem.

---

## Environment

- saropa_lints version: current (v6/10 per status bar)
- Dart SDK version: 3.x (current stable)
- Platform: Windows 11, 16 GB RAM
- Triggering project: d:\src\contacts (~1500+ Dart files)
- Observed RSS at trip: 8425 MB
- Plugin estimated cache size at trip: not captured (but historically <100 MB)

---

## Finish Report (2026-09-05)

**Defect:** The hard RSS safety valve in `MemoryPressureHandler._refreshHardLimit()` read `ProcessInfo.currentRss` — the entire analysis server process RSS — and paused all saropa_lints rule execution when that crossed the adaptive cap. On large projects (1500+ files), the analysis server's own resolved-element model, AST caches, and cross-library type graph consume 70–90% of process RSS. The plugin's own estimated cache footprint was typically under 100 MB. The valve was pausing rules in response to memory the plugin did not allocate and could not reclaim.

**Fix (Option C — proportional valve with panic fallback):**

1. **Attribution check** in `_refreshHardLimit`: when RSS crosses `_hardLimitMb`, the valve now calls `_estimateMemoryUsageMb()` and only trips if the plugin's footprint is ≥ 100 MB (`_minPluginContributionMb`) or ≥ 5% of process RSS (`_minPluginContributionPct`). If below both thresholds, the valve logs a one-time attribution-skip message and keeps rules running.

2. **Panic threshold** (`_panicRssLimitMb`): set to 90% of system RAM at startup. Trips unconditionally regardless of attribution — at that RSS the OS will OOM-kill the process, so any shedding is better than crashing.

3. **Baseline RSS** (`_baselineRssMb`): recorded at startup before caches are populated, for diagnostics and future attribution refinements.

4. **Enhanced logging**: periodic trend log now includes the plugin's estimated footprint (`plugin ~NMB`). The trip message names the reason (plugin footprint or OOM panic). A new attribution-skip log entry explains when and why the valve stayed open despite RSS exceeding the cap.

5. **Test reset**: `resetShedStateForTesting()` clears the new fields so tests start clean.

**Files changed:**
- `lib/src/project_context_throttle_memory.dart` — attribution check in `_refreshHardLimit`, new fields (`_baselineRssMb`, `_panicRssLimitMb`, `_minPluginContributionMb`, `_minPluginContributionPct`, `_loggedAttributionSkip`), updated `getStats()`, `initializeCacheManagement()`, `resetShedStateForTesting()`
- `CHANGELOG.md` — new Fixed entry
- `bugs/infra_hard_rss_valve_penalizes_plugin_for_server_memory.md` — Status: Fixed, archived to `plans/history/2026.09/2026.09.05/`

**Tests:** 17/17 memory eviction tests pass. Existing tests use `setHardLimitTrippedForTest()` which directly sets the flag, unaffected by the attribution logic. The attribution path depends on `ProcessInfo.currentRss` and cannot be unit-tested without controlling real process RSS.

**Hardening (post-reflection):**

6. **Cached RAM detection**: `_totalPhysicalMemoryMb()` — which shells out to PowerShell/wmic on Windows — was called twice during `initializeCacheManagement` (once for adaptive cap, once for panic threshold). The result is now cached in a local and passed to `_computeAdaptiveRssCap` via a named `ramMb` parameter, eliminating the redundant subprocess spawn.

7. **Estimator guard**: Added a DartDoc warning on `_estimateMemoryUsageMb()` documenting that new caches MUST be accounted for there or via `registerEstimator()`, since the hard valve's attribution check relies on the estimate's accuracy.

8. **Debug memory mode**: Added `SAROPA_LINTS_DEBUG_MEMORY=1` env var support. When enabled, every periodic trend line additionally logs a per-cache size breakdown (KB per cache), making it straightforward to diagnose which caches are growing under memory pressure. Implemented as `_logCacheBreakdown()` gated on a `_debugMemory` flag read once at class load time.
