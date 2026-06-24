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

## 3.1 Phase-4 render **[CLOSED — verified 2026-06-24]**

The `--format html` report was rendered (`dart run saropa_lints:project_health --format html` against
the Saropa Contacts workspace, 4011 files / 1.1M LOC) and confirmed to render correctly against the
Phase-4 design: brand banner, KPI chips, treemap size map with the orange LOC ramp + per-tile contrast
text, sticky/sortable/filterable hotspot table, dark mode, reduced-motion, brand focus ring, skeleton
removal, and the VS Code `openFile` bridge all present and correct. Empty sections (scatter, gravity)
hide themselves cleanly when a scan computes size only — no false "all clear" tables.

Note for future work: a bare `--format html` run computes the **size map only**; the churn × complexity
scatter, performance-gravity table, and the hotspot table's cognitive/maint./churn columns stay empty
until a scan that computes those sections is run. The render of those populated sections was not
separately screenshot-verified, but the code paths are present and the empty-state handling is verified.

---

## Already split out (do not duplicate here)

- **§3.2 Isolate worker pool** → `deferred/PROJECT_HEALTH_isolate_worker_pool.md` (cold-scan CPU
  parallelism; throughput-only, would destabilize the verified core for unmeasured gain).
- **§3.3 Adaptive huge-workspace auto-defaults** → `deferred/PROJECT_HEALTH_adaptive_huge_workspace.md`
  (auto-aggregate above a file-count threshold; no real-user trigger yet).
- **§3.4 SQLite results store** → `deferred/PROJECT_HEALTH_sqlite_store.md` (interactive full-set
  arbitrary-filter querying; NDJSON shards shipped, no code blocker — a capability choice gated on a
  real consumer + profiling + dependency approval).

---

## Finish Report (2026-06-24)

Project Health Phase-4 residuals are resolved: the one live verification item is closed and the last
inline deferral has been promoted to its own standing document, leaving no open items. The plan is
archived.

**Scope:** documentation/plan tracking only. No Dart rules, analyzer configuration, extension code, or
tests were touched.

**Changes:**

- **§3.1 render verification — closed.** The `--format html` report was rendered against the Saropa
  Contacts workspace (4011 files / 1.1M LOC) and confirmed correct against the Phase-4 design: brand
  banner, KPI chips, treemap size map with the orange LOC ramp and per-tile contrast text, the
  sortable/filterable hotspot table, dark mode, reduced-motion handling, the brand focus ring, skeleton
  removal, and the VS Code `openFile` bridge. The empty-state path is verified — the churn × complexity
  scatter and performance-gravity panels hide themselves when a scan computes size only, producing no
  false "all clear" tables. A bare `--format html` run computes the size map only; the populated
  scatter/gravity/complexity render was not separately screenshot-verified, but those code paths are
  present and the empty-state handling is confirmed.

- **§3.4 SQLite store — split to its own deferral doc.** The inline `[DEFERRED]` paragraph was promoted
  to `deferred/PROJECT_HEALTH_sqlite_store.md`, matching the format of the sibling deferrals (isolate
  worker pool, adaptive huge-workspace). It records what shipped instead (dependency-free NDJSON shards
  plus a provably-small in-memory aggregate index), why SQLite was not adopted (no consumer, new
  dependency is a permanent supply-chain commitment, the shard path already answers every shipped query),
  and the three-part trigger to un-defer (a real full-set interactive-filter consumer, profiling that
  shows the NDJSON disk pass is too slow, and explicit dependency approval).

**Outcome:** the TODO now lists only the four split-out deferrals (isolate pool, adaptive workspace,
SQLite store) under "Already split out" with one-line pointers. No live work remains.
