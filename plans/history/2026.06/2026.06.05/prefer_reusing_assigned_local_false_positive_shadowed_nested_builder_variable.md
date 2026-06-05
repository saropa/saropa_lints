# BUG: `prefer_reusing_assigned_local` — matches expression text across a shadowed nested-scope variable

**Status: Fixed**

Created: 2026-06-05
Rule: `prefer_reusing_assigned_local`
File: `lib/src/rules/code_quality/unnecessary_code_rules.dart` (line ~1145)
Severity: False positive / High (suggested "reuse" would substitute a different variable of a different type → wrong value or compile error)
Rule version: v1

---

## Summary

An outer builder closure declares `final x = snapshot.snapLoadingProgress();` (and `final c = snapshot.data;`). A **nested** builder closure — a `FutureBuilder` inside the outer `StreamBuilder` — has its own parameter also named `snapshot`, of a different type, and reads `snapshot.snapLoadingProgress()` / `snapshot.data`. The rule keys occurrences by source text, so it matches the inner reads to the outer locals and reports them as redundant recomputes. They are not: the inner `snapshot` is a different variable (different element, different generic type) that shadows the outer one. Reusing the outer local would read the wrong snapshot (and fail to compile where the types differ).

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
Widget build(BuildContext context) {
  return StreamBuilder<List<Foo>?>(
    stream: _fooStream,
    builder: (BuildContext context, AsyncSnapshot<List<Foo>?> snapshot) {
      final Widget? snapWaiting = snapshot.snapLoadingProgress(); // outer read
      if (snapWaiting != null) return snapWaiting;
      final List<Foo>? foos = snapshot.data;                      // outer read

      return FutureBuilder<List<Bar>?>(
        future: _barsFuture,
        builder: (BuildContext context, AsyncSnapshot<List<Bar>?> snapshot) { // SHADOWS outer snapshot, different type
          final Widget? innerWaiting = snapshot.snapLoadingProgress(); // LINT — but different variable
          if (innerWaiting != null) return innerWaiting;
          final List<Bar> bars = snapshot.data ?? Bar.values;          // LINT — but different variable
          return SomeWidget(foos: foos, bars: bars);
        },
      );
    },
  );
}
```

**Frequency:** Always, when a nested closure re-binds an identifier (commonly `snapshot`, `context`, `value`) that an outer block already declared/bound, and the same member expression text appears in both scopes.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the inner `snapshot` is a distinct, shadowing variable; the reads are not recomputes of the outer local |
| **Actual** | `[prefer_reusing_assigned_local]` reported on the inner `snapshot.snapLoadingProgress()` and `snapshot.data` |

---

## AST Context

```
Block (outer StreamBuilder builder body)        ← addBlock; firstDecls keyed on "snapshot.snapLoadingProgress()", "snapshot.data"
  ├─ VariableDeclarationStatement (snapWaiting = snapshot.snapLoadingProgress())   [outer snapshot]
  ├─ VariableDeclarationStatement (foos = snapshot.data)                           [outer snapshot]
  └─ ReturnStatement → FunctionExpression (inner builder)
      └─ FormalParameterList: (BuildContext context, AsyncSnapshot<List<Bar>?> snapshot)  ← RE-BINDS `snapshot`
          └─ Block (inner builder body)          ← walked by block.accept(scanner)
              ├─ MethodInvocation (snapshot.snapLoadingProgress())  ← reported here (inner snapshot)
              └─ PropertyAccess (snapshot.data)                     ← reported here (inner snapshot)
```

---

## Root Cause

`firstDecls` (line ~1186) is keyed on `initializer.toSource()` — pure text. `_collectReferencedNames` (line 1277) records referenced identifiers by **lexeme** (`snapshot`), not by resolved element. The `_BlockReuseScanner` walks nested function bodies (`block.accept(scanner)`, line 1212) and matches the same text inside the inner builder. `mutationBarrierFor` only lowers the barrier on **assignment** to a referenced name; a nested **re-declaration** (a closure parameter shadowing the name) is not an assignment, so no barrier is set and the inner occurrence is flagged.

The rule never confirms that `snapshot` in the inner occurrence resolves to the **same element** as `snapshot` in the original declaration. Shadowing makes the text identical but the binding different.

### Hypothesis A (preferred): compare by resolved element, not text

For each candidate reuse, resolve the receiver/identifier(s) to their `staticElement` and confirm they match the elements referenced by the original declaration's initializer. If any referenced identifier resolves to a different element (shadowed), do not report.

### Hypothesis B: stop scanning at a scope that re-declares a referenced name

When the scanner enters a `FunctionExpression` / nested scope whose parameters or local declarations introduce any name in `local.referencedNames`, skip occurrences within that scope.

---

## Suggested Fix

Hypothesis A is the robust fix and also hardens the rule against any same-text/different-element case. In the reuse loop (line 1223), before `reporter.atNode(reuse)`, walk the reuse expression's identifiers and require each to resolve to the same `Element` as in the declaration; bail if any differs. Hypothesis B is a cheaper guard if element resolution is unavailable in this pass.

---

## Fixture Gap

The fixture should include:

1. **Nested builder shadowing `snapshot`, same member text in both scopes** — expect NO lint (this bug).
2. **Same-element genuine recompute in one scope** — expect LINT (regression guard).
3. **Nested closure shadowing `context`/`value` with identical member reads** — expect NO lint.

---

## Environment

- saropa_lints version: 13.12.0
- Triggering project/file: `d:\src\contacts\lib\views\contact\contact_audit_issues_screen.dart:289,296`

---

## Finish Report (2026-06-05)

Implemented **Hypothesis A** (compare by resolved element, not text).

**Fix** — `lib/src/rules/code_quality/unnecessary_code_rules.dart`:
- Added a `_sameBindings(declInit, reuse)` guard in the reuse loop, called before `reporter.atNode(reuse)`. Because an occurrence is matched to a declaration by `toSource()` equality, the two expressions have identical AST shapes and therefore identical in-order identifier sequences, so the guard compares resolved `Element`s position-by-position via a new `_IdentifierElementCollector`.
- A mismatch only counts when **both** identifiers resolve to a non-null element and those elements differ — unresolved identifiers (members read off a `dynamic` receiver) leave existing behavior unchanged, preserving the true positives that depend on text matching.
- Bumped the problem-message version marker `{v1}` → `{v2}`.

**Fixture** — `example/lib/unnecessary_code/prefer_reusing_assigned_local_fixture.dart`:
- `goodShadowedNestedClosure` — nested closure parameter shadows the outer `wrapper`; identical `wrapper.label` text, different element → expect NO lint (this bug).
- `badCapturedSameElement` — nested closure **captures** the same `wrapper` element → genuine recompute, `expect_lint` retained (regression guard).

**Verification** — `dart analyze lib/` clean. A resolved-unit probe (`AnalysisContextCollection.getResolvedUnit`) confirmed the outer/inner `wrapper` resolve to **different** `FormalParameterElement`s in the shadowed case and the **same** element in the captured case — exactly the discriminator the fix keys on. The `scan` CLI cannot exercise this path because it is parse-only (`parseString`, no element resolution); the real custom_lint analyzer (where the bug was reported) resolves elements, so the guard is effective there.
