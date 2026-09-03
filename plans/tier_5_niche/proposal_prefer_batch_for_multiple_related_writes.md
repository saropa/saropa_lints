# PROPOSAL: Flag Multiple Sequential Observable Writes — Wrap in `batch()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_computed_for_derived_state`

**Package dependency:** an observer/reactive-state package exposing `Observable`/`batch()` (e.g. `signals`, `mobx`, or the package all_observer_lint targets). This rule only applies to projects using such a package and should only run when it is a declared dependency.

---

## Summary

Add `prefer_batch_for_multiple_related_writes` to flag two or more sequential writes to different `Observable`/reactive-state instances within the same function body that are not wrapped in a `batch()` call, since each unbatched write triggers its own synchronous notification/rebuild cycle instead of coalescing into one.

**Closes gap:** all_observer_lint (Gap Theme 13, niche reactive-state library — `Observable`/`Computed`/`Observer`/`effect`/`batch` API misuse). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 13.

---

## Motivation

Reactive-state libraries built around `Observable`/`Computed`/`effect` notify their subscribers synchronously on every individual write by default. Writing to two or more related observables back-to-back without `batch()` means any listener/effect that depends on both re-runs once per intermediate write instead of once after both are settled — wasted rebuild work at best, and a listener observing a transient, inconsistent intermediate state at worst (e.g. `total` recomputed after `price` changes but before `quantity` changes).

---

## Detection / Behavior

Flag a function/method body containing 2+ direct assignments to `.value` (or the package's equivalent setter) on distinct `Observable`-typed variables, with no intervening non-observable-write statement, that are not enclosed in a `batch(() { ... })` call.

### Should flag (bad code)

```dart
final price = Observable(10.0);
final quantity = Observable(1);

void updateOrder(double newPrice, int newQuantity) {
  price.value = newPrice; // LINT — sequential related writes not batched
  quantity.value = newQuantity;
}
```

### Should pass (good code)

```dart
final price = Observable(10.0);
final quantity = Observable(1);

void updateOrder(double newPrice, int newQuantity) {
  batch(() {
    price.value = newPrice; // OK — coalesced into one notification
    quantity.value = newQuantity;
  });
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific (observer/reactive-state library), performance-oriented rather than correctness-breaking in most cases; matches saropa's placement for other opt-in package-specific performance rules.

---

## Edge Cases

1. **Two writes to the SAME observable in sequence (`price.value = a; price.value = b;`)** — should pass; only the second write matters and there is no cross-observable coalescing benefit; a separate "redundant sequential write" rule would cover that case if desired.
2. **Writes separated by a statement that reads a different, unrelated observable's `.value`** — should still flag, since the notification-coalescing benefit doesn't depend on other reads occurring between the writes.
3. **Writes already inside a `batch()` callback, nested one level deeper in a helper call** — should pass; only detect direct membership in the same function body, not attempt cross-function dataflow analysis.
4. **Single write inside a loop body writing to the same variable each iteration** — should pass; that's one observable, not "multiple related" ones, and the loop's own restructuring is a separate concern.

---

## Alternatives Considered

- **Require a quick fix that auto-wraps in `batch()`** — include as an initial quick fix; wrapping consecutive statements in a `batch(() { ... })` closure is a safe, mechanical transform once the flagged range is identified.

---

## Decision

---

## Implementation Notes

---

## Commits
