# PROPOSAL: Flag Direct `list[index]` Access in Favor of a Bounds-Safe Accessor

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_dynamic_calls` (core lints)

---

## Summary

Add `no_direct_iterable_access` to flag direct index access (`list[index]`) on `List`/other indexable collections, suggesting a bounds-safe alternative such as `.elementAtOrNull(index)` or a project-provided `safeAt()` extension that returns `null`/a default instead of throwing `RangeError`.

**Closes gap:** `flutter_custom_lints` `no_direct_iterable_access` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`list[index]` throws `RangeError` the moment `index` is out of bounds, and that failure mode is easy to miss when the index comes from user input, an API response, or a computed offset rather than a literal loop counter. A bounds-safe accessor turns a crash into a `null` the caller must explicitly handle, which is the same defensive posture saropa_lints already takes with nullable-safe collection access.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String firstItemLabel(List<String> items) {
  return items[0]; // LINT — direct index access, no bounds check
}
```

### Should pass (good code)

```dart
String firstItemLabel(List<String> items) {
  return items.elementAtOrNull(0) ?? ''; // OK — bounds-safe accessor with an explicit fallback
}
```

---

## Proposed Tier

Tier: Professional
Justification: `RangeError` crashes are a real production risk, but flagging every literal-index access (including provably-safe ones inside a bounds-checked loop) is noisy enough to place above Essential/Recommended.

---

## Edge Cases

1. **Index access immediately preceded by an explicit bounds check (`if (index < list.length) list[index]`)** — should pass; the developer has already guarded the access.
2. **Index access inside a `for (var i = 0; i < list.length; i++)` loop using the loop variable** — should pass; the loop condition provably bounds `i`.
3. **Fixed-size literal list with a constant, in-range index (`const [1, 2, 3][1]`)** — should pass; statically provable safety.
4. **`Map` bracket access (`map[key]`)** — should pass; `Map` access returns `null` for a missing key rather than throwing, so it is not the hazard this rule targets.

---

## Alternatives Considered

- **Flag `Map` access too** — rejected; `Map`'s `[]` already returns `null` on a miss, so it has none of the crash risk that motivates this rule for `List`.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

1. **`<=` is wrongly accepted as a sufficient bounds guard** — `_isBoundsGuardCondition` (`no_direct_iterable_access_rules.dart:199-200`) treats both `TokenType.LT` and `TokenType.LT_EQ` as safe guard operators. `index <= list.length` does **not** prevent a `RangeError`: when `index == list.length` the access still throws. This is a correctness bug in the guard-detection logic itself — it causes the rule to silently suppress a lint on code that is genuinely unsafe (a false negative on the exact hazard the rule exists to catch). No test exercises the `<=` case, so this ships unverified.
2. **Doc/code mismatch on `!=` handling** — the dartdoc on `_isBoundsGuardCondition` (lines 178-181) claims the method handles "the `<=`/`!=`-with-appropriate-sense variants," but the code never checks `TokenType.BANG_EQ` or `TokenType.EQ_EQ` anywhere; only `LT`/`LT_EQ` are compared (line 200). Combined with issue 1, the `<=` half of that claim is also actively wrong, not just undocumented-but-fine.
3. **No support for the early-return guard-clause idiom** — `_isGuardedByBoundsCheck` (lines 140-156) only recognizes the case where the indexed access is nested *inside* the `if`'s `thenStatement`/`thenElement`. It does not recognize the far more common Dart idiom:
   ```dart
   int elementAt(List<int> values, int index) {
     if (index >= values.length) return -1;
     return values[index]; // FALSE POSITIVE — will be flagged, but is safe
   }
   ```
   This pattern (guard clause + early return, then unguarded use below) is at least as common in real code as the nested-`if` form that IS tested. As written, the rule will fire on this and contradicts its own dartdoc claim ("The rule does not flag access that is statically provable to be safe").
4. **`else`-branch guards are not recognized** — same method never inspects `elseStatement`/`elseElement`, so:
   ```dart
   if (index >= values.length) {
     return -1;
   } else {
     return values[index]; // FALSE POSITIVE
   }
   ```
   is flagged despite being safe.
5. **Reversed comparison operand order is not recognized** — `_isBoundsGuardCondition` (lines 202-208) requires the index to be the *left* operand and a `.length` access to be the *right* operand. `if (values.length > index) { ... values[index] ... }` — an equally idiomatic way to write the same guard — is not recognized and will false-positive.

### Concerns

