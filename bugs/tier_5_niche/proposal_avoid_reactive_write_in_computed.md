# PROPOSAL: Flag Writes to a Reactive Variable Inside a `computed` Derivation

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_io_in_computed`, `avoid_observable_write_during_observer_build`, `avoid_reactive_creation_in_build`

**Package dependency:** an observable/reactive-state package exposing a `computed`/`Computed` construct (e.g. `mobx`, `signals`). This rule only applies when such a package is a declared dependency.

---

## Summary

Add `avoid_reactive_write_in_computed` to flag an assignment to any observable/reactive variable — including a *different* observable than the one being derived — made from inside a `computed` getter/block. `computed` values are contractually pure derivations: the reactive framework may re-evaluate them any number of times for reasons unrelated to "how many times the logical dependency actually changed," so a write inside one is a side effect that fires an unpredictable, framework-internal number of times, and can itself retrigger other computeds/reactions in a cascade.

**Closes gap:** all_observer_lint `avoid_reactive_write_in_computed`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The MobX/Signals contract explicitly documents `computed`/derivations as required to be free of side effects — mutating other observable state from within one is one of the most commonly cited anti-patterns in reactive-framework documentation because it can produce cascading re-computation, infinite loops, or computed values that differ depending on evaluation order, none of which are visible from reading the `computed` block in isolation.

---

## Detection / Behavior

Flag any assignment (or `.value =`) to a variable statically known to be an observable/reactive type, found within the body of a `computed(() => ...)` callback or a getter annotated `@computed`.

### Should flag (bad code)

```dart
final _evaluationCount = Observable(0);

@computed
int get total {
  _evaluationCount.value++; // LINT — writing to a different observable inside computed
  return _items.fold(0, (sum, item) => sum + item.price);
}
```

### Should pass (good code)

```dart
@computed
int get total => _items.fold(0, (sum, item) => sum + item.price); // OK — pure derivation
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (observable/reactive state library) correctness rule; only relevant to MobX/Signals-style projects, appropriate for a deep-review tier.

---

## Edge Cases

1. **Write to the SAME observable the `computed` is deriving from (self-write, causing direct infinite recursion)** — should flag as the most severe case; consider a distinct, higher-severity message for self-referential writes since that specific pattern guarantees an infinite loop rather than "merely" an unpredictable cascade.
2. **Write to a plain (non-observable) local/instance variable used only for memoization within the computed's own scope** — should pass; the rule targets writes to reactive/observable-typed state specifically, not ordinary local caching.
3. **Write guarded by an `if` that in practice never executes given current call sites (dead code)** — should still flag; static analysis targets the pattern regardless of current reachability, since future edits could make the branch live.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Merge with `avoid_observable_write_during_observer_build` into one generic "no writes during reactive read tracking" rule** — rejected; the two target distinct syntactic contexts (`Observer.builder` widget-tree building vs. `computed` derivations) with different messaging needs and different upstream rule identities to match for parity.

---

## Decision

---

## Implementation Notes

---

## Commits
