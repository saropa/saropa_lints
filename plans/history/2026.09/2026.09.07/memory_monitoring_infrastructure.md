# Memory Monitoring Infrastructure — Crash Prevention

The extension's system health monitoring covered Dart process memory and analyzer
plugin shedding, but was blind to the conditions that actually caused the
2026-09-05 VS Code hard crash: large workspace files tracked by the file watcher,
missing watcher exclusions, and extension host process memory. The status bar also
had no crash recovery path — a corrupted `workspaceState` after a hard crash could
prevent `statusBarItem.show()` from ever executing, silently hiding the extension.

## Changes

### 1. Crash-safe `updateAllStatusBars` (extension.ts)
Refactored the monolithic `updateAllStatusBars` into three functions:
`updateEnabledStatusBar`, `updateAllStatusBarsInner`, and a top-level wrapper
with try/catch. The catch block renders a visible `$(error) Saropa Lints: Error`
state with an error background and always calls `.show()`, so the status bar
never silently disappears. Error is logged to the shared output channel.

### 2. Workspace hazard file scanner (workspaceHazardScan.ts)
New module scans the workspace root for dangerously large files (heap dumps >50MB,
any file >100MB) not covered by `files.watcherExclude`. Runs once on activation
(deferred 15s), skips `build/`, `.dart_tool/`, `node_modules/`, `.git/`, etc.
Shows a warning notification with a one-click "Exclude from Watcher" action.
Disabled via `saropaLints.systemHealth.workspaceHazardScan`.

### 3. Watcher exclude auditor (watcherExcludeAudit.ts)
New module audits the workspace's `files.watcherExclude` against 8 recommended
patterns for Flutter/Dart workspaces. Fires once per session (deferred 10s), with
"Add All" / "Dismiss" buttons. Dismissal is persisted in `workspaceState`.

### 4. Extension host RSS monitor (processMonitor.ts, types.ts)
Extended `ProcessMonitor` to sample `process.memoryUsage()` on each poll cycle,
tracking the Node.js extension host's own RSS and heap. Trend detection via a
parallel ring buffer. Configurable warning threshold (`extensionHostWarningGB`,
default 1GB) surfaces in the status bar when no higher-priority issue is active.
Tooltip shows RSS, heap used/total, and trend arrow.

## Code review fixes applied during /finish
- `matchGlob` regex for `**/` patterns failed to match files at the workspace root
  (no `/` in relative path). Fixed `**/` → `(.*/)?` instead of `.*`.
- `setTimeout` ordering was swapped: hazard scan at 10s, audit at 15s,
  contradicting the comment. Swapped to audit first (10s), scan second (15s).
- Test CONFIG constant missing new `extensionHostWarningGB` field — test compilation
  failed. Added field with default value 1.
- Agent bumped `package.json` version to 16.2.0 — reverted to 16.0.1 per the
  "NEVER bump version numbers" rule.
- JSDoc comment containing `*/` sequence inside backtick span terminated the comment
  block prematurely — converted to line comments.

## Known limitations
- `collectHazards` uses synchronous `readdirSync`/`statSync` recursively. On a
  large monorepo or slow filesystem this blocks the extension host thread. Should
  be converted to async `fs.promises` or `vscode.workspace.findFiles` in a
  follow-up.
- Config-merge logic for `files.watcherExclude` is duplicated between
  `workspaceHazardScan.ts` and `watcherExcludeAudit.ts`. Should be extracted to
  a shared helper.
- Extension host monitoring only runs on Windows (gated by `ProcessMonitor.start`'s
  `process.platform !== 'win32'` guard, which exists for the WMI-based Dart process
  query). `process.memoryUsage()` itself is cross-platform — should run on all
  platforms in a follow-up.

## Finish Report (2026-09-07)

Four modules added to close the monitoring blind spots identified in
`bugs/infra_vscode_crash_memory_exhaustion_missing_statusbar.md`. All compile
clean (both main and test tsconfig). The `statusBarSeverity` test suite passes
(65/65). Extension verification (F5 launch, screenshot) has NOT been performed
— all changes are unverified per the extension verification protocol.
