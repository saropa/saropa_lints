# BUG: project vibrancy `unused` flag — resolved-usage pass degrades on multi-package repos, reintroducing false positives

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-07-16
Component: `lib/src/cli/project_vibrancy_resolved_usage.dart` (element-resolved usage collector) + `lib/src/cli/project_vibrancy.dart` (merge / flag application)
Severity: False positive
Since: Phases 1-2 of `plans/PLAN_vibrancy_usage_collector_element_resolution.md` (landed 2026-06-24)

---

## Summary

Running `dart run saropa_lints:project_vibrancy` on this repo flags **326 `lib/` functions
`unused`, of which at least ~165 (50%+) are false positives** — live code with real callers.
The element-resolved usage pass (Phases 1-2) is meant to prevent exactly this, but it degrades
on a repo whose root contains nested package roots: files fail context lookup, get skipped, and
fall back to name-based counting with no entry-point protection. Polymorphic-only methods (every
`@override`) then name-count to `0` and are flagged dead.

This is the precision-review result that gates Phases 3-5 of the plan (tree-SHA cache, killable
subprocess, cascading-unused). Those phases harden a signal that is presently wrong half the time
on its own home repo. Fix this first; do not build the hardening around an inaccurate flag.

---

## Attribution Evidence

The collector is this repo's own CLI code — no cross-repo ambiguity.

```bash
grep -rn "collectResolvedUsage\|entryPointIds" lib/src/cli/
# lib/src/cli/project_vibrancy_resolved_usage.dart — defines collectResolvedUsage, ResolvedUsage, entryPointIds
# lib/src/cli/project_vibrancy.dart:352,449 — calls it, applies the unused flag
```

**Merge / flag application:** `lib/src/cli/project_vibrancy.dart:449-450`
**Resolved collector:** `lib/src/cli/project_vibrancy_resolved_usage.dart`
**Entry-point predicate:** `lib/src/cli/project_vibrancy_resolved_usage.dart:260-269` (`_isEntryPoint`)

---

## Reproducer

Run the vibrancy scan on this repo and count `lib/` symbols flagged `unused`:

```bash
dart run saropa_lints:project_vibrancy --path . --format json > vibrancy.json
# functions scored: 25198 ; unusedCount: 4959 (4618 are example/ fixtures — expected)
# lib/ (shipped code) flagged unused: 326
```

Classification of the 326 `lib/` flags (excluding a vendored report ndjson):

| Class | Count | False positive? |
|---|---|---|
| `@override` methods (framework/registry, invoked polymorphically) | 147 | Yes — Phase 2 is meant to exclude these |
| Functions whose only caller is in `bin/*.dart` (CLI delegates) | 18+ | Yes — live CLI surface |
| Remaining (engine-internal / public API called from bin/scripts) | 161 | Mostly yes on inspection |

Confirmed live examples flagged `unused`:

- `runInit` (`lib/src/init/init_runner.dart:90`) — sole caller `bin/init.dart`.
- `findDuplicateLineBlocks` (`lib/src/cli/cross_file_duplicates.dart:26`) — sole caller `bin/cross_file.dart`.
- `buildHealthReport` (`lib/src/cli/project_health/health_export_json.dart:14`) — sole caller `bin/project_health.dart`.
- `addWithClause`, `addAdjacentStrings`, … (`lib/src/scan/capturing_registry.dart`) — `@override` registry methods.

**Frequency:** Always, on any repo whose root contains nested package roots (see Root Cause).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `@override` members and runtime/CLI entry points are NOT flagged `unused`; the degrade-safe design biases toward false negatives (a missed orphan), never toward flagging live code. |
| **Actual** | 147 `@override` methods and the entire `bin/`-called CLI surface are flagged `unused`. |

---

## Evidence: the override exclusion logic is sound in isolation

A focused probe resolved `lib/src/scan/capturing_registry.dart` through its OWN single-file
`AnalysisContextCollection` and read each method's resolved element:

```
addAdjacentStrings   offsetLine=44  elemHasOverride=true  astHasOverride=true  elemNull=false
addAnnotation        offsetLine=46  elemHasOverride=true  astHasOverride=true  elemNull=false
...
```

