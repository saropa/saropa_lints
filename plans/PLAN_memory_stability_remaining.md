# Plan: Memory & Stability Features — Remaining Phases

**Created:** 2026-09-07
**Status:** Pending — requires design decision
**Source:** Split from [`PLAN_memory_stability_features.md`](history/2026.09/2026.09.07/PLAN_memory_stability_features.md) after Phases 1-3 shipped.

---

## Open items

### Consolidate Machine Health into Process Health (user direction, 2026-09-07)

The Machine Health dashboard was implemented as a separate webview. User
feedback: this over-complicates — consolidate into the existing Process Health
panel using collapsible `<details>` sections for progressive disclosure. The
separate panel works but the long-term direction is one unified system health
view with expanders for detail.

### Phase 4 — Windows Job Object process containment

Assign spawned child processes (scan daemon, Ollama daemon) to a Windows Job
Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` so the OS guarantees cleanup
if the parent crashes. Requires native FFI (extension side) or `pywin32`
(`qwen_engine.py` side). Needs a cost/benefit decision on the native dependency.

### Phase 5 — Historical health logging

JSON-lines log at `reports/.saropa_lints/health_log/YYYY-MM-DD.jsonl` (60s
samples: system RAM, per-group RSS, orphan count, shed level) plus a
session-summary line on deactivation and a 24-hour trend chart in the dashboard.

### Code quality deferred items

- `buildRecommendations()` is 101 lines (cap: 50) — split into per-rule helpers.
- `queryData()` is 64 lines mixing 5 concerns — extract orphan-state and
  config-read helpers.
- `orphanCount` derived from both raw pid sets and group objects — single source
  of truth after consolidation.
- PowerShell `execFile` boilerplate duplicated 4× across `processQuery.ts`,
  `orphanHosts.ts`, `systemQuery.ts` — extract a shared `runPowerShellJson()`.
- `BYTES_PER_GB` declared 3× — import from one location.
