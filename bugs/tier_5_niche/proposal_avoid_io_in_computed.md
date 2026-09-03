# PROPOSAL: Flag I/O Calls Inside Reactive `computed` Getters

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_reactive_write_in_computed`, `avoid_reactive_creation_in_build`, `avoid_observable_write_during_observer_build`

**Package dependency:** an observable/reactive-state package exposing a `computed`/`Computed` construct (e.g. `mobx`, `signals`). This rule only applies when such a package is a declared dependency.

---

## Summary

Add `avoid_io_in_computed` to flag network calls, file I/O, `print`/logging, or platform-channel calls made from inside a reactive `computed` getter/block — computed values are expected to be pure, synchronous derivations of other observable state, re-evaluated an unpredictable number of times whenever any dependency changes, so side effects placed inside one fire repeatedly and unpredictably, not once per "logical" trigger.

**Closes gap:** all_observer_lint `avoid_io_in_computed`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Reactive frameworks re-run `computed` derivations any time a read dependency changes, and reactive systems are explicitly allowed to re-evaluate more often than "necessary" for correctness reasons internal to the framework. An I/O call inside a `computed` block runs on that same unpredictable cadence — potentially many times per second during rapid state changes — turning a pure derivation into a runaway source of network requests, log spam, or file writes.

---

## Detection / Behavior

Flag any call to a known I/O API (`http.get`/`post`, `File(...).read*`/`write*`, `print`, `dart:io` socket/process calls, or a project-configured list of I/O-performing functions) found within the body of a `computed(() => ...)` callback or a getter annotated `@computed`.

### Should flag (bad code)

```dart
@computed
int get itemCount {
  print('recomputing itemCount'); // LINT — I/O (logging) inside a computed derivation
  return _items.length;
}
```

### Should pass (good code)

```dart
@computed
int get itemCount => _items.length; // OK — pure derivation, no side effects

@action
void logItemCount() {
  print('itemCount is $itemCount'); // OK — logging lives in an action, not the derivation
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (observable/reactive state library) correctness rule; only relevant to teams using MobX/Signals-style computed values, appropriate for a deep-review tier.

---

## Edge Cases

1. **Computed getter that reads from an in-memory cache (no actual I/O)** — should pass; the rule targets true I/O boundaries (network, disk, platform channels, logging), not pure memory reads.
2. **`print` used only in debug builds behind `assert()` or `kDebugMode`** — needs discussion; still recommend flagging since debug-only I/O in a hot re-evaluation path is still a performance/log-spam hazard during development.
3. **I/O call made inside a nested closure passed to a synchronous collection method (`_items.map((i) => logAndTransform(i))`) within the computed** — should flag; the nested closure still executes as part of the computed's re-evaluation.
4. **Computed value awaited via a `Future`-returning helper (async computed)** — should flag as a stronger case; async work inside a `computed` is doubly wrong (side effect + framework generally expects synchronous derivations).

---

## Alternatives Considered

- **Flag all side effects generically (not just I/O)** — deferred; I/O is the highest-cost, most visible category of side effect for this pattern (network/disk/log spam), while other side effects (e.g. mutating a different observable) are covered by the sibling `avoid_reactive_write_in_computed` and `avoid_observable_write_during_observer_build` rules.

---

## Decision

---

## Implementation Notes

---

## Commits
