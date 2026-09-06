# BUG: RSS valve attribution check leaves rules paused forever and re-walks caches on every bystander sample

**Status: Open**

Created: 2026-09-05
Rule: N/A (infrastructure — `MemoryPressureHandler` hard RSS valve)
File: `lib/src/project_context_throttle_memory.dart`
Severity: High
Introduced by: commit `e0f0b0bc` "fix: hard RSS valve now checks plugin attribution before pausing rules"

---

## Summary

The attribution fix in `e0f0b0bc` correctly stops the plugin pausing its rules
for memory the analysis server allocated. Three defects in that change were
found by review before release. All three are in the unreleased commit, so
none has shipped.

The fix introduced a "bystander" state: process RSS is over the hard cap, but
the plugin's own estimated footprint is small enough that the plugin is not
the cause. That state is entered correctly and never leaves correctly.

---

## Defect 1: bystander state re-walks every cache on every sample

`lib/src/project_context_throttle_memory.dart:1309`

In the bystander case nothing latches. The guard
`!_hardLimitTripped && rss >= _hardLimitMb` therefore stays true, so
`_estimateMemoryUsageMb()` runs again on the next sample, and the next, for as
long as the analysis server sits above the cap.

`_estimateMemoryUsageMb()` is not cheap. It walks `StringInterner._pool` and
every cache map to sum entry counts. The sampling interval is every 200 rule
callbacks, so on a large project this becomes a permanent background cost
during exactly the condition the fix was written for: a big server heap with a
small plugin. The fix intended to make the common case free and instead made
it the most expensive path.

**Fix:** latch the bystander decision the same way a trip latches. Re-evaluate
on a coarse timer or after the plugin's own estimate grows by a meaningful
delta, not on every sample.

## Defect 2: a legitimate trip can never release

`lib/src/project_context_throttle_memory.dart:1341`

Attribution is consulted only when deciding to trip. Release is tested against
process RSS alone.

That is self-defeating in sequence. A genuine trip fires `relieve(clearAll:
true)`, which drops the plugin's caches and therefore makes the plugin a
bystander by the fix's own definition. Release then waits for process RSS to
fall below the cap — but that RSS is the analysis server's, and clearing the
plugin's caches barely moves it. Rules stay paused indefinitely, which is the
original symptom the attribution work set out to eliminate, now reached by a
different route.

**Fix:** apply the same attribution test on the release path. When the plugin
is no longer a meaningful contributor, resume rules regardless of process RSS,
except under the panic threshold.

## Defect 3: the memory probe re-spawns when detection failed

`lib/src/project_context_throttle_memory.dart:1922`

`ramMb > 0 ? ramMb : _totalPhysicalMemoryMb()` re-runs the PowerShell/wmic
probe every time the caller's detection returned 0. The caching this line
documents therefore does not hold in the one case that matters, and the
failure case is the expensive one — spawning a process per call.

**Fix:** cache the failure as well as the success, or resolve the value once at
initialization and treat 0 as a terminal "unknown" that selects a documented
default cap.

---

## Attribution Evidence

Found by code review of `e0f0b0bc` against the working tree on 2026-09-05.
Not observed in a running editor; no reproducer is recorded here because the
first two defects are state-machine reasoning over the trip and release paths
rather than an observed failure.

## Related

- `plans/history/2026.09/2026.09.05/infra_hard_rss_valve_penalizes_plugin_for_server_memory.md`
  — the original attribution bug these defects were introduced while fixing.
- `bugs/infra_extension_shows_stale_memory_state_when_plugin_disabled.md`
  — the extension side renders this state without checking it is live.
- `bugs/analysis_rss_valve_is_measuring_the_wrong_thing.md` — the design
  analysis behind the attribution work.
