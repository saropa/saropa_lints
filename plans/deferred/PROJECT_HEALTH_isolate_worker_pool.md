# Project Health: Isolate Worker Pool (CPU parallelism for cold scans)

**Severity**: Optimization — throughput-only
**Date deferred**: 2026-05-25
**Status**: Deferred — revisit only if cold scans on huge monorepos prove too slow in practice
**Parent plan**: [../PROJECT_HEALTH_DASHBOARD_PLAN.md](../PROJECT_HEALTH_DASHBOARD_PLAN.md)

---

## Goal

Parallelize the cold-scan per-file parse across CPU cores using an isolate worker
pool, so a first-time scan of a huge project finishes faster on multi-core
machines.

## Why it was deferred

Quoted from the parent plan:

> The only planned item intentionally NOT built. It would parallelize the
> cold-scan parse across CPU cores. Deferred because:
>
> (a) memory is already flat (the streaming design), so this is throughput-only;
>
> (b) `--cache` already makes rescans fast;
>
> (c) it would rework `runSizeScan` — the verified core every other feature
>     depends on — and parsed AST can't cross isolate boundaries, so workers
>     must receive file CONTENT (a copy per in-flight file), reintroducing a
>     memory trade-off;
>
> (d) the speedup is unmeasurable here without a multi-core benchmark.
>
> "Cheap before heavy": not worth destabilizing the verified core for an
> unverified gain. Revisit only if cold scans on huge monorepos prove too slow
> in practice.

## Trigger to un-defer

- A real user reports cold-scan time as painful on a monorepo (10k+ files), AND
- Profiling shows parse CPU is the bottleneck (not git, not lcov, not analyzer
  resolution), AND
- A reproducible benchmark exists so a "before / after" speedup can be measured
  honestly.

Without all three, this stays deferred — speculative optimization against the
verified core is exactly the "cheap before heavy" anti-pattern the parent plan
calls out.

## Design sketch (when un-deferred)

- Reuse the existing batching in
  [project_context_parallel_batch.dart](../../lib/src/project_context_parallel_batch.dart).
- Workers receive file CONTENT (not AST — AST can't cross isolate boundaries)
  and return small result records (paths + numbers).
- Cap pool size at `cores - 1` with a hard upper bound; never let it grow with
  file count.
- Heavy resolution (cross-file unused symbols, LCOM) stays in the main
  isolate's single shared analyzer context — only cheap parsed-AST metrics
  parallelize.
- Memory budget must remain bounded: in-flight content × pool size, not whole
  project.
- Acceptance: measured speedup on a real benchmark; peak RSS not materially
  higher than the streaming serial baseline; verified core (`runSizeScan`)
  still passes the existing 76-test suite.

## Risks

- Reworking the verified core for an unmeasured gain — the parent plan's
  primary objection. Any work here must be additive (a new path the existing
  serial path can fall back to), not a rewrite.
- Memory regression from content copying — must be benchmarked, not assumed.
- Determinism — parallel scan must produce identical output for the
  baseline/diff feature to remain useful.
