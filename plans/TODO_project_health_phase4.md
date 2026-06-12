# TODO — Project Health dashboard, Phase-4 residuals

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §3 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** project-health CLI + HTML/webview render
**Source plan:** `history/2026.05/2026.05.25/PROJECT_HEALTH_DASHBOARD_PLAN.md`

Core CLI + size map shipped (`dart run saropa_lints:project_health`). These are the residuals.

## Status legend
- **[OPEN — verified]** confirmed still unbuilt by reading current code in the 2026-06-11 audit.
- **[DEFERRED]** intentional standing deferral; build only when a real consumer/trigger appears.

---

## 3.1 Phase-4 render unverified **[OPEN — verified]**

The `--format html` beautiful report and the async cancellable webview render in a browser but
were **never screenshot / runtime-verified against the design**.

Action: render both, screenshot, compare to the Phase-4 design in the source plan, tune. This is a
`/verify`-style task, not new feature code — confirm the shipped render matches intent.

## 3.4 SQLite store **[DEFERRED]**

NDJSON shards shipped. SQLite is deferred until full-set interactive arbitrary-filter querying is
actually needed. No code blocker — a capability choice. Build only when interactive cross-shard
filtering is requested.

---

## Already split out (do not duplicate here)

- **§3.2 Isolate worker pool** → `deferred/PROJECT_HEALTH_isolate_worker_pool.md` (cold-scan CPU
  parallelism; throughput-only, would destabilize the verified core for unmeasured gain).
- **§3.3 Adaptive huge-workspace auto-defaults** → `deferred/PROJECT_HEALTH_adaptive_huge_workspace.md`
  (auto-aggregate above a file-count threshold; no real-user trigger yet).
