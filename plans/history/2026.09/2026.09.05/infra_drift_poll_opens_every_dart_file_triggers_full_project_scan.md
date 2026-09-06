# BUG: Drift Advisor poll opens every Dart file, cascading into full-project resolved scans and VS Code OOM crashes

**Status: Fixed**

Created: 2026-09-05
Rule: N/A (infrastructure — extension `driftAdvisor/mapper.ts` + `scanOnSave/scanOnSaveController.ts`)
Severity: Critical (crashes VS Code, exhausts system commit memory)
Since: scan-on-save `onDidOpenTextDocument` hook + Drift Advisor 30 s poll

---

## Summary

With `saropaLints.driftAdvisor.integration: true`, the extension polls the Drift
server every 30 s (`pollIntervalMs`, `extension.ts:824`) and calls
`mapIssuesToLocations()`. That function resolves each table name by calling
`vscode.workspace.openTextDocument()` on **every Dart file in the workspace**
(`driftAdvisor/mapper.ts:82-90`) until a regex matches. A table that does not
match opens all files, and the per-call `tableCache` is discarded, so the full
walk repeats on every poll.

Every programmatic `openTextDocument` fires `onDidOpenTextDocument`, which
`scanOnSaveController._queueIfDart` (`scanOnSaveController.ts:220`) treats as
"user opened a file" and queues for scanning. Result in the contacts project:

```
[scan-on-save] scanning 4598 file(s): d:\src\contacts\test\utils\system\...
[scan-on-save] tier=recommended, resolveTypes=true, useDaemon=false, daemonSuspended=true
```

33 full-project resolved scans of 4598 files were launched in the first
50 minutes of the 19:55 session; none logged `scan complete`. Each spawns a
`dart run saropa_lints scan --resolve` process that resolves the whole project.

The same opens also reach the Dart analysis server (4598 `didOpen` → priority
files, fully resolved and pinned) and the Saropa LSP (thousands of
`didClose` lines per file in the LSP log).

## Evidence

Windows System event 2004 at 2026-09-05 22:18:01:

```
low virtual memory condition ... dart.exe (5752) consumed 22210670592 bytes,
dart.exe (7152) consumed 13450592256 bytes, and Code.exe (13764) consumed 6193004544 bytes
```

Extension host for the contacts window went unresponsive at 21:18:32
(renderer.log) and was restarted twice (20:49, 21:18). Crashpad dumps for the
renderer, GPU, and extension-host processes appeared at 12:33, 13:39, 14:20,
19:08 and 22:18 today. Earlier crashes had an additional cause (three orphaned
`llama-server.exe` processes holding 37 GB commit, killed 19:27, machine
rebooted 19:45); the 22:18 crash happened after the reboot with only Dart
processes at the top.

Logs: `%APPDATA%\Code\logs\20260905T195528\window1\exthost\output_logging_*\2-Saropa Lints.log`
(11.8 MB, 9.2 MB, 19.8 MB — each `scanning 4598 file(s)` line is 354 KB).

The standalone Drift Advisor extension has the same pattern
(`drift-source-locator.ts:32-38`, `file-decoration-provider.ts:61-66`) but its
calls are user-triggered (go-to-definition, tree click), not on a timer.

## Fix

1. `mapper.ts`: read files with `fs.promises.readFile` (or `workspace.fs.readFile`),
   never `openTextDocument`, so no document events fire. Cache the
   table→location map across polls and invalidate on `onDidChange` of `*.dart`
   files under `lib/`. Restrict the glob to `lib/**/*.dart` (tables never live
   in `test/` or `dependency_overrides/`).
2. `scanOnSaveController._queueIfDart`: ignore documents that are not visible
   in an editor (`vscode.window.visibleTextEditors` / tab groups). Programmatic
   opens from any extension must not trigger scans. Add a hard cap: a queued
   batch above N files (e.g. 20) is a bug signal, not a scan; log and drop it.
