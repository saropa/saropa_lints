# Project Health: SQLite results store (interactive full-set filtering)

**Severity**: Capability choice — not a fix, not a blocker
**Date deferred**: 2026-05-24 (decision); split to its own doc 2026-06-24
**Status**: Deferred — revisit only if interactive arbitrary-filter querying over the full row set is actually requested
**Parent plan**: [../PROJECT_HEALTH_DASHBOARD_PLAN.md](../PROJECT_HEALTH_DASHBOARD_PLAN.md)

---

## Goal

Replace (or back) the on-disk results store with SQLite so the dashboard can run
interactive, arbitrary-filter queries over the **full** `FileHealth` row set
(e.g. "all files >300 LOC AND <40% coverage AND touched in the last 30 days,
sorted by complexity") without a full re-scan or a streaming two-pass.

## What shipped instead — NDJSON shards

Decided 2026-05-24 (dependency-free, approved):

- Each scan writes append-only `*.ndjson` shards under
  `reports/.saropa_lints/health/`.
- An **in-memory aggregate index** — folder rollups, bounded quantile sketches,
  top-N heaps — is built in the single streaming pass. It is provably small:
  O(folders) + fixed-size sketches/heaps, **never** O(files) of full rows.
- Windowed file-level detail is served by seeking the relevant shard.
- Zero new dependencies; peak RSS stays roughly flat from 5k to 50k files.

This fully covers the default report (top-N / above-threshold) and drill-down.
The gap it does NOT cover is ad-hoc full-set filtering on arbitrary column
combinations — which today requires a disk pass over the shards rather than an
indexed query.

## Why it was deferred

Quoted from the parent plan:

> SQLite is **not** adopted now; revisit only if profiling later shows
> interactive arbitrary-filter queries over the full row set need a real index —
> and that would be a separate, approved decision.

- No code blocker — the NDJSON store is complete and verified; this is a
  capability choice, not a missing piece.
- A new dependency is a permanent supply-chain commitment (blast-radius gate);
  not worth it for a use case no user has requested.
- "Cheap before heavy": the shard + seek path already answers every query the
  shipped dashboard issues.

## Trigger to un-defer

All of:

- A real consumer needs interactive arbitrary-filter querying over the **full**
  row set (not top-N, not a single folder drill-down), AND
- Profiling shows the NDJSON disk pass is too slow for that interactive use, AND
- The new dependency is explicitly approved (blast-radius gate).

Without all three, this stays deferred.

## Design sketch (when un-deferred)

- Write rows to a SQLite file under `reports/.saropa_lints/health/` alongside (or
  instead of) the shards; keep the same versioned schema (`schemaVersion`) as the
  JSON/NDJSON export so consumers stay compatible.
- Index the columns interactive filters actually use (LOC, coverage, complexity,
  last-touched) — measured from real filter usage, not speculation.
- Keep the streaming aggregate index for first paint; SQLite serves only the
  full-set ad-hoc query path, so the verified streaming core is unchanged.
- Additive, not a rewrite: the shard path remains the fallback.

## Risks

- New dependency — permanent commitment; must clear the blast-radius gate.
- Schema drift between the JSON/NDJSON export and the SQLite table — keep one
  versioned schema definition as the single source of truth.
- Reworking the verified store for an unmeasured gain — any work here must be
  additive and leave the streaming core intact.
