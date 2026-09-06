# PROPOSAL: Process Health — fix false attribution and non-actionable red alarm

**Status: Implemented**

Created: 2026-09-06
Type: Tooling / Infrastructure
Related rules: N/A (status bar Process Health panel, not a lint rule)

---

## Summary

The Process Health status bar item aggregates ALL Dart process RSS system-wide, colors it red when the total is high, and sits in the saropa_lints status bar — falsely attributing other processes' memory usage to saropa_lints. The user sees red, blames the plugin, and has no action available. Two problems: (1) the red threshold fires on memory saropa_lints doesn't own, and (2) even when the alarm is legitimate, no actionable remedy is offered.

---

## Motivation

On a 32GB Windows machine running VS Code with the contacts project (4400+ files), the Process Health tooltip showed:

```
Process Health
Dart processes: 20 (15.7G RSS)
Saropa Lints: 2 process(es) (29M RSS)
Flutter daemons: 2 (0 orphaned)
Memory usage is critical — clean up recommended
```

The red indicator and "critical" label led the user to suspect saropa_lints was the cause. Investigation revealed:

| PID | Process | RSS | What it is |
|-----|---------|-----|------------|
| 15584 | dart.exe | 6.8 GB | Dart analysis server (no heap cap — second VS Code window) |
| 32124 | dart.exe | 5.7 GB | Dart analysis server (with `--old_gen_heap_size=6144`) |
| 23564 | dartvm | 2.9 GB | `saropa_lints:scan_daemon` for contacts project |

Two analysis servers (12.5GB combined) were the actual problem — a second VS Code window had spawned an uncapped instance. The saropa_lints scan daemon was 2.9GB (notable but secondary), and the remaining 17 processes totaled ~1.5GB. None of this was visible from the tooltip.

The "clean up recommended" message with no breakdown is not actionable — the user cannot distinguish "close a VS Code window" from "saropa_lints is leaking" from "too many Flutter daemons."

---

## Detection / Behavior

### Current (tooltip)

```
Dart processes: 20 (15.7G RSS)
Saropa Lints: 2 process(es) (29M RSS)
Flutter daemons: 2 (0 orphaned)
Memory usage is critical — clean up recommended
```

### Proposed — separate owned vs external, only alarm on owned

```
Saropa Lints: 2 process(es) (29M RSS) ✓
  scan_daemon (contacts)   2.9G
  lsp_server                73M
Flutter daemons: 2 (0 orphaned)
Other Dart processes: 17 (12.8G RSS)
  dart analysis server     6.8G  (no heap cap)
  dart analysis server     5.7G
  frontend_compiler         386M
```

**Key changes:**

1. **Red/yellow/green only reflects saropa_lints-owned processes** (scan daemon, LSP server). The system-wide Dart total is informational — shown in neutral color, never red. A 12.5GB analysis server is not saropa_lints' fault and should not make the saropa_lints indicator red.
2. **Top 2-3 processes shown per category** so the user can identify what's consuming memory without opening Task Manager.
3. **Actionable message when saropa_lints IS the problem** — e.g. "scan_daemon: 2.9G — restart with `dart run saropa_lints:scan_daemon --restart`" or a clickable kill/restart action. Red without a remedy is just anxiety.
4. **"Other Dart processes" section is informational** — helps the user but does not alarm. If saropa_lints can detect an obvious issue (two analysis servers, orphaned daemons), a neutral hint is fine ("2 analysis servers detected — close unused VS Code windows").

---

## Edge Cases

1. **saropa_lints scan daemon is genuinely large** — 2.9GB for a 4400-file project may be expected or may be a leak. Either way, saropa_lints owns it and CAN offer a restart action. This is a legitimate red. **Note:** the scan daemon's RSS warrants its own investigation — if 2.9GB is normal for a project this size, the red threshold for owned processes should account for it; if it's a leak, that's a separate bug.
2. **Many small processes** — if no single process dominates, the breakdown still helps by showing distribution. The message should remain neutral, not red.
3. **Process identification** — command-line parsing to label processes (analysis server vs scan daemon vs flutter run) needs heuristics. A fallback of PID + RSS is still better than a blind aggregate.
4. **Tooltip width** — long command lines should be truncated to a short label, not shown raw.
5. **System-wide total is fine to show** — the user benefits from seeing it. The issue is coloring it red under the saropa_lints brand, implying ownership and blame.

---

## Open questions

