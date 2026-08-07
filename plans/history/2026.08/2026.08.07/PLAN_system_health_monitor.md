# PLAN — Extension: System Health Monitor

**Created:** 2026-08-07
**Subsystem:** `extension/src/` (new `systemHealth/` module) + existing status bar
**Status:** COMPLETE
**Related bugs:**
- `bugs/infra_orphan_flutter_daemons_leak_memory.md` (mitigated, scheduled task deployed)
- `bugs/infra_analysis_server_7gb_memory_with_plugin.md` (open)

---

## What it is

A background system health monitor in the saropa_lints VS Code extension that
watches Dart/Flutter process memory consumption and orphaned daemon count,
warns the user via the existing status bar item before OOM crashes occur, and
offers a one-click cleanup action (with user permission).

## Why

Orphaned `flutter daemon` processes and the Dart analysis server together
consumed 9.2 GB of 32 GB RAM on 2026-08-07, causing cascading OOM failures
in MCP servers, the VS Code extension host, and Claude Code. A scheduled
task mitigation is deployed (`~\.flutter_daemon_cleanup.ps1`, every 15 min)
but the user has no visibility into the problem until things crash. Upstream
fixes will not happen — this is our problem to solve locally.

---

## Design Principles

1. **Inform, don't surprise** — show status, explain what's wrong, let the user act
2. **Permission before kill** — never terminate processes without explicit user consent
3. **Minimal overhead** — poll every 60s using WMI/OS APIs, not continuous monitoring
4. **Platform-aware** — Windows-first (WMI for process queries), stub on macOS/Linux
5. **Integrate with existing status bar** — extend `buildStatusBarLabel`, don't add a second item

---

## Thresholds

| Level | Condition | Status bar | Action |
|-------|-----------|------------|--------|
| **Healthy** | Dart RSS < 4 GB AND 0 orphans | No change (existing label) | None |
| **Warning** | Dart RSS 4–6 GB OR 1–3 orphans | Append `⚠ 5.2G` to label | Tooltip explains |
| **Critical** | Dart RSS > 6 GB OR 4+ orphans | Append `🔴 8.1G` to label, show notification | Notification with "Clean Up" button |

RSS = total resident set size across all `dart.exe` + `dartvm.exe` processes.
Orphan = flutter daemon process whose parent PID is dead or recycled (CreationDate check).

Thresholds are configurable via extension settings with these defaults.

---

## Implementation

### Phase 1 — Process monitor service (new file: `extension/src/systemHealth/processMonitor.ts`)

Polls every 60 seconds (configurable). On Windows, spawns:

```
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name = 'dart.exe' OR Name = 'dartvm.exe'\" | Select-Object ProcessId, ParentProcessId, WorkingSetSize, CreationDate, CommandLine | ConvertTo-Json"
```

Parses the JSON result into:

```typescript
interface DartProcessSnapshot {
  totalRssBytes: number;
  processCount: number;
  orphanedDaemonPids: number[];  // flutter_tools.snapshot daemon with dead/recycled parent
  legitimateDaemonCount: number;
  timestamp: number;
}
```

Orphan detection logic (matches the deployed cleanup script):
- Filter to `CommandLine` containing `flutter_tools.snapshot` AND `daemon`
- For each, query parent by `ParentProcessId`
- Parent missing OR parent `CreationDate` >= daemon `CreationDate` → orphaned

### Phase 2 — Status bar integration (modify: `extension/src/statusBarLabel.ts`)

Extend `buildStatusBarLabel` to accept an optional `DartProcessSnapshot`.
When warning/critical, append a health suffix to the existing label:

- Warning: `· ⚠ 5.2G` (yellow foreground via `statusBarItem.color`)
- Critical: `· 🔴 8.1G` (error background via `statusBarItem.backgroundColor`)

Tooltip expands to multi-line:
```
Dart processes: 12 (5.2 GB RSS)
Flutter daemons: 8 (5 orphaned)
⚠ Memory usage is high — click for details
```

All user-facing strings go through `l10n()` from the start — no hardcoded text.

### Phase 3 — Cleanup command (`extension/src/systemHealth/cleanupCommand.ts`)

Register command: `saropaLints.killOrphanedDaemons`

Flow:
1. Show information message: "Found {count} orphaned Flutter daemon processes using {size}. Kill them?"
2. Options: "Kill Orphans" / "Cancel"
3. On confirm: run the cleanup script logic (same two-pass algorithm as `~\.flutter_daemon_cleanup.ps1`)
4. Show result: "Killed {count} orphaned daemons, freed ~{size}"

Also available via command palette: "Saropa Lints: Kill Orphaned Flutter Daemons"

### Phase 4 — Critical notification with action button