3. `_scan`: never log the full file list; log the count and the first 5.
4. Standalone Drift Advisor: same `readFile` swap in `drift-source-locator.ts`
   and `file-decoration-provider.ts` (file a bug in that project's `bugs/`).

## Resolution

Fixed on 2026-09-05 across three files.

`driftAdvisor/mapper.ts` no longer calls `openTextDocument` at all. File
content is read with `vscode.workspace.fs.readFile`, which raises no document
event. The table-to-location map and the file list are now module-level caches
guarded by a generation counter, so an invalidation landing mid-walk discards
that walk's result instead of caching a stale one. A `**/*.dart` filesystem
watcher clears both caches on create, change, and delete. The search glob now
excludes build output, `.dart_tool/`, `test/`, `integration_test/`,
`dependency_overrides/`, and generated files. Within a single call the file
holding a table is read once no matter how many column issues reference it.

`scanOnSave/scanOnSaveController.ts` no longer treats a programmatic document
open as a user action. Files are queued optimistically with their origin
recorded as save or open, and the visible-editor and tab check runs after the
debounce rather than inside the event handler, so a genuine user open is not
rejected because its tab has not registered yet. Saves bypass the check and
the cap entirely. A batch of open-derived files above the cap is dropped
rather than scanned, and the drop is surfaced in the status bar, not only the
log. Scan log lines print a count and a five-path sample instead of the full
list, which previously produced a single 354 KB line per scan.

`scanOnSave/scanOnSaveRunner.ts` gained a wall-clock watchdog. The spawned
scan process is killed and the promise resolved if it does not finish, which
closes a second defect found during the fix: the runner accepted a
cancellation token that the controller never passed, so a hung scan left the
in-flight flag set and silently disabled scan-on-save for the rest of the
session. The controller now creates a token per scan and cancels a scan whose
file set a newer batch fully covers.

`extension.ts` disposes the mapper's file watcher on deactivate.

Runtime behavior in a live VS Code window is unverified — see the extension
verification protocol. A human must confirm at F5 that opening a Dart file
still produces diagnostics without saving, that a background tab still scans,
that Save All across more than 20 files still reports, and that the poll no
longer produces full-project scan bursts.

## Workaround before the fix shipped

Set `"saropaLints.driftAdvisor.integration": false` in user settings, or
`"saropaLints.driftAdvisor.pollIntervalMs": 0`. The setting defaults to false,
so only users who explicitly enabled the Drift integration were affected.

---

## Finish Report (2026-09-05)

### Defect

A 30-second poll in the extension's Drift integration resolved Drift table
names by opening every Dart file in the workspace as a VS Code text document.
Each such open raised `onDidOpenTextDocument`, which the scan-on-save
controller treated as a user opening a file, so it queued and launched
whole-project resolved lint scans. On a 4598-file project this produced 33
scan launches in 50 minutes against one completion, drove two Dart processes
to 22 GB and 13 GB of committed memory, and ended in an unresponsive extension
host and a VS Code crash.

### Changes

`extension/src/driftAdvisor/mapper.ts` reads file bytes through
`vscode.workspace.fs.readFile`, which creates no document and raises no event.
The table-location map and the workspace file list became module-level caches
behind a generation counter, so an invalidation arriving mid-walk discards that
walk's result rather than publishing a stale one. A Dart file watcher clears
both caches, and a workspace-folder listener covers the folderless start. A
negative result is cached only when it came from a real search; a lookup that
could not search caches nothing, so navigation recovers once a folder appears.
The search glob excludes build output, tool directories, tests, dependency
overrides, and generated files. Within one call each file is read once
regardless of how many issues reference its table.

`extension/src/scanOnSave/scanOnSaveController.ts` records whether each queued
path arrived from a save or from a document-open event, and applies the
visible-editor and tab check after the debounce rather than inside the event
handler. Deferring it removes a dependence on whether a tab is registered
before `onDidOpenTextDocument` fires. Saved paths bypass both the visibility
filter and the batch cap. Open-derived batches above the cap are dropped rather
than scanned, and the dropped count survives onto the terminal status line of
the batch so a drop remains visible when a scan also ran. Scan log lines print
a count and a short sample; the previous full-list line reached 354 KB.

`extension/src/scanOnSave/scanOnSaveRunner.ts` gained a watchdog and a
settle-once lifecycle. Cancellation kills the child but deliberately leaves the
watchdog armed, because process-tree termination on Windows is fire-and-forget
and no-ops when the child has no pid; if the kill does not take effect the
watchdog still settles the promise. Previously the runner accepted a
cancellation token that the controller never passed, so a stalled scan left the
in-flight flag set and disabled scan-on-save for the remainder of the session.

`extension/src/extension.ts` disposes the mapper's watchers on deactivate.

### Verification

Both TypeScript projects typecheck clean. The scan-on-save, Drift mapper, and
system-health suites run 120 tests green, including regressions pinning the
generation-counter race, the uncached negative, the settle-once contract, the
cancellation path that produces no close event, and the drop notice surviving a
concurrent scan.

Runtime behavior was not observed. No Extension Development Host was available,
so nothing in this change has been seen rendered or exercised in a live editor.