1. **Scan daemon 2.9GB — expected or leak?** On a 4400-file project the scan daemon consumed 2.9GB RSS. If this is normal for large projects, the red threshold for owned processes must account for it (otherwise every large project shows red permanently). If it's a leak, that's a separate bug. Profile across project sizes (500, 2000, 4000+ files) to determine.
2. **Two analysis servers — why?** The uncapped 6.8GB server (PID 15584) started 44s before the capped one (PID 32124). Most likely cause: a second VS Code window or multi-root workspace where one root doesn't inherit `.vscode/settings.json`. Process Health could detect and hint at this ("2 analysis servers detected — close unused VS Code windows") without alarming red.
3. **Green hiding a real problem?** If saropa_lints-owned processes are small but leaking, a green indicator could mask the issue while "Other Dart processes" draws no alarm at 12GB. Consider a yellow tier for owned-process growth rate (RSS increasing over time) even when the absolute value is below the red threshold.

---

## Stretch goal: RSS history sparkline

Track owned-process RSS over time and show a sparkline in the status bar or tooltip. A flat line = stable (expected); a rising line = leak (investigate). This lets the user distinguish "large but stable" from "growing without bound" without needing Task Manager or external monitoring. The sparkline should cover the current VS Code session only (no cross-session persistence needed).

---

## Stretch goal: kill orphaned Dart processes

When Process Health detects Dart processes whose parent VS Code window no longer exists (orphaned Flutter daemons, stale analysis servers from crashed windows, zombie build_runner processes), offer a one-click "Clean up N orphaned processes" action. This addresses the "clean up recommended" message by actually providing a cleanup mechanism.

**Detection heuristic:** a Dart process is orphaned when its parent PID no longer exists or is not a VS Code process. Flutter daemons (`flutter_tools.snapshot daemon`) and analysis servers (`language-server --protocol=lsp`) are the most common orphan types. Build-related processes (`build_runner`, `frontend_server_aot`) should only be flagged if idle for >5 minutes (they may be legitimately running a long build).

**Safety:** only kill processes the heuristic is confident about. Show the list before killing. Never kill the user's running debug session or a process attached to an active VS Code window.

---

## Alternatives Considered

1. **Click-to-open a detailed panel** — more room for information, but the tooltip is where users look first when they see red. A panel could be a follow-up; the tooltip needs the top-level breakdown regardless.
2. **Only show saropa_lints' own memory** — would miss the point; the user sees "Dart processes: 20 (15.7G)" and needs to know which ones, not just whether saropa_lints is one of them.
3. **Orphaned process detection without a kill action** — detecting and labeling orphans is useful even without the kill button, but the kill is what makes "clean up recommended" actionable.

---

## Decision

Accepted and implemented 2026-09-06. Core scope only — stretch goals (RSS sparkline, kill-orphans action) deferred to separate proposals.

---

## Implementation Notes

### What changed

1. **`assessHealth()` thresholds on `saropaRssBytes` only** (`processMonitor.ts:41-64`). The 4GB/6GB warning/critical thresholds now compare saropa-owned process RSS (scan daemon, CLI scans), not the system-wide Dart total. A 12GB analysis server no longer makes the saropa_lints status bar go red.

2. **Status bar text shows saropa RSS** (`processMonitor.ts:93-111`). Memory-triggered warnings/criticals display the saropa-owned figure — the number that actually tripped the threshold.

3. **Per-process tooltip breakdown** (`extension.ts:1171-1245`). The tooltip now shows three sections:
   - **Saropa Lints** — owned process count and RSS, with top 3 by RSS listed individually. Shows a ✓ when healthy.
   - **Flutter daemons** — count and orphan status (unchanged).
   - **Other Dart processes** — informational only (never red). Top 3 listed individually. Hints when 2+ analysis servers detected ("close unused VS Code windows").

4. **Process labeling** (`processQuery.ts:140-168`). New `processLabel()` function parses command lines into human-readable labels: "scan daemon", "analysis server", "analysis server (no heap cap)", "Flutter daemon", "frontend compiler", "build runner", "dart process".

5. **`DartProcessSnapshot.processes` field** (`types.ts`). The full process list is now carried in the snapshot so the tooltip can render per-process detail without re-querying.

6. **New test** (`statusBarSeverity.test.ts`). Pins the false-attribution fix: 12GB `totalRssBytes` with 29MB `saropaRssBytes` must remain Healthy.

### Assumptions verified

- **Process enumeration**: already existed via `queryDartProcesses()` with full command-line parsing. No new shell calls needed.
- **Tooltip rendering**: VS Code hover tooltips support multi-line plain text. The per-process lines are indented and truncated to short labels, fitting within standard tooltip width.
- **Platform**: process enumeration is Windows-only (`process.platform !== 'win32'` returns empty). No cross-platform changes needed — the tooltip gracefully shows nothing when no processes are enumerated.
- **Red threshold for owned processes**: existing 4GB/6GB defaults kept. Profiling scan daemon RSS across project sizes remains an open question (see Open Questions §1) — the threshold can be tuned via `saropaLints.systemHealth.warningThresholdGB` / `criticalThresholdGB` settings.

---

## Commits

<!-- Add commit hashes as implementation lands -->