So when a file DOES resolve: `element.metadata.hasOverride` returns `true`, the element is
non-null, and `node.offset` maps to the method's own line (44) — the exact line the parse phase
uses for `_FunctionNode.id`. The entry-point id and the function id therefore match, and the
exclusion at `project_vibrancy.dart:449` works. The bug is not in the override detection.

---

## Root Cause

`collectResolvedUsage` builds ONE `AnalysisContextCollection` with `includedPaths: [projectRoot]`
(`project_vibrancy_resolved_usage.dart:91-94`). This repo's root contains many nested package
roots, each with its own `pubspec.yaml` / `analysis_options.yaml`:

```
./self_check/pubspec.yaml
./example/pubspec.yaml
./example_packages/pubspec.yaml
./packages/saropa_lints_api/pubspec.yaml
./build/test_tmp/saropa_hist_*/…   (dozens of full package copies)
```

The analyzer splits these into multiple analysis contexts under the one collection. For a `lib/`
file, `collection.contextFor(driverPath)` then fails to map it to a context — reproduced directly:

```
Unhandled exception:
Bad state: Unable to find the context to D:\src\saropa_lints\lib\src\scan\capturing_registry.dart
  at AnalysisContextCollectionImpl.contextFor
```

The collector's per-file `try { contextFor(...) } on Object { fullyResolved = false; continue; }`
(`project_vibrancy_resolved_usage.dart:109-122`) swallows this and **skips the file**. A skipped
file produces neither a resolved count nor an `entryPointIds` entry. Downstream, for every symbol
in a skipped file:

1. `_mergeUsageCount` (`project_vibrancy.dart:937-941`) sees `resolvedCount == null` and returns
   the **name-based** count.
2. `isEntryPoint` (`project_vibrancy.dart:449`) is `false` — the id was never added to
   `entryPointIds`.

For a method invoked only polymorphically (all `@override` registry/framework methods) the
name-based count is `0` because the identifier is never written literally in project source. So
`usageCount == 0 && !isEntryPoint` → `unused` flagged. The degrade path reintroduces precisely
the false positive Phases 1-2 exist to remove.

The `bin/`-only class has an adjacent cause: `targetFiles` is "lib + test" only
(`project_vibrancy_resolved_usage.dart:66`; `bin/` excluded), so a lib function called solely from
a `bin/` entry point has no in-scope caller in either the resolved or the name-based pass.

Net: on any multi-package repo the resolved pass is largely inert (context fragmentation skips
files), and the name-based fallback carries its original blind spots — polymorphic dispatch and
out-of-target-scope callers — straight into the `unused` verdict.

---

## Suggested Fix

Not implemented (bug report only). Direction:

1. **Constrain the analysis context to the package under test.** Build the collection over the
   actual Dart roots (`lib/`, `test/`, `bin/`), or exclude `build/`, `example*/`, `self_check/`,
   `packages/` from `includedPaths`, so `contextFor` resolves `lib/` files instead of failing.
   The `_collectTargetFiles` root/exclusion set already used by the syntactic pass is the model
   (plan Phase 1, step 1).
2. **Include `bin/` in the resolved target set** so CLI-delegate functions get real caller counts,
   OR treat top-level `bin/` entry files and their transitively-referenced public symbols as entry
   points.
3. **Make the degrade path honest about entry points.** When a file is skipped, its `@override`
   members should still be protected from `unused` — either resolve entry-point status
   syntactically as a fallback, or refuse a `0` verdict for any skipped file (the constraint already
   says: never flag live code dead).
4. Consider surfacing `fullyResolved == false` in the report so a heavily-degraded run does not
   present name-based guesses as resolved truth.

---

## Verification

- `dart run saropa_lints:project_vibrancy --path . --format json` → count `lib/` `unused` flags
  before/after; the 147 `@override` and the `bin/`-called functions must drop out.
- Single-file resolution probe (above) confirms `hasOverride` and id alignment are correct when a
  file resolves — the fix target is context construction, not the override predicate.
- Existing tests in `test/cli/project_vibrancy_resolved_usage_test.dart` pass because their
  fixtures are single small files where `contextFor` succeeds; add a fixture with a nested package
  root (or a `bin/`-only caller) to cover the degrade path this bug exposes.

---

## Related

- Plan: `plans/PLAN_vibrancy_usage_collector_element_resolution.md` — this bug is the "precision
  review" its Verification section and Phase-2 "Done when" require before Phases 3-5 proceed.
