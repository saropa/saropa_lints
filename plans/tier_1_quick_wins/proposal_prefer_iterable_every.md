# PROPOSAL: Flag `.where(predicate).isEmpty` — Use `!iterable.any(predicate)` / `.every()` Instead

**Status: Duplicate — already covered by `PreferAnyOrEveryRule` (`prefer_any_or_every`) in `lib/src/rules/code_quality/code_quality_prefer_rules.dart` which flags `.where().isEmpty` → `!.any()`/`.every()`**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_iterable_any` (companion rule), `prefer_any_or_every` (false cognate — see below)

---

## Summary

Add `prefer_iterable_every` to flag `iterable.where(predicate).isEmpty`, recommending the negated form appropriate to the predicate's meaning — `!iterable.any(predicate)` in general, or `iterable.every((e) => !predicate(e))` when the predicate can be cleanly negated inline — instead of building and evaluating an intermediate `Iterable` just to check it's empty.

**Closes gap:** pyramid_lint `prefer_iterable_every`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` pyramid_lint Gaps section / Gap Theme 14.

**Note — false cognate, not already covered:** saropa's existing `prefer_any_or_every` rule is a *different* rule with a similarly-worded name — do not treat this proposal as already implemented. Confirm the exact target shape of `prefer_any_or_every` before closing this proposal as a duplicate.

---

## Motivation

Same performance rationale as `prefer_iterable_any`: `.where(predicate).isEmpty` materializes/iterates a lazy `Iterable` wrapper instead of short-circuiting via `.any`/`.every`. `iterable.where(p).isEmpty` is logically `!iterable.any(p)`, which Dart can evaluate as a single short-circuiting pass with no intermediate `Iterable` object.

---

## Detection / Behavior

### Should flag (bad code)

```dart
bool allNonNegative(List<int> values) {
  return values.where((v) => v < 0).isEmpty; // LINT — use !values.any((v) => v < 0)
}
```

### Should pass (good code)

```dart
bool allNonNegative(List<int> values) {
  return !values.any((v) => v < 0); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: performance-and-clarity rule with a mechanical, safe rewrite; matches `prefer_iterable_any`'s tier placement.

---

## Edge Cases

1. **`.where(predicate).length == 0`** — should also flag toward `!iterable.any(predicate)`; same inefficiency, different emptiness-check spelling.
2. **Predicate is a simple negatable comparison (e.g. `v < 0`)** — the correction message/quick fix may offer `iterable.every((v) => v >= 0)` as a more readable alternative to double-negation, but `!iterable.any(predicate)` remains the always-safe minimal rewrite when the predicate isn't a simple comparison to invert.
3. **Result of `.where(predicate)` reused elsewhere** — should NOT flag; only the direct `.where(...).isEmpty` chain with no other use of the filtered result is a safe rewrite target.
4. **`.where(predicate).isNotEmpty`** — out of scope; covered by `prefer_iterable_any`.

---

## Alternatives Considered

- **Always emit `.every((e) => !predicate(e))` as the sole suggested fix** — rejected as the primary fix; double-negating an arbitrary predicate expression is not always straightforward to auto-generate correctly (especially for multi-clause predicates), so `!iterable.any(predicate)` is the safer default auto-fix, with `.every` offered only as a documented alternative in the correction message.

---

## Decision

---

## Implementation Notes

---

## Commits
