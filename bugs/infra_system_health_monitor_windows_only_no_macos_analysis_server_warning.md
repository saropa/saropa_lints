# BUG: System Health monitor is Windows-only — a 6.7 GB analysis server on an 8 GB Mac raises no warning

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-18
Rule: n/a (extension-native check: System Health / Process Monitor)
File: `extension/src/systemHealth/processMonitor.ts` (line ~209)
Severity: False negative (High): the memory-safety feature is silent on macOS and Linux
Rule version: n/a | Since: deliberate deferral, `PLAN_memory_stability_features.md` (2026-09-07) | Updated: 16.4.1

---

## Summary

`ProcessMonitor.start()` returns immediately on any platform other than `win32`. Every data source under it (`queryDartProcesses`, `querySystemMemory`) also returns empty or `undefined` off Windows. So on macOS the analysis-server size warning (`analysisServerWarningGB`, default 4), the saropa RSS warning and critical notifications, the low-free-RAM warning, and the Machine Dashboard **never run**. Expected: the same warnings on macOS and Linux, driven by `ps` / `vm_stat` / `sysctl` (or `/proc`) instead of CIM.

---

## Attribution Evidence

Extension-native check, so the grep root is `extension/src/` (see "Rule Sources" in `ISSUE_REPORT_GUIDE.md`).

```bash
grep -rn "process.platform !== 'win32'" extension/src/systemHealth/
# extension/src/systemHealth/processMonitor.ts:209   if (!config.enabled || process.platform !== 'win32') return;
# extension/src/systemHealth/processQuery.ts:113     if (process.platform !== 'win32') { return Promise.resolve([]); }
# extension/src/systemHealth/systemQuery.ts:33       if (process.platform !== 'win32') return Promise.resolve(undefined);
# extension/src/systemHealth/machineDashboard.ts:45  (shows 'machineDashboard.platformUnsupported')
# extension/src/systemHealth/machineDashboard.ts:95
# extension/src/systemHealth/healthPanel.ts:212, :224
# extension/src/systemHealth/orphanHosts.ts:220, :238
# extension/src/systemHealth/orphanPreflight.ts:167
```

**Emitter registration:** `new ProcessMonitor()` / `processMonitor.start()` at `extension/src/extension.ts:1610` and `:1624`
**Diagnostic surface:** `vscode.window.showWarningMessage`, not a Problems-panel diagnostic

---

## Reproducer

Not a Dart snippet; this is workspace and machine state.

1. On macOS, install saropa-lints 16.4.1 with `saropaLints.systemHealth.enabled` left at its default.
2. Open a large Flutter workspace, then add a few nested package copies to push the analysis server past 4 GB (for example `git worktree add .claude/worktrees/a HEAD`, repeated). See the companion report `infra_exclusion_audits_miss_claude_worktrees_nested_package_roots.md`.
3. Wait past several poll intervals.

**Observed on 2026-09-18** (`saropa_contacts`, macOS 26.6.2, Apple silicon, 8 GB):

| `top -l 1 -o mem` | |
|---|---|
| PID 1432 `dart language-server --protocol=lsp --client-id=VS-Code` (`--old_gen_heap_size=6144`) | **6726 MB** |
| Free physical memory, no tests running | 1.2–1.9 GB of 8.0 GB |

No saropa-lints notification, status-bar change or dashboard data appeared. Every `flutter test` hung at "loading" for lack of memory, and the cause was found by hand.

**Frequency:** Always, on every non-Windows platform.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `systemHealth.notification.analysisServerLarge` fires (6.7 GB ≥ 4 GB) with "Restart analysis server" (the only action `checkAnalysisServerSize` offers, `processMonitor.ts:381`); separately, the low-memory warning fires only if free RAM drops below the configured `systemMemoryWarningPercent` (default 15 — `freePercent >= 15 → no warning`). The observed 1.2–1.9 GB free on an 8 GB machine is 15–24%, i.e. at or above the default threshold, so it would *not* have fired here at defaults. The macOS "free" definition matters too: `vm_stat`'s free+inactive+speculative reads higher than what `top`'s "unused" figure suggests, so the same machine can look more pressured in `top` than the configured check would treat it. |
| **Actual** | `start()` returns at `processMonitor.ts:209`; nothing polls, and nothing is shown |

---

## AST Context

`SKIPPED`: extension-native TypeScript, no Dart AST involved. The equivalent control flow:

```
extension.ts:1624  processMonitor.start()
  └─ processMonitor.ts:209  process.platform !== 'win32' → return   ← exits here on darwin/linux
      (never reached) poll() → queryDartProcesses() → checkAnalysisServerSize() :381
```

---

## Root Cause

### The data layer is CIM-only by design, and the platform gate is a direct consequence

`PLAN_memory_stability_features.md` (history 2026-09-07) scoped this work to a 32 GB Windows dev machine (Windows Event 2004) and explicitly deferred the rest: "**Cross-platform process query** — Phase 1 uses `Get-CimInstance` (Windows). macOS/Linux equivalents (`ps`, `/proc`) are deferred unless there's demand. The existing `processQuery.ts` is already Windows-only." (lines ~239-241). Every query uses `Get-CimInstance Win32_*` through `powershell.exe`, and the comment at `machineDashboard.ts:43-44` says so directly: "All data sources are Windows-only CIM queries".

