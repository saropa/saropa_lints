# BUG: Infrastructure — VS Code Hard Crash from Memory Exhaustion; Status Bar Missing After Restart

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-09-07
Rule: N/A (infrastructure / extension activation)
File: `extension/src/extension.ts` (lines ~1129–1481)
Severity: Critical
Rule version: N/A
Since: observed 2026-09-07

---

## Summary

VS Code hard-crashed (full process termination, no graceful shutdown) while the
contacts project workspace was open. Root cause is cumulative memory exhaustion
from multiple unwatched large files in the workspace combined with the Dart
analyzer's 6 GB heap reservation. After restarting VS Code, the Saropa Lints
status bar item is not visible — the extension either failed to activate or the
status bar update cycle did not complete.

---

## Attribution Evidence

This is an infrastructure bug, not a lint rule bug. The status bar is created in
the extension's `activate()` function:

```
extension/src/extension.ts:1129:  const statusBarItem = vscode.window.createStatusBarItem(...)
extension/src/extension.ts:1138:  const memoryStatusBarItem = vscode.window.createStatusBarItem(...)
```

Both items call `.show()` at line 1399/1481 inside `updateAllStatusBars()`, which
is invoked at line 1483 during activation. If activation throws or the extension
host crashes before reaching that point, neither item appears.

---

## Environment at Time of Crash

- **OS:** Windows 11 Pro 10.0.22631
- **VS Code:** crashed (version unknown post-crash)
- **Workspace:** `d:\src\contacts` (Flutter project)
- **Dart analyzer heap:** `--old_gen_heap_size=6144` (6 GB reserved)
- **saropaLints.enabled:** true
- **saropaLints.scanOnSave.enabled:** true
- **saropaLints.todosAndHacks.workspaceScanEnabled:** true
- **saropaLogCapture.enabled:** true (10 adapters active)

---

## Part 1: VS Code Hard Crash — Root Cause Analysis

### Memory budget consumed before VS Code even starts working

| Source | Size | Watched by VS Code? |
|--------|------|---------------------|
| `android/java_pid21840.hprof` (JVM heap dump) | **2.2 GB** | YES — not in `files.watcherExclude` |
| `custom_lint.log` (project root) | **55 MB** | YES |
| `dependency_overrides/fluttermoji/custom_lint.log` | **31 MB** | YES |
| `lib/l10n/*.arb` (26 locale files) | **140 MB** | YES — only excluded from Dart analysis, not file watcher |
| `assets/l10n/*.arb` (26 locale files) | **141 MB** | YES |
| `hs_err_pid*.log` (6 JVM crash logs) | ~1 MB total | YES |
| Dart analyzer heap reservation | **6 GB** | N/A (process memory) |
| `build/` directory | **3.6 GB** (13,294 files) | Excluded from watcher, but on disk |
| `reports/` directory | **4.7 GB** (6,389 files) | Excluded from watcher |
| Total workspace files (excl `.git`) | ~31,800 | — |

### The smoking gun: 2.2 GB `.hprof` heap dump

`android/java_pid21840.hprof` is a JVM heap dump from a prior Gradle OOM crash
(dated 2026-08-27). The `.gitignore` covers `*.hprof` for git purposes, but
VS Code's `files.watcherExclude` in `.vscode/settings.json` did NOT exclude
`*.hprof` files. The file watcher attempted to track this 2.2 GB file, likely
triggering memory-mapped I/O or buffer allocation that pushed the process over
the edge.

Six `hs_err_pid*.log` files at the project root confirmed Gradle had already
OOM'd with:
> "There is insufficient memory for the Java Runtime Environment to continue.
> Native memory allocation (mmap) failed to map 536870912 bytes.
> Error detail: G1 virtual space"

The same machine memory pressure that killed Gradle eventually killed VS Code.

### 281 MB of ARB files being file-watched for no reason

The 52 ARB localization files across `lib/l10n/` and `assets/l10n/` total 281 MB.
These are static JSON that only change when the l10n translation pipeline runs —
never during normal editing. `dart.analysisExcludedFolders` excludes `lib/l10n`
from the Dart analyzer, but the VS Code file watcher and search indexer still
scanned all 52 files on every filesystem event.

### 6 GB Dart analyzer heap

The setting `"dart.analyzerVmAdditionalArgs": ["--old_gen_heap_size=6144"]`
reserves 6 GB for the Dart analysis server alone. Combined with VS Code's own
Electron process (~1–2 GB), the Saropa Lints extension, Saropa Log Capture
(10 adapters), GitLens, Error Lens, and the file watcher's memory for 31,800
files, the total memory footprint easily exceeds 10 GB before the user opens a
single file.

### 474 KB `analysis_options.yaml`

