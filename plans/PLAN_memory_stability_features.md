# Plan: Memory & Stability Features for the Extension

**Created:** 2026-09-06
**Status:** Draft — awaiting review
**Source:** [`plans/ANALYSIS_dev_machine_stability.md`](ANALYSIS_dev_machine_stability.md)
**Related:** [`plans/history/2026.09/2026.09.02/PLAN_analyzer_memory_monitor.md`](history/2026.09/2026.09.02/PLAN_analyzer_memory_monitor.md) (Phases 0-4 shipped), [`plans/history/2026.08/2026.08.07/PLAN_system_health_monitor.md`](history/2026.08/2026.08.07/PLAN_system_health_monitor.md)

---

## Problem

A 32 GB dev machine running VS Code + Flutter + AI extensions routinely hits
virtual-memory exhaustion (Windows Event 2004) from four independent actors:
Dart analysis server (unbounded RSS), Flutter daemon sprawl (orphaned children),
AI extension leaks (per-session heap growth), and the translation engine's Ollama
daemon (orphaned model hosts). None have upstream fixes on any reliable timeline.

The extension already **reports** some of this (Process Health panel, status bar,
orphan preflight) and **addresses** a subset (orphan reclaim, shed rules, memory
pressure watcher). This plan fills the gaps: things we can ship that give the
developer visibility into what's eating their machine and actionable controls to
fix it without leaving the editor.

---

## What already exists

| Surface | Reports | Addresses |
|---------|---------|-----------|
| Status bar | Saropa RSS (warn/crit), shed count, orphan count | Click → Health Panel |
| Tooltip | Sparkline, trend arrow, per-category breakdown | — |
| Health Panel (webview) | Process table, orphan banner, engine cards | Kill orphan button per-row |
| Notifications | Critical RSS, leak detection, orphan preflight | Clean Up / Reclaim buttons |
| Memory pressure watcher | Shed level from plugin's `memory_state.json` | Prompt to enable `shed_rules` |
| Cleanup command | — | Kill orphaned Flutter/scan daemons |
| Orphan preflight | Detect orphaned llama-server/ollama at startup | Reclaim with confirmation |

---

## Phases

### Phase 1 — Machine Health Dashboard (new webview, not a rewrite of Health Panel)

**Goal:** One page a developer opens when the machine feels slow, showing
everything relevant across the whole Dart/Flutter/AI stack — not just saropa's
own processes.

**What it shows (read-only, no kill buttons in v1):**

1. **System summary bar** — total physical RAM, available RAM, commit charge,
   swap usage. Color-coded: green/yellow/red at 70%/85% thresholds. Source:
   `Get-CimInstance Win32_OperatingSystem` (already used in orphan preflight).

2. **Process groups** — collapsible sections, each with aggregate RSS and
   process count:
   - **Dart Analysis Servers** — every `dart.exe language-server` process, with
     per-process RSS, command-line args (shows `--old_gen_heap_size` if set),
     and which VS Code window owns it (parent PID → extension host → window).
   - **Flutter Daemons** — `flutter_tools` snapshots under `dartaotruntime.exe`,
     orphan status.
   - **AI Extensions** — `claude`, `copilot`, other known extension-host
     children. Best-effort attribution by parent PID chain.
   - **Translation Engine** — Ollama/llama-server processes, model loaded
     (from `/api/ps` if daemon is reachable), VRAM vs RAM split.
   - **Saropa Lints** — existing process breakdown (scan daemon, CLI scans).
   - **Other Dart** — everything else under `dart.exe`/`dartaotruntime.exe`.

3. **Timeline chart** — RSS over time for the top 3 groups (extend the existing
   30-sample ring buffer to per-group tracking, 60s interval, ~30 min window).
   Unicode sparkline per group in the collapsible header; a simple SVG line
   chart in an expanded detail section.

4. **Recommendations panel** — contextual, rule-based suggestions based on
   current state:
   - "Analysis server is using {X} GB — consider adding folder exclusions"
     (link to `analysis_options.yaml` and the relevant Dart-Code docs).
   - "Multiple analysis servers detected — close unused VS Code windows or
     use `dart.onlyAnalyzeProjectsWithOpenFiles`" (with the caveat from
     Dart-Code's own docs).
   - "{N} orphaned processes found — [Reclaim]" (runs existing cleanup).
   - "Claude Code is using {X} GB across {N} sessions — restart older panels".
   - "Ollama model loaded in RAM — run `ollama stop {model}` to free {X} GB".
   - "`--old_gen_heap_size` is not set — consider capping the analysis server"
     (link to `dart.analyzerVmAdditionalArgs`).

**Files to create/modify:**
- `extension/src/systemHealth/machineDashboard.ts` — data aggregation
- `extension/src/systemHealth/machineDashboard-html.ts` — HTML renderer
- `extension/src/systemHealth/machineDashboard-styles.ts` — CSS
- `extension/src/systemHealth/machineDashboard-script.ts` — client JS
- `extension/src/extension.ts` — register command + webview serializer
- `package.json` — command registration, menu contribution
- `en.json` — all new strings under `machineDashboard.*`

**Command:** `saropaLints.showMachineDashboard`
**Sidebar entry:** Under the existing system health section, "Machine Health" row.

---

### Phase 2 — Actionable Controls (kill/restart/cap from the dashboard)

**Goal:** Move from "here's what's wrong" to "click to fix it."