- **`isDartCoreList` exact-type check misses List-shaped subtypes.** Typed-data lists (`Uint8List`, `Int32List`, `Float64List`, etc. from `dart:typed_data`) extend `List<int>`/`List<double>` and throw the identical `RangeError` on out-of-bounds `[]`, but `targetType.isDartCoreList` (line 98) is false for them, so they are silently out of scope. A custom class that `implements List<T>` is exempted the same way. This narrows real-world coverage without being called out in the proposal's "Alternatives Considered."
- **`ForElement` (collection-for in a list/set/map literal) is not covered** by `_isGuardedByBoundingForLoop` (lines 162-176) — only `ForStatement` is checked. `[for (var i = 0; i < items.length; i++) items[i]]` inside a collection literal will false-positive even though it's the identical bounded-loop idiom the rule is explicitly designed to exempt.
- **Guard matching is purely syntactic (`toSource()` equality), not semantic.** If the index expression or target has a side effect or is non-idempotent (e.g., a getter that mutates state, or an expression embedding a call), the guard condition and the access can be textually identical (`toSource()` equal) while evaluating to different values at runtime. Low-probability in practice, but worth knowing this is a syntactic, not a dataflow, safety proof.
- **`test/rules/data/no_direct_iterable_access_test.dart:3-8` contains a stale/incorrect comment** stating the rule "is not yet wired into the global tier registry (a separate process handles the three-way registration centrally...)." This is factually wrong as of this review — the rule IS registered: `lib/src/rules/all_rules.dart:212` (export), `lib/saropa_lints.dart:2927` (`NoDirectIterableAccessRule.new` in `_allRuleFactories`), and `lib/src/tiers.dart:1772` (`professionalOnlyRules`). Leaving this comment will mislead the next person who touches this test into thinking registration is still pending.
- `RuleCost.high` is self-declared and justified by the ancestor-walk, but nothing in the test suite exercises a deeply nested guard (e.g., an access 10+ blocks below the guarding `if`) to confirm the walk terminates correctly and cheaply at real-world nesting depths.

### Opportunities

- `RangeError.checkValidIndex(index, list)` — the dart:core-provided, textbook-idiomatic way to explicitly guard an index — is not recognized as a guard at all. Recognizing it would reward the "correct" fix this rule's own correctionMessage doesn't suggest, and would remove an otherwise-guaranteed false positive on any code that follows dart:core's own recommended pattern.
- The ancestor-walking "is this node inside/after a guard" logic (`_isGuardedByBoundsCheck`, `_isGuardedByBoundingForLoop`, `_isDescendantOf`) is generic guard-clause detection that isn't List-specific. If other rules need similar "was this dereference/access preceded by a guard clause" reasoning (null-check guards, range guards, etc.), extracting a shared `GuardClauseUtils` (or similar) would avoid re-deriving this ancestor-walk in each rule file — worth checking whether `avoid_mounted_check_in_finally_rules.dart` or other rules already reimplement a similar pattern before writing a third copy.
- Widening the scope check from the exact `isDartCoreList` to a small allowlist (`List` plus known typed-data list types) mirrors the broader indexable check already used in `collection_rules.dart:118`; reusing/aligning with that logic would close the typed-data gap noted above with minimal new code.

### Recommendations

1. **(High)** Fix the `<=` bug: drop `TokenType.LT_EQ` from the accepted operators in `_isBoundsGuardCondition` (or handle it correctly, e.g. treat `index <= list.length - 1` as equivalent to `<`), correct the misleading `!=` dartdoc claim, and add a regression test proving `index <= values.length` still fires.
2. **(High)** Add early-return guard-clause detection (`if (unsafeCondition) return/continue/break;` immediately before the access, in the same enclosing block) with a fixture + test — this single fix removes what is likely the most common false-positive class in real codebases and brings the implementation in line with the rule's own documented safety claim.
3. **(Medium)** Add `else`-branch recognition and reversed-comparison (`list.length > index`) recognition to `_isBoundsGuardCondition`, each with its own fixture/test case.
4. **(Medium)** Correct or delete the stale "not yet wired into the global tier registry" comment in `test/rules/data/no_direct_iterable_access_test.dart:3-8` — the rule is registered; the comment is now actively wrong.
5. **(Low)** Decide and document (in "Alternatives Considered") whether typed-data lists and `ForElement` loop-comprehension guards are in-scope; if deferred, note it explicitly rather than leaving it as an undocumented gap.