The gate at `processMonitor.ts:209` (and its siblings at `processQuery.ts:113`, `systemQuery.ts:33`, `healthPanel.ts:212`, `machineDashboard.ts:45/:95`) exists only because the underlying queries return nothing off Windows — it is a symptom of the deferral above, not an independent decision. Once the queries have a POSIX implementation, the gate can go: `checkAnalysisServerSize` (`:381`), `assessHealth` and the free-RAM check are platform-neutral given a `DartProcessInfo[]` and a `SystemMemorySnapshot`.

---

## Suggested Fix

1. `processQuery.ts` `queryDartProcesses()`: add a darwin/linux branch that parses `ps -axo pid=,ppid=,rss=,etime=,command=` (RSS in KB, ×1024) and filters the same `dart` / `dartvm` / `dartaotruntime` / `flutter_tester` images — note this POSIX filter is intentionally wider than Windows's (`dart.exe`/`dartvm.exe` only), and should match on the executable **basename**, not a substring of the full command line. `isAnalysisServerProcess` already keys on the command line (`language-server`), which `ps` provides in full.
2. `systemQuery.ts` `querySystemMemory()`: darwin reads total memory from `sysctl -n hw.memsize` and free memory from `vm_stat` (free + inactive + speculative pages × page size; the page size is in the `vm_stat` header, 16384 on Apple silicon). Linux reads `MemAvailable` from `/proc/meminfo`.
3. `processQuery.ts` `queryProcessById()` (used by `buildSnapshot` for daemon parent-liveness checks): it shells out to `powershell.exe` unguarded by platform; off Windows it resolves `undefined` → `isParentAlive` returns `false` → every Flutter/scan daemon is flagged orphaned → the critical notification fires, whose "Clean up" action runs `killOrphanedDaemons` against live daemons. This needs a POSIX implementation — `ps -o pid=,lstart= -p <pid>` — **before** the `win32` guard at `processMonitor.ts:209` is removed, or every daemon on macOS/Linux gets killed on the first poll. Use `lstart` (an absolute, `Date.parse`-able timestamp), not `etime` (elapsed time, not a start time — and macOS `ps` doesn't support the GNU `etimes` alternative either).
4. Remove the `win32` guard at `processMonitor.ts:209`. Keep a guard only where a feature is genuinely Windows-specific (orphan `.exe` hosts, `orphanHosts.ts`). Also update `healthPanel.ts:224` (data query) to match — but keep the orphan-host guard at `healthPanel.ts:212`, since that scan is Windows-specific. `processMonitor.ts`'s `sampleHostMemory` (extension host RSS) is also silenced by the current gate and should start reporting once it's removed.
5. `machineDashboard.ts:45/:95`: show POSIX data instead of `platformUnsupported`, and reword the `machineDashboard.platformUnsupported` locale string (currently "Machine Health requires Windows — process queries are not available on this platform", `extension/src/i18n/locales/en.json:854`, mirrored in every other locale file) so it no longer claims a permanent Windows requirement.
6. Note: RSS understates on macOS because the kernel compresses idle pages. `top`'s `MEM` column (phys_footprint) is closer to what starves the machine. Use `top -l 1 -stats pid,mem` or `footprint` if RSS proves too low to trip the threshold.

Prior art in a downstream repo: `saropa_contacts` `scripts/test/test_run_guard.py` v2.1 already implements darwin process and memory snapshots with `ps` / `vm_stat` / `sysctl`.

---

## Fixture Gap

`extension/src/test/systemHealth/` should include:

1. `queryDartProcesses` parses a captured darwin `ps` sample (analysis server, `frontend_server_aot`, `flutter_tester`) → correct pids and bytes. **Fails today** (returns `[]`).
2. `querySystemMemory` parses a captured `vm_stat` plus `hw.memsize` → correct free and total.
3. `ProcessMonitor.start()` on a stubbed `process.platform = 'darwin'` schedules polling. **Fails today.**
4. `checkAnalysisServerSize` with a darwin snapshot holding a 6.7 GB `language-server` → notification fires once, then throttles for 10 minutes.
5. **darwin daemon with live parent is not flagged orphaned** — a `queryProcessById`/`isParentAlive` case exercising the POSIX `lstart` path so a live Flutter/scan daemon isn't killed by `killOrphanedDaemons` on the first poll (see Suggested Fix item 3).
6. A Windows regression case: the existing CIM path is unchanged.

Parsers (`ps`, `vm_stat`, `sysctl` output) should be extracted as pure functions so they're testable directly on captured sample strings without shelling out via `execFile`. Platform stubbing throughout should use `Object.defineProperty(process, 'platform', { value: 'darwin' })` (or `'linux'`), since `process.platform` is a read-only getter and cannot be assigned directly.

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: VS Code extension `saropa.saropa-lints` 16.4.1 (saropa_lints repo `pubspec.yaml` 16.3.0 / 16.4.0 unreleased)
- Dart SDK version: 3.13.3 (Flutter 3.47.4 stable)
- custom_lint version: n/a (extension-native)
- Triggering project/file: `saropa_contacts` workspace, macOS 26.6.2 (Apple silicon, 8 GB RAM)
- Related: `bugs/infra_exclusion_audits_miss_claude_worktrees_nested_package_roots.md`