1. **Kill / restart analysis server** — button per analysis-server row.
   Sends `dart.restartAnalysisServer` (Dart-Code's built-in command) or
   kills the PID directly as fallback. Warns that open diagnostics will
   refresh.

2. **Kill orphaned processes** — per-row kill button (extend existing
   `killProcess` to the machine dashboard's broader process set). Grouped
   "Kill all orphans" button with confirmation modal.

3. **Unload Ollama model** — button that POSTs to `http://localhost:11434/api/generate`
   with `keep_alive: 0` to force-unload. Only shown when `/api/ps` reports a
   loaded model.

4. **Set analysis server memory cap** — inline number input that writes
   `--old_gen_heap_size=<MB>` into the user's `dart.analyzerVmAdditionalArgs`
   setting. Shows current value if already set. Warns that a restart is needed.

5. **Open VS Code Process Explorer** — button that runs
   `workbench.action.openProcessExplorer`. Useful when attribution is unclear.

---

### Phase 3 — Proactive Warnings (background, no dashboard needed)

**Goal:** Warn before a crash, not after.

1. **System memory pressure notification** — poll system-wide available RAM
   (reuse the `Get-CimInstance` query, piggyback on the existing 60s poll
   interval). Warn at <15% available with top-3 consumers named. Throttle to
   once per 10 min. "Open Machine Health" button.

2. **Analysis server size warning** — if any `dart.exe language-server` exceeds
   a configurable threshold (default 4 GB), fire a notification naming it and
   suggesting a restart. Distinct from the saropa-only RSS warning (which
   already exists). Config: `saropaLints.systemHealth.analysisServerWarningGB`.

3. **Stale orphan sweep** — extend the existing 15s orphan preflight to also
   run periodically (every 10 min, configurable). Currently it runs once at
   activation. Orphans can appear mid-session when a debug session crashes.

4. **Session-start health check** — on activation, if system available RAM is
   below 20%, show an info notification: "Your machine has {X} GB free of
   {Y} GB — consider closing unused VS Code windows or Ollama models before
   starting work."

---

### Phase 4 — Job Object Process Containment (Windows)

**Goal:** Guarantee child process cleanup even when the parent crashes.

1. **Extension side** — when spawning the scan daemon or any long-lived child
   process, assign it to a Windows Job Object with
   `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. Use Node's `child_process` +
   native FFI or a small native addon. The job handle is inherited; when the
   extension host dies (even via Crashpad/OOM), Windows kills every process
   in the job.

2. **Translation engine (`qwen_engine.py`)** — add Job Object support via
   `pywin32` (`win32job.CreateJobObject` → `SetInformationJobObject` →
   `AssignProcessToJobObject`) at Ollama spawn time. The `_terminate_tree`
   cleanup remains as a belt to the Job Object's suspenders.

3. **Scope:** Windows only. macOS/Linux already propagate signals to process
   groups by default (and the POSIX `_terminate_tree` path handles cleanup).

**Risk:** Native FFI / `pywin32` adds a dependency. The extension side could use
`child_process` stdio inheritance (the child dies when the parent's pipes break)
as a lighter alternative — but this is not guaranteed on Windows the way Job
Objects are. Decision: prototype both, measure reliability.

---

### Phase 5 — Historical Tracking & Trends

**Goal:** Answer "is my machine getting worse over time?" without Task Manager.

1. **Persistent session log** — write a JSON-lines file per day to
   `reports/.saropa_lints/health_log/YYYY-MM-DD.jsonl`. Each line is a
   60-second sample: timestamp, system RAM, per-group RSS totals, orphan
   count, shed level. Rotate at 7 days (configurable). Enables post-crash
   diagnosis ("what was happening at 14:32?").

2. **Session summary** — on deactivation, write a summary line: peak RSS per
   group, orphan count, shed events, crash/restart count. Append to a
   `sessions.jsonl` file for long-term trend.

3. **Trend view in Machine Health dashboard** — if log files exist, show a
   24-hour RSS chart (SVG) with per-group lines. Highlight shed events and
   orphan-reclaim events as markers.

---

## What this does NOT cover

- **Fixing the Dart analysis server's memory** — that's upstream (`dart-lang/sdk`).
  We report, warn, and offer the restart/cap workarounds, but the root cause
  is not ours to fix.
- **Fixing AI extension leaks** — same. We attribute and surface, but the fix
  is in Claude Code / Copilot / Cursor's own codebase.
- **Cross-platform process query** — Phase 1 uses `Get-CimInstance` (Windows).
  macOS/Linux equivalents (`ps`, `/proc`) are deferred unless there's demand.
  The existing `processQuery.ts` is already Windows-only.
- **Auto-killing the analysis server** — too aggressive for a default. We warn
  and offer a button; auto-restart is opt-in at most.
- **Pub workspace consolidation** — the analysis doc mentions it as a memory
  win, but that's a project-structure decision, not an extension feature.

---

## Priority and sequencing

| Phase | Value | Effort | Ships |
|-------|-------|--------|-------|
| 1 | High — the "what's eating my RAM" answer nobody has today | Medium | First |
| 2 | High — turns reporting into action | Low (most kill/restart infra exists) | With or right after 1 |
| 3 | High — prevents crashes before they happen | Low | After 1 |
| 4 | Medium — closes a real gap but edge-case (script crash during cleanup) | High (native FFI) | Later |
| 5 | Low — nice for diagnosis, not urgent | Medium | Last |

Phases 1-3 are the core value. Phase 4 is insurance. Phase 5 is polish.
