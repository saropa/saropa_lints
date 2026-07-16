# PLAN — Project Vibrancy: element-resolved cross-file Usage collector

**Created:** 2026-06-24
**Split from:** `TODO_vibrancy_residual_surfaces.md` §5.4 (parent TODO archived to `history/2026.06/2026.06.24/`)
**Source plan:** `history/2026.04/2026.04.28/project_vibrancy_report.md` (§ Usage / Orphan State, § Analyzer isolation, § Two-tier cache)
**Subsystem:** `lib/src/cli/project_vibrancy.dart` (Dart-side collector) + `extension/src/vibrancy/` (subprocess host)
**Status:** Phases 1-2 LANDED 2026-06-24 (element-resolved counts + entry-point exclusions, degrade-safe;
`lib/src/cli/project_vibrancy_resolved_usage.dart`, tests in `test/cli/project_vibrancy_resolved_usage_test.dart`).
Phases 3-5 (tree-SHA usage cache, dedicated killable/chunked subprocess, cascading unused) BLOCKED —
the precision review this plan gated on (Verification section, Phase-2 "Done when") ran 2026-07-16 and
FAILED. On this repo 326 `lib/` functions flag `unused`, ~50%+ false positives: 147 `@override` methods
and the entire `bin/`-called CLI surface. Root cause: the resolved pass builds one
`AnalysisContextCollection` over the repo root, which contains nested package roots (`self_check/`,
`example*/`, `packages/`, `build/test_tmp/…`); `contextFor` fails for `lib/` files, they are skipped, and
skipped files fall back to name-based counts with no entry-point protection. Filed as
`bugs/infra_vibrancy_unused_false_positives_context_fragmentation.md`. Fix the context construction and
`bin/`-scope defects (Phase 1-2 correctness), re-run the precision review, THEN decide Phases 3-5.

---

## Problem

The Usage signal feeds the vibrancy score (weight `W_U = 0.25`) and the `unused` flag. Today it is
**name-based**, not semantic: it counts how many times an identifier *string* appears, then attributes
every occurrence of `foo` to any function declared `foo`, regardless of which `foo` was actually called.

Current implementation (all syntactic — `parseString`, no resolved element model):