The analysis options file is 474 KB / ~2,000 lines. This is parsed repeatedly by
both the Dart analysis server and the `saropa_lints` custom lint extension on
every file change event. While not a crash cause on its own, it amplifies memory
churn in the analyzer process.

---

## Part 2: Fixes Applied (2026-09-07)

### Files deleted (2.3 GB freed)

| File | Size | Why deleted |
|------|------|-------------|
| `android/java_pid21840.hprof` | 2.2 GB | Stale JVM heap dump from prior Gradle crash |
| `custom_lint.log` | 55 MB | Stale custom_lint output from 2026-02-16 |
| `dependency_overrides/fluttermoji/custom_lint.log` | 31 MB | Stale custom_lint output |
| `hs_err_pid15020.log` | ~150 KB | JVM crash log |
| `hs_err_pid18560.log` | ~150 KB | JVM crash log |
| `hs_err_pid19992.log` | ~150 KB | JVM crash log |
| `hs_err_pid21536.log` | ~150 KB | JVM crash log |
| `hs_err_pid31260.log` | ~150 KB | JVM crash log |
| `hs_err_pid34652.log` | ~150 KB | JVM crash log |

### Watcher exclusions added to `.vscode/settings.json`

```json
"files.watcherExclude": {
    "**/build/**": true,
    "**/reports/**": true,
    "**/blobs/**": true,
    "**/.dart_tool/**": true,
    "**/dependency_overrides/**/build/**": true,
    "**/dependency_overrides/**/.dart_tool/**": true,
    "**/lib/l10n/**": true,
    "**/assets/l10n/**": true,
    "**/*.hprof": true,
    "**/*.log": true,
    "**/.vs/**": true
}
```

New entries (last 5) prevent future accumulation of unwatched large files.

---

## Part 3: Open Issues

### OPEN-1: Saropa Lints status bar not visible after restart — FIXED

**Symptom:** After VS Code restarted post-crash, the Saropa Lints status bar item
(normally showing health score, tier, and violation count) is not visible.

**Root cause confirmed:** `updateAllStatusBars` had no top-level exception
handling. A throw anywhere in its body (e.g. `loadHistory(context.workspaceState)`
against a workspaceState corrupted by the hard crash) aborted the function before
reaching `statusBarItem.show()`, leaving the bar silently absent.

**Fix:** Commit `4ce4859f` ("harden: memory monitoring infrastructure +
crash-safe status bar") already applied the exact recommendation below — the
body was extracted into `updateAllStatusBarsInner()` and `updateAllStatusBars`
now wraps it in try/catch (extension.ts:1551), rendering a visible
`$(error) ...` status bar item and logging to the "Saropa Lints" output channel
on any throw, so `statusBarItem.show()` always executes. No further action
needed here.

### OPEN-2: Dart analyzer heap size (6 GB) is aggressive — MOVED

This concerns `d:\src\contacts` workspace settings (`.vscode/settings.json`
`dart.analyzerVmAdditionalArgs`), not the saropa_lints extension. Per project
scope rules, filed instead in the contacts project's own `bugs/` — not tracked
here.

### OPEN-3: `custom_lint.log` and `hs_err_*.log` not in `.gitignore` — MOVED

This concerns the `d:\src\contacts` project's own `.gitignore`, not
saropa_lints. Filed in the contacts project's own `bugs/` — not tracked here.

### OPEN-4: `analysis_options.yaml` is 474 KB (2,000+ lines)

This file is parsed on every file-change event by both the Dart analysis server
and the saropa_lints plugin. At this size it contributes to memory churn and
parse latency. Most projects have analysis_options under 5 KB.

**Status:** Noted for future investigation. The file appears to contain manually
flattened rule configurations rather than using `include:` directives. A
structural refactor could reduce it significantly, but this is not urgent.

### OPEN-5: 31,800 files in workspace with limited exclusions — MOVED

This concerns `d:\src\contacts` workspace settings (`search.exclude`), not
saropa_lints. Filed in the contacts project's own `bugs/` — not tracked here.

---

## Summary of State

| Item | Status |
|------|--------|
| 2.2 GB `.hprof` deleted | **FIXED** |
| 86 MB `custom_lint.log` files deleted | **FIXED** |
| 6 JVM crash logs deleted | **FIXED** |
| Watcher exclusions for l10n, `.hprof`, `.log`, `.vs` | **FIXED** |
| Status bar not visible after restart | **FIXED** — try/catch hardening already in `4ce4859f` |
| 6 GB analyzer heap too aggressive | **MOVED** — contacts project scope |
| Missing `.gitignore` entries | **MOVED** — contacts project scope |
| 474 KB `analysis_options.yaml` | **OPEN-4** — noted, low priority |
| 31,800 files with limited search exclusions | **MOVED** — contacts project scope |