When the monitor crosses the critical threshold:
1. Show `vscode.window.showWarningMessage` with the status and a "Clean Up" action button
2. Clicking "Clean Up" runs the `saropaLints.killOrphanedDaemons` command
3. Notification is rate-limited: at most once per 5 minutes (don't spam during a crisis)
4. Add "Don't show again" option that disables notifications (monitor + status bar still active)

### Phase 5 — Extension settings

```jsonc
{
  "saropaLints.systemHealth.enabled": true,
  "saropaLints.systemHealth.pollIntervalSeconds": 60,
  "saropaLints.systemHealth.warningThresholdGB": 4,
  "saropaLints.systemHealth.criticalThresholdGB": 6,
  "saropaLints.systemHealth.warningOrphanCount": 1,
  "saropaLints.systemHealth.criticalOrphanCount": 4,
  "saropaLints.systemHealth.showNotifications": true
}
```

---

## File plan

| Action | File |
|--------|------|
| CREATE | `extension/src/systemHealth/processMonitor.ts` — polling service |
| CREATE | `extension/src/systemHealth/cleanupCommand.ts` — kill orphans command |
| CREATE | `extension/src/systemHealth/types.ts` — `DartProcessSnapshot` interface |
| MODIFY | `extension/src/statusBarLabel.ts` — health suffix in label builder |
| MODIFY | `extension/src/extension.ts` — wire up monitor, register command, pass snapshot to status bar |
| MODIFY | `extension/package.json` — add command + settings contributions |
| MODIFY | `extension/package.nls.json` — command title string |
| MODIFY | `extension/src/i18n/locales/en.json` — all user-facing strings |

---

## Integration with existing tooling

### Claude session monitor (`d:\src\contacts\scripts\ai\claude_monitor.py`)

An existing terminal-based monitor polls `claude agents --json --all` every
3 seconds, showing active sessions with project, model, age, and status.
The extension's system health monitor should offer similar visibility for
Dart processes — same polling-and-display pattern, adapted for VS Code:

- **Borrow the model:** poll → parse → format → display, with configurable interval
- **Don't duplicate:** the Claude monitor stays as a terminal tool; the extension
  monitors Dart/Flutter processes, not Claude sessions
- **Future opportunity:** if the extension gains a webview health panel (Phase 2+),
  it could optionally shell out to `claude agents --json` and show both Claude
  sessions and Dart process health in one view — but that's out of scope for v1

### Cleanup script

The deployed scheduled task (`~\.flutter_daemon_cleanup.ps1`, every 15 min) remains
as the safety net. The extension's cleanup command uses the same algorithm but runs
on-demand with user confirmation. They are complementary:

- **Scheduled task** — automated, silent, no user interaction, catches orphans even
  when VS Code isn't running
- **Extension command** — visible, requires permission, immediate, shows results

The extension does NOT manage or interfere with the scheduled task.

---

## i18n keys (namespace: `systemHealth`)

```
systemHealth.statusBar.warning        — "⚠ {size}"
systemHealth.statusBar.critical       — "🔴 {size}"
systemHealth.tooltip.processCount     — "Dart processes: {count} ({size} RSS)"
systemHealth.tooltip.daemonCount      — "Flutter daemons: {total} ({orphaned} orphaned)"
systemHealth.tooltip.warningHint      — "Memory usage is high — click for details"
systemHealth.tooltip.criticalHint     — "Memory usage is critical — clean up recommended"
systemHealth.notification.critical    — "Dart processes are using {size} with {orphaned} orphaned daemons. Clean up?"
systemHealth.notification.result      — "Killed {count} orphaned daemons, freed ~{size}"
systemHealth.command.killOrphans      — "Saropa Lints: Kill Orphaned Flutter Daemons"
systemHealth.settings.enabled         — "Monitor Dart process memory and orphaned Flutter daemons"
systemHealth.settings.pollInterval    — "How often to check process health (seconds)"
systemHealth.settings.warningGB       — "Show warning when total Dart RSS exceeds this (GB)"
systemHealth.settings.criticalGB      — "Show critical alert when total Dart RSS exceeds this (GB)"
```

---

## Out of scope

- macOS/Linux process monitoring (stub with "not supported" — Windows-first)
- Analysis server restart/management (separate concern, see related bug)
- Job Object wrapper for flutter_agent_lens (belongs in that repo)
- Webview dashboard with charts (status bar + notifications is sufficient for v1)

---

## Acceptance criteria

1. Status bar shows health suffix when Dart RSS > 4 GB or orphans > 0
2. Critical threshold triggers a notification with a "Clean Up" button
3. "Clean Up" kills only orphaned daemons (PID reuse guard), shows count + freed size
4. All user-facing strings are in `en.json`, none hardcoded
5. Polling does not visibly impact extension performance (< 200ms per poll)
6. No processes killed without explicit user consent (notification button or command palette)
7. Works correctly when no Dart processes are running (healthy state, no errors)

---

## Finish Report (2026-08-07)

### Implementation summary

All five phases of the system health monitor were implemented across two sessions. The feature adds a background process monitor to the saropa_lints VS Code extension that polls Dart/Flutter processes via WMI on Windows, tracks total RSS and orphaned daemon count, and surfaces health status through the existing status bar item.

### Files created

- `extension/src/systemHealth/types.ts` — `DartProcessInfo`, `DartProcessSnapshot` interfaces, `HealthLevel` const enum
- `extension/src/systemHealth/processQuery.ts` — WMI query, JSON parsing, orphan detection via full OS process table lookup, snapshot builder
- `extension/src/systemHealth/processMonitor.ts` — `ProcessMonitor` class with configurable polling, snapshot listeners, rate-limited critical notifications
- `extension/src/systemHealth/cleanupCommand.ts` — `saropaLints.killOrphanedDaemons` command with live re-query before kill and modal confirmation

### Files modified

- `extension/src/statusBarLabel.ts` — added optional `systemHealthSuffix` parameter to `buildStatusBarLabel()`
- `extension/src/extension.ts` — wired ProcessMonitor lifecycle, snapshot listener, cleanup command registration, config change restart
- `extension/src/i18n/locales/en.json` — 23 keys under `systemHealth` namespace
- `extension/package.json` — 1 command, 7 settings under "System Health" configuration section
- `extension/package.nls.json` — 9 NLS strings for manifest
- `CHANGELOG.md` — `[Unreleased]` entry under `### Added`
- `extension/src/test/sidebarToggleLabel.test.ts` — 2 new tests for systemHealthSuffix branch

### Review findings addressed

1. **Orphan detection was fundamentally broken.** The original `isParentAlive()` searched only the dart-filtered process list for the parent PID. Since daemon parents are typically `cmd.exe`, `Code.exe`, or `node.exe`, every live daemon was classified as orphaned. Fixed by introducing `queryProcessById()` which queries the full OS process table for a specific PID, with unique parent PIDs batched via `Promise.all`.
2. **Stale-snapshot kill risk.** The cleanup command used `monitor.getLastSnapshot()` which could be up to 600 seconds old. PID reuse on Windows meant a cached PID could refer to a different process. Fixed by removing the monitor dependency from `registerCleanupCommand()` and re-querying live processes immediately before presenting the kill dialog.
3. **Inconsistent threshold operators.** `classifyHealth` used `>` for critical RSS but `>=` for warning RSS. Normalized both to `>=`.
4. **7 dead en.json keys.** The `systemHealth.settings.*` block duplicated the NLS strings already in `package.nls.json`. Removed.
5. **Dead imports.** `classifyHealth` and `readSystemHealthConfig` were imported into `extension.ts` but never used. Removed.
6. **Unnecessary re-export indirection.** `processMonitor.ts` re-exported `formatBytes` from `processQuery.ts`. Consumers now import directly from `processQuery.ts`.
7. **Added `maxBuffer: 4MB`** to all `execFile` calls to prevent silent failures on large process lists.

### Hardening pass (reflection gate)

8. **CIM_DATETIME parsing.** WMI `ConvertTo-Json` emits DateTime as `/Date(1234567890000)/` which `new Date()` cannot parse. Added `parseCimDate()` that extracts epoch milliseconds from the .NET JSON date format, falling back to `Date.parse()` for ISO strings, and returning 0 (triggering "assume alive" safe default) for unparseable values.
9. **`isDaemonProcess` word-boundary regex.** Changed from `cmd.includes('daemon')` to `/\bdaemon\b/.test(cmd)` so `dart_tooling_daemon` is not falsely classified as a Flutter daemon.
10. **Config-change restart scoped.** The `onDidChangeConfiguration` handler now only restarts the monitor when `enabled` or `pollIntervalSeconds` change, not on `showNotifications` or threshold changes that don't affect the poll timer.

### Process Health webview panel (unrequested feature)

Created `extension/src/systemHealth/healthPanel.ts` (controller), `healthPanel-html.ts` (HTML builder), `healthPanel-script.ts` (client JS), `healthPanel-styles.ts` (CSS). Registered command `saropaLints.showProcessHealth` in `package.json` and `extension.ts`. Panel shows a live table of all Dart/Flutter processes with PID, parent PID, RSS, type classification (process/daemon/orphan pills), command line, and per-process kill buttons for orphaned daemons.

### Second review findings addressed

11. **Dispose race condition.** `HealthPanel.refresh()` and `killAndNotify()` now check a `disposed` flag before touching `this.panel.webview` after awaiting async work.
12. **CSP blocks inline onclick.** Replaced all `onclick="..."` attribute handlers with `data-action` attributes and a delegated `document.addEventListener('click', ...)` in the script, which is authorized by the nonce-only CSP.
13. **Duplicated `isDaemonProcess`.** Exported from `processQuery.ts`; `healthPanel-html.ts` now imports it instead of reimplementing inline.
14. **Duplicated `killProcess`.** Extracted to `processQuery.ts` as a shared export; `cleanupCommand.ts` and `healthPanel.ts` both import from there.
15. **Hardcoded "Killed"/"Failed" strings.** Added `systemHealth.panel.killed` and `systemHealth.panel.killFailed` keys to `en.json`. Labels are passed into the webview via `data-label-killed`/`data-label-failed` attributes and read by the client script.

### Verification

- TypeScript compilation: 0 errors (`npx tsc --noEmit`)
- NLS key parity: OK (321 keys)
- Unit tests: 9/9 passing (including 2 new tests for systemHealthSuffix)
- Locale regeneration: deferred — MT pipeline in transition (NLLB→Qwen); publish gate enforces