- [`_ReferenceVisitor`](../lib/src/cli/project_vibrancy.dart#L1115-L1126) collects raw `SimpleIdentifier.name`
  text; it never inspects `staticElement`.
- [`_collectReferenceCounts`](../lib/src/cli/project_vibrancy.dart#L870-L908) sums per-name occurrence
  counts across all files into one `name -> count` map.
- [`_computeUsageCounts`](../lib/src/cli/project_vibrancy.dart#L850-L868) attributes a function's count via a
  bare `referencesByName[fn.name]` lookup.
- [`unused` flag](../lib/src/cli/project_vibrancy.dart#L429) is set when that count is `0`.

### Failure modes this produces

1. **Name collision over-counting.** A private `_dispose` in 40 files all roll into one bucket; every
   one reads as heavily used even if a given `_dispose` has zero real callers. Hides true orphans.
2. **Shadowed / unrelated identifiers.** A local variable, parameter, named argument, or string-like
   identifier matching a function name inflates that function's count.
3. **No entry-point awareness.** Runtime-invoked symbols (`main`, `build`, `@pragma('vm:entry-point')`,
   framework lifecycle overrides) that are never *statically* referenced get mis-flagged `unused`.
4. **Cross-file staleness (already noted in source plan).** Usage is not content-local: deleting the
   only caller in `a.dart` changes `b.dart`'s reference count without changing `b.dart`'s bytes, so a
   per-file blob-SHA cache returns stale counts. Today's parse cache is keyed per-file → wrong for usage.

The source plan's status section already lists these as "not started": *analyzer element reference map,
entry-point exclusions, Tier-2 usage cache, cascading unused, usage collector in isolated subprocess
with NDJSON streaming.* This plan is that work.

---

## Goal

Replace name-string attribution with **element-resolved** reference counting: each reference resolves to
the declaration it actually binds to, counted against that declaration's stable id — so a function's
count reflects its real callers, and `unused` means "no static caller" with narrow, deliberate
entry-point exclusions.

Non-goal: changing the score formula, weights, buckets, or any other collector (age / coverage /
complexity / documentation). Usage attribution is the only behavior that changes.

---

## Constraints (hard)

- **Analyzer OOM hazard — subprocess only.** The resolved element model loads the whole project into an
  `AnalysisContext`; on a large project this is multi-GB and MUST NOT run in the extension host or
  in-process with the language server. Source plan § Analyzer isolation is non-negotiable: the resolved
  usage pass runs in a dedicated CLI subprocess with its own memory budget, streaming NDJSON to stdout.
- **Cross-file cache key is the git tree SHA, never a blob SHA.** Per source plan § Two-tier cache: the
  reverse-reference map is keyed on `git rev-parse HEAD^{tree}` (or a working-tree equivalent), not on
  any single file's content hash.
- **Degrade safe.** If resolution fails for a file/library (errors, missing part, SDK mismatch), fall
  back to the existing name-based count for the affected symbols and flag the run partial — never crash
  the scan, never silently drop a file to `unused`.
- **Err toward false negatives.** Missing a real orphan is acceptable; flagging live code `unused` is
  not (source plan § Risks). Entry-point exclusions and the degrade-safe fallback both bias this way.

---

## Phases

### Phase 1 — Resolved reference collection (core)

Replace the syntactic visitor with a resolved one, behind a new collector entry point so the name-based
path stays as the documented fallback.

1. Build resolved units via `AnalysisContextCollection` over the configured Dart roots (reuse the same
   root/exclusion set the syntactic pass uses in [`_collectTargetFiles`](../lib/src/cli/project_vibrancy.dart#L515)).
2. New visitor over each *resolved* `CompilationUnit`: for every reference, read its `staticElement`
   (method/function/accessor invocations, tear-offs, named-constructor refs), walk to the canonical
   `Element`, and emit `(declarationId, +1)`. Skip declaration contexts (as the current visitor does)
   and skip self-references inside the declaration's own body if the source plan's reference semantics
   require it (decide and document; default: count only references outside the declaration).
3. Map each resolved `Element` to the existing stable `_FunctionNode.id` (`filePath:name:offset`) so the
   downstream score/flag/JSON shape is unchanged. Where an element has no matching `_FunctionNode`
   (e.g. a getter not modeled as a function), document the gap; do not invent ids.
4. Attribution becomes `counts[fn.id] = resolvedRefs[fn.elementKey] ?? nameBasedFallback`.

**Done when:** a fixture with two same-named private functions in different files, one called once and
one never called, yields counts `1` and `0` (today both read non-zero). Unit test in `test/cli/`.

### Phase 2 — Entry-point exclusion set

Narrow, explicit list of runtime-invoked symbols excluded from `unused` (NOT from the usage score —
they still score on real refs; they are only protected from the orphan flag):

- `main()` (top-level), `@pragma('vm:entry-point')`-annotated declarations.
- Flutter/framework lifecycle overrides where the class extends a framework type: `build`,
  `initState`, `dispose`, `createState`, `didChangeDependencies`, etc. Detect via resolved supertype,
  not by method name alone (name-only would re-introduce the false-attribution bug).
- Anything overriding an external (SDK/package) member — `@override` against a non-project supertype is
  framework-driven and not statically callable from within the project.

**Done when:** a `StatefulWidget` whose `build`/`dispose` have no in-project caller is NOT flagged
`unused`; a plain private helper with no caller still IS. Fixture + test.

### Phase 3 — Tier-2 usage cache (tree-SHA keyed)

- Store: `.saropa/project-vibrancy-cache/usage/<tree-sha>.json` + a rolling `latest.json` pointer.
- Key: `git rev-parse HEAD^{tree}` for committed state; for a dirty tree, fall back to recompute (do not
  trust a stale entry — correctness over speed; source plan § Two-tier cache).
- Value: the full `declarationId -> callerFileSet` reverse map plus per-symbol counts, with
  `schemaVersion` + `collectorVersion`; unknown/newer schema → safe ignore + recompute.
- Keep this SEPARATE from the existing per-file parse cache ([`_parseCacheVersion`](../lib/src/cli/project_vibrancy.dart#L1158));
  never key cross-file usage under a per-file blob SHA.

**Done when:** editing a caller in `a.dart` (changing `b.dart`'s count without touching `b.dart`) busts
the usage cache and recomputes; a no-op rescan at the same tree SHA is a cache hit.

### Phase 4 — Subprocess isolation + NDJSON streaming

- New CLI mode: `dart run saropa_lints:project_vibrancy --collect-usage --tree-sha <sha>` runs ONLY the
  resolved usage pass in a child process, streaming `{event, phase:'usage', ...}` NDJSON to stdout
  (reuse the existing `ProjectScanProgress.onEvent` envelope shape from
  [`_collectReferenceCounts`](../lib/src/cli/project_vibrancy.dart#L877-L904)).
- Extension host spawns this child, parses NDJSON, merges the resulting counts back into the report;
  the child is killable and memory-bounded. Extension NEVER runs the resolved pass in-process.
- Chunking inside the subprocess for projects that still OOM (source plan § Analyzer isolation):
  process libraries in batches, persisting each batch's partial map before the next.

**Done when:** the resolved pass runs end-to-end from the extension via the child process on this repo,
NDJSON progress reaches the existing progress bar, and the extension host RSS does not spike (manual
check; the whole reason for the subprocess).

### Phase 5 — Cascading unused (enrichment, optional within this plan)

Once a symbol is a confirmed orphan, re-run attribution with that symbol's own outbound references
removed; symbols that become zero-caller *only because* a dead symbol referenced them surface as
cascade orphans. Lower priority — land Phases 1–4 first; split to its own follow-up if it grows.

---

## Verification

- Per-phase fixtures + `test/cli/` unit tests as named above. Scope `dart test --no-pub` to the one new
  test file (background it).
- Validate `unused` precision on this repo: spot-check a sample of flagged symbols are truly orphaned
  (no false positives on framework callbacks) before considering Phase 2 done.
- Confirm the report JSON shape (`usage`, `usageCount`, flags) is byte-stable for symbols whose real
  caller count did not change — the upgrade must not churn unrelated rows.

## Risks

- **Resolution cost / OOM** — mitigated by Phase 4 subprocess + chunking; this is the headline risk.
- **Entry-point list maintenance** — the exclusion set is the highest-leverage and most error-prone
  piece; under-excluding flags live code, over-excluding hides real orphans. Keep it small, resolved-
  supertype-driven, and test-covered.
- **Cache correctness** — a wrong key silently returns stale counts; the tree-SHA discipline and
  dirty-tree-recompute fallback are the guardrails.

## Blast radius (needs sign-off before building)

This adds: a resolved-analyzer code path (heavier dependency on analyzer element APIs), a new CLI flag
+ child-process protocol, and a second on-disk cache tier. It is a multi-part feature, not a local fix —
do not start without explicit go-ahead on scope and phase ordering.

---

## Finish Report (2026-06-24)

**Scope delivered:** Phases 1 (resolved reference collection) and 2 (entry-point exclusion set). Phases 3-5
(tree-SHA usage cache, dedicated killable/chunked subprocess, cascading unused) remain OPEN and deferred,
pending a precision review of the resolved `unused` flag on real repositories.

**Why this plan stays in `plans/` rather than moving to history:** the majority of the plan (three of five
phases, including the headline OOM/cache hardening) is still open and this document remains their live
tracking record. Splitting Phases 3-5 into a new file would duplicate the problem/goal/constraints framing
verbatim for no gain. The Status line at the top records the partial-completion state.

### What changed

The Usage signal was name-based: `_computeUsageCounts` attributed `referencesByName[fn.name]`, so every
occurrence of an identifier *string* rolled into one bucket keyed by name. A private `_dispose` declared in
many files all read as heavily used (the count of every `_dispose` reference anywhere), and shadowed locals,
parameters, and named-argument labels matching a function name inflated that function's count — hiding true
orphans and producing wrong caller counts on collisions.

A new collector, `lib/src/cli/project_vibrancy_resolved_usage.dart`, resolves the project element model via
`AnalysisContextCollection` and counts each reference against the declaration it actually binds to:

- Each reference's element is canonicalized with `Element.baseElement.nonSynthetic` (unwrapping generic
  `Member` instantiations and synthetic accessors) so a reference and its declaration key to the same map
  entry. Declarations are keyed by the same `filePath:name:lineStart` id the parse phase builds for
  `_FunctionNode`, so the score loop's `countsById[fn.id]` lookup matches with no second id scheme.
- Self/recursive references are excluded via an enclosing-declaration stack (the source plan counts only
  references *outside* a declaration's own body).
- An entry-point set is computed for declarations that are runtime-invoked, not statically called:
  top-level `main`, `@pragma('vm:entry-point')`, and any `@override` member (detected from resolved
  `Element.metadata.hasOverride`, never by method name). Overrides are reached polymorphically through the
  supertype, so a zero static-caller count is expected for them; the set protects them from the `unused`
  flag only (they still score on real references). Protecting *all* overrides — not just named lifecycle
  hooks — is the deliberate false-negative bias the constraints require.

Integration in `runProjectVibrancy`: the resolved pass runs after the name-based pass. `_mergeUsageCount`
reconciles them, biased to never flag live code dead — no resolved data, or a declaration absent from the
resolved set (its file failed to resolve), yields the name-based count; a resolved count `> 0` is trusted;
a resolved count `0` is trusted only when every file resolved (`fullyResolved`), otherwise it falls back to
the over-counting name-based value. The `unused` flag now also skips entry points. On any resolution failure
the collector returns `null` and the scan keeps its prior name-based behavior unchanged.

The resolved pass runs inside the existing `project_vibrancy` CLI child process (already spawned by the
extension), so it does not load the element model in the extension host — satisfying the source plan's
analyzer-isolation constraint for Phases 1-2 without the Phase 4 dedicated subprocess. Phase 4 remains the
OOM guard (chunking, a killable child) for very large consumer repositories.

### Verification

- `test/cli/project_vibrancy_resolved_usage_test.dart` (new, 3 tests, all passing): two same-named private
  functions in different files yield counts `1` and `0` (name-based read both as used — the Phase-1
  "Done when"); a self-recursive function reads `0` (unused); `@override` / `@pragma('vm:entry-point')` /
  top-level `main` with zero static callers are not flagged `unused`, while a plain private orphan still is
  (the Phase-2 "Done when").
- Existing `test/cli/project_vibrancy_cli_test.dart` (19 tests) and
  `test/cli/project_vibrancy_coverage_quality_test.dart` re-run green: the caller/callee and no-caller
  `unused` assertions agree with the resolved path on unambiguous cases, confirming no regression.
- Command: `dart test test/cli/project_vibrancy_resolved_usage_test.dart` and
  `dart test test/cli/project_vibrancy_cli_test.dart test/cli/project_vibrancy_coverage_quality_test.dart`.
