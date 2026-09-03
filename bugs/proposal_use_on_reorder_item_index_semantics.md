# PROPOSAL: Flag Missing Index-Adjustment in `ReorderableListView.onReorder`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `use_on_reorder_item_index_semantics` to flag a `ReorderableListView.onReorder` (or `.builder`'s `onReorder`) callback that uses `newIndex` directly to insert/move an item without the required `if (newIndex > oldIndex) newIndex -= 1;` adjustment — Flutter's documented `onReorder` contract passes a `newIndex` computed *before* the item is removed from the list, so a naive direct use silently off-by-ones every downward drag.

**Closes gap:** `flutter_skill_lints` `use_on_reorder_item_index_semantics`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `flutter_skill_lints` gap list.

---

## Motivation

This is one of the most commonly mis-implemented callbacks in Flutter — the framework's own documentation calls out the off-by-one adjustment explicitly, yet it is routinely missed because the bug only manifests visually (items landing one position off) rather than throwing, so it slips through manual testing unless someone drags every possible direction. It is a pure boilerplate-correctness rule, exactly the kind of thing static analysis is good at catching before a human ever runs the app.

---

## Detection / Behavior

Flag an `onReorder: (oldIndex, newIndex) { ... }` callback body that performs a `list.removeAt(oldIndex)` followed by `list.insert(newIndex, item)` (or equivalent), where no `if (newIndex > oldIndex) newIndex -= 1;`-shaped adjustment (comparing `newIndex` to `oldIndex` and decrementing) appears between the two parameter declarations and the `insert` call.

### Should flag (bad code)

```dart
onReorder: (oldIndex, newIndex) {
  setState(() {
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item); // LINT — missing newIndex adjustment, off-by-one on downward drags
  });
},
```

### Should pass (good code)

```dart
onReorder: (oldIndex, newIndex) {
  setState(() {
    if (newIndex > oldIndex) {
      newIndex -= 1; // OK — required adjustment present
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
  });
},
```

---

## Proposed Tier

Tier: Recommended
Justification: Well-documented, easy-to-miss correctness bug with a mechanical, low-false-positive detection shape (parameter reassignment pattern), similar risk profile to other Recommended-tier boilerplate-correctness rules.

---

## Edge Cases

1. **Reorder logic delegated to a helper function/mixin that already performs the adjustment internally** — needs discussion; single-function pattern matching is the v1 scope and may false-positive on delegated implementations — consider allowing a suppress-if-body-is-a-single-call-expression exemption.
2. **`newIndex` adjusted via a different but equivalent expression (e.g. `newIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;`)** — should pass; detection should recognize the semantic pattern (compare-then-decrement), not one exact syntactic form.
3. **A reorder implementation that doesn't use `removeAt`/`insert` at all (e.g. rebuilds the list from a reordered index array)** — should pass; the off-by-one only applies to the remove-then-insert idiom the rule targets.
4. **`onReorder` callback that ignores `newIndex` entirely (always appends)** — should pass; no adjustment is needed if `newIndex` is never used positionally.

---

## Alternatives Considered

- **Provide an auto-fix that inserts the adjustment** — recommend as a follow-up quick fix once the rule ships; the fix location (right after the `(oldIndex, newIndex)` parameter list) is unambiguous once the bad pattern is detected.

---

## Decision

---

## Implementation Notes

---

## Commits
