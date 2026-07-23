# DEFERRED — Project Vibrancy usage: tree-SHA cache, killable subprocess, cascading unused

**Deferred:** 2026-07-16
**Flavor:** blocked — depends on an unfixed precision defect in the layer below.
**Parent plan (archived):** `plans/history/2026.07/2026.07.16/PLAN_vibrancy_usage_collector_element_resolution.md`
**Blocking bug:** `bugs/infra_vibrancy_unused_false_positives_context_fragmentation.md`

## Why deferred

These were Phases 3-5 of the element-resolved usage plan. Phases 1-2 (resolved reference counts +
entry-point exclusions) landed 2026-06-24. The plan gated Phases 3-5 on a precision review of the
resolved `unused` flag on a real repo. That review ran 2026-07-16 and FAILED: on this repo, 326
`lib/` functions flag `unused`, ~50%+ of them false positives (147 `@override` methods and the
entire `bin/`-called CLI surface). Root cause is context fragmentation in the resolved pass — the
analyzer context is built over the repo root, `contextFor` fails for `lib/` files, they are skipped,
and skipped files fall back to name-based counting with no entry-point protection.

Every phase below hardens or extends the resolved `unused` signal. Building any of them now means
investing in caching, process isolation, and cascade logic around a signal that is wrong half the
time. They are blocked until the blocking bug is fixed and the precision review is re-run clean.

## Deferred items (each blocked on the same precision fix)

1. **Tier-2 usage cache (tree-SHA keyed).** Cache the reverse-reference map under
   `git rev-parse HEAD^{tree}` so cross-file usage recomputes only when the tree changes. Blocked:
   caching an inaccurate reverse map just serves wrong `unused` verdicts faster. No value until the
   map is correct.
2. **Dedicated killable/chunked subprocess + NDJSON streaming.** Run the resolved pass in its own
   memory-bounded, cancelable child process, chunking libraries to survive OOM on large consumer
   repos. Blocked: the OOM hazard is real (the `build/test_tmp/` tree already bloats the context),
   but process isolation is orthogonal hardening — pointless to build around a pass that currently
   skips most files. Fix context construction first; that likely also shrinks the memory footprint.
3. **Cascading unused (enrichment).** After confirming an orphan, re-run attribution with its own
   outbound refs removed to surface second-order orphans. Blocked: cascade logic amplifies whatever
   the base `unused` set contains — on a 50%-false-positive base it manufactures more false
   positives, not insight.

## To resurrect

1. Fix `bugs/infra_vibrancy_unused_false_positives_context_fragmentation.md` (scope the analyzer
   context to the package; include `bin/` in the target set; protect entry points on the degrade
   path).
2. Re-run the precision review: `dart run saropa_lints:project_vibrancy --path . --format json`,
   confirm `@override` methods and `bin/`-called functions no longer flag `unused`.
3. Only then re-open these three items — new file in `plans/`, referencing this record.
