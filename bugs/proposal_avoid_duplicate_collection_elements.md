# PROPOSAL: Flag Duplicate Literal Elements in a Collection Literal

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_duplicate_collection_elements` to flag a `List`/`Set` literal that repeats the same constant
element more than once (`[1, 2, 2, 3]`, `{'a', 'b', 'a'}`) — almost always a copy-paste mistake, since a
`Set` silently drops the duplicate at runtime and a `List` carries dead redundant data either way.

**Closes gap:** `awesome_lints` `avoid_duplicate_collection_elements` (unconfirmed exact upstream match —
github.com/LucasXu0/awesome_lints). Implementing this proposal as specified closes this competitive gap —
see `plans/GAP_ANALYSIS.md` "awesome_lints" Gaps section (flagged unconfirmed pending upstream verification).

---

## Motivation

A duplicated literal element inside a collection literal is a specific, mechanical mistake pattern —
usually a copy-paste that wasn't updated, or a merge that introduced the same entry twice. For a `Set`
literal it is silently harmless at runtime (duplicates collapse) but signals the author's intent was
probably to list N distinct values and only got N-1; for a `List` literal it directly changes behavior
(the value now appears twice where one was likely intended), which is a real correctness risk in contexts
like enum-exhaustiveness lists, allowed-value lists, or test fixture data.

---

## Detection / Behavior

### Should flag (bad code)

```dart
const allowedRoles = {'admin', 'editor', 'admin'}; // LINT — avoid_duplicate_collection_elements: 'admin' appears twice
final scores = [10, 20, 20, 30]; // LINT — avoid_duplicate_collection_elements: 20 appears twice
```

### Should pass (good code)

```dart
const allowedRoles = {'admin', 'editor', 'viewer'}; // OK — all distinct
final scores = [10, 20, 20, 30]; // OK if genuinely intentional (e.g. tied placements) — see edge cases
```

---

## Proposed Tier

Tier: Recommended
Justification: Cheap, purely mechanical AST check (constant-literal-equality comparison within one
collection literal) with low false-positive risk on `Set` literals specifically and clear intent-signal
value; safe enough for a default-on tier without needing a deep readability-pass mindset.

---

## Edge Cases

1. **Duplicate elements in a `List` literal that legitimately represents repeated values** (e.g. dice-roll
   results, tied test scores, a histogram's raw sample data) — needs discussion; the rule should probably
   scope to `Set` literals only by default (where duplication is unambiguously either dead or a mistake),
   and treat `List` duplication as a separate, lower-confidence opt-in variant since repeated values are
   often intentional in a list.
2. **Duplicate non-constant expressions** (`[getValue(), getValue()]` where the two calls could return
   different results) — should pass; only literal/constant-foldable elements should be compared, not
   arbitrary expressions that happen to look textually identical.
3. **Spread elements** (`[...listA, ...listA]`) — needs discussion; flagging the whole spread as duplicated
   is a different, coarser check than per-element duplication — likely out of scope for the initial rule.
4. **`const` collection with duplicate elements used deliberately to weight a random-pick pool**
   (`const weightedPool = ['common', 'common', 'common', 'rare']`) — should pass if scoped to `Set` literals
   only per Edge Case 1's resolution; this is exactly the kind of intentional `List` duplication that
   justifies excluding `List` from the default check.

---

## Alternatives Considered

- **Scope to both `List` and `Set` literals uniformly** — rejected in favor of `Set`-only by default (see
  Edge Case 1); `List` duplication has too many legitimate uses (weighted pools, repeated test data) to flag
  without a high false-positive rate, while `Set` duplication is unambiguous since the language itself
  silently discards the repeat.

---

## Decision

---

## Implementation Notes

---

## Commits
