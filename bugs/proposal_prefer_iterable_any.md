# PROPOSAL: Flag `.where(predicate).isNotEmpty` — Use `.any(predicate)` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_iterable_every` (companion rule), `prefer_any_or_every` (false cognate — see below)

---

## Summary

Add `prefer_iterable_any` to flag `iterable.where(predicate).isNotEmpty`, recommending `iterable.any(predicate)` instead — `.where().isNotEmpty` builds and fully evaluates an intermediate lazy `Iterable` just to check emptiness, while `.any` short-circuits on the first matching element without allocating the intermediate iterable.

**Closes gap:** pyramid_lint `prefer_iterable_any`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` pyramid_lint Gaps section / Gap Theme 14.

**Note — false cognate, not already covered:** saropa's existing `prefer_any_or_every` rule is a *different* rule with a similarly-worded name — do not treat this proposal as already implemented. Confirm the exact target shape of `prefer_any_or_every` before closing this proposal as a duplicate.

---

## Motivation

`.where(predicate)` returns a lazy `Iterable`; calling `.isNotEmpty` on it forces evaluation but, worse, most developers don't realize `.where().isNotEmpty` still evaluates the predicate against every element up to the first match through an iterator wrapper with extra allocation overhead compared to `.any`, which is implemented as a direct loop with early return. Functionally identical, but `.any` is both faster (no intermediate `Iterable` wrapper) and more directly states the intent ("does any element satisfy this?").

---

## Detection / Behavior

### Should flag (bad code)

```dart
bool hasNegative(List<int> values) {
  return values.where((v) => v < 0).isNotEmpty; // LINT — use values.any((v) => v < 0)
}
```

### Should pass (good code)

```dart
bool hasNegative(List<int> values) {
  return values.any((v) => v < 0); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: performance-and-clarity rule with a purely mechanical, safe rewrite — matches saropa's placement for similar collection-idiom-substitution rules (e.g. `prefer_any_or_every`'s tier, once confirmed).

---

## Edge Cases

1. **`.where(predicate).length > 0`** — should also flag toward `.any(predicate)`; same underlying inefficiency, different emptiness-check spelling.
2. **`.where(predicate).toList().isNotEmpty`** — should also flag; the explicit `.toList()` materialization makes the waste even more concrete but the fix target is identical.
3. **Result of `.where(predicate)` reused elsewhere (not immediately followed by `.isNotEmpty`)** — should NOT flag; only the direct `.where(...).isNotEmpty` chain with no intervening use of the filtered list is a safe, behavior-preserving rewrite target.
4. **`.where(predicate).isEmpty`** — out of scope for this rule; that inverse case is `prefer_iterable_every`'s (`!predicate` via `.every`) territory, tracked as its own proposal.

---

## Alternatives Considered

- **Combine with `prefer_iterable_every` into a single rule with two message variants** — rejected; keep as two separate rules matching pyramid_lint's own separation, since `isEmpty`/`isNotEmpty` require different negation handling on the predicate and separate rule ids make tier/severity control finer-grained.

---

## Decision

---

## Implementation Notes

---

## Commits
