# BUG: `prefer_reusing_assigned_local` — flags an intentional live-getter re-read across an `await`

**Status: Fixed**

Created: 2026-06-05
Rule: `prefer_reusing_assigned_local`
File: `lib/src/rules/code_quality/unnecessary_code_rules.dart` (line ~1145)
Severity: False positive / High (the "reuse" the rule suggests is a real bug — it reintroduces use-of-context-across-async-gap)
Rule version: v1

---

## Summary

A retry loop re-reads `appGlobalNavigatorKey.currentContext` into a fresh local on each iteration, after an `await Future.delayed(...)`. The rule sees the same source text as an earlier `currentContext` read in the enclosing block and tells the author to reuse that earlier local. Doing so would be wrong twice over: `currentContext` is a live getter whose value changes (null → mounted) as the navigator boots during the delay, and reusing a value captured before the `await` reintroduces exactly the cross-async-gap context use that `use_build_context_synchronously` forbids (the fresh-per-iteration read exists to satisfy that other lint).

---

## Attribution Evidence

```bash
grep -rn "'prefer_reusing_assigned_local'" lib/src/rules/
# lib/src/rules/code_quality/unnecessary_code_rules.dart:1162:    'prefer_reusing_assigned_local',

grep -rn "'prefer_reusing_assigned_local'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/code_quality/unnecessary_code_rules.dart:1162`
**Rule class:** `PreferReusingAssignedLocalRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#4`

---

## Reproducer

```dart
Future<void> handleNotificationTap() async {
  final BuildContext? context = appGlobalNavigatorKey.currentContext; // first read
  if (context != null && context.mounted) {
    await showSomeScreen(context: context);
    return;
  }

  // Cold start: navigator not mounted yet. Retry, RE-READING currentContext
  // each iteration — its value changes as the navigator boots during the delay.
  for (int i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final BuildContext? retryContext =
        appGlobalNavigatorKey.currentContext; // LINT — but must NOT reuse the first local
    if (retryContext != null && retryContext.mounted) {
      await showSomeScreen(context: retryContext);
      return;
    }
  }
}
```

**Frequency:** Always, when the same pure-looking property/getter chain is read in an outer block and re-read inside a nested loop/block that contains an `await` before the re-read.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the re-read is intentional; the value legitimately differs across the `await`, and reusing the earlier local is a bug |
| **Actual** | `[prefer_reusing_assigned_local]` reported on the `appGlobalNavigatorKey.currentContext` re-read |

---

## AST Context

```
MethodDeclaration (handleNotificationTap)
  └─ Block (method body)              ← addBlock fires here; firstDecls = { "appGlobalNavigatorKey.currentContext": context }
      ├─ VariableDeclarationStatement (context = appGlobalNavigatorKey.currentContext)
      └─ ForStatement
          └─ Block (loop body)        ← walked by block.accept(scanner)
              ├─ ExpressionStatement (await Future.delayed(...))   ← suspension point, NOT a barrier
              └─ VariableDeclarationStatement
                  └─ VariableDeclaration (retryContext)
                      └─ PrefixedIdentifier (appGlobalNavigatorKey.currentContext)  ← reported here
```

---

## Root Cause

In `runWithReporter` (line ~1178), `firstDecls` is keyed on `initializer.toSource()` (the source text). The `_BlockReuseScanner` then walks the whole block — **including nested blocks** (`block.accept(scanner)`, line 1212) — collecting every occurrence of that text. `mutationBarrierFor` (line 1218) advances the barrier only when one of the initializer's referenced *identifier names* (`appGlobalNavigatorKey`, `currentContext`) is **assigned**. An intervening `await` is not an assignment, so no barrier is set, and the nested re-read is flagged.

Two compounding gaps:

1. **`await` is not treated as a barrier.** A suspension point lets external state change between reads even when no in-scope identifier is written. `appGlobalNavigatorKey.currentContext` returns different values before vs. after the navigator mounts.
2. **`currentContext` is classified as a reusable pure read.** `_isReusableInitializer` (line 1250) accepts any `PrefixedIdentifier`, and `_InitializerPurityVisitor` has no notion that a framework live getter (`GlobalKey.currentContext`, `.currentState`, etc.) returns time-varying state.

### Hypothesis A (preferred): treat `await` as a reuse barrier

In `mutationBarrierFor`, also lower the barrier to the offset of the first `AwaitExpression` that lies between the declaration and a candidate reuse. Across a suspension point the cached value is no longer guaranteed redundant. This is the minimal, general fix and also covers any other live state re-read after an `await`.

### Hypothesis B: exclude known time-varying getters from `_isReusableInitializer`

Reject initializers ending in `.currentContext` / `.currentState` / `.currentWidget` on a `GlobalKey`, and similar live getters. Narrower; does not cover non-framework cases that Hypothesis A handles.

---

## Suggested Fix

Implement Hypothesis A: add an `await`-aware barrier. When scanning, record the offset of each `AwaitExpression`; in the reuse loop (line 1223), skip any `reuse` whose offset is greater than the earliest `await` offset following `local.initializer.end`. Combine with Hypothesis B if framework-getter purity should also be tightened.

---

## Fixture Gap

The fixture should include:

1. **Pure read re-read after an `await`** — expect NO lint (this bug).
2. **Pure read re-read in a loop with no `await` and no mutation** — expect LINT (genuine redundancy stays flagged).
3. **`GlobalKey.currentContext` read twice with no await** — decide intended behavior; if Hypothesis B is adopted, expect NO lint.

---

## Environment

- saropa_lints version: 13.12.0
- Triggering project/files: `d:\src\contacts\lib\service\notification\notification_service_init.dart:567,602`; `d:\src\contacts\lib\service\notification\content\birthday_notification_service.dart:243`

---

## Finish Report (2026-06-05)

Implemented **Hypothesis A** (treat `await` as a reuse barrier) — the general, minimal fix that covers any live state re-read after a suspension point, not just framework getters. Hypothesis B (a `currentContext`/`currentState` purity blocklist) was not needed: with the await barrier in place the reproducer no longer fires, and a same-block `GlobalKey.currentContext` read twice with no intervening `await` is a genuine redundancy that should still flag.

### Changes

- `lib/src/rules/code_quality/unnecessary_code_rules.dart`
  - `_BlockReuseScanner` now records every `AwaitExpression` offset (`_awaitOffsets`, `visitAwaitExpression`) and exposes `awaitBarrierFor(afterOffset:)` returning the earliest `await` past the declaration.
  - `runWithReporter` lowers the reuse barrier to `min(mutationBarrier, awaitBarrier)`, so any occurrence after the first intervening `await` is skipped.
- `example/lib/unnecessary_code/prefer_reusing_assigned_local_fixture.dart`
  - Added `goodReReadAcrossAwait` (re-read after `await` — must NOT lint) and `badLoopNoAwait` (re-read in a loop with no `await` — must still lint).

### Verification

Scanned the fixture via `dart run saropa_lints scan` (comprehensive tier): the across-`await` re-read is no longer reported; the no-`await` loop recompute and the three original BAD cases still flag. `dart analyze` clean on the rule file.

(The fixture's `goodShadowedNestedClosure` still reports under the scan CLI — that is the separate, already-tracked shadowed-nested-builder false positive, unrelated to this fix.)
