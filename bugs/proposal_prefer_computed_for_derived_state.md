# PROPOSAL: Flag Observable Recomputed Inside an `effect`/Listener — Use `Computed` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_batch_for_multiple_related_writes`

**Package dependency:** an observer/reactive-state package exposing `Observable`/`Computed`/`effect` (e.g. `signals`, `mobx`, or the package all_observer_lint targets). This rule only applies to projects using such a package and should only run when it is a declared dependency.

---

## Summary

Add `prefer_computed_for_derived_state` to flag an `effect()`/listener callback whose body only reads one or more `Observable`s to derive and write a value into another plain `Observable`, recommending `Computed(() => ...)` instead — `Computed` caches its result and only recomputes lazily on read of a stale value, while an `effect` re-runs eagerly on every dependency change and produces a second mutable `Observable` for what is really a pure derivation.

**Closes gap:** all_observer_lint (Gap Theme 13, niche reactive-state library — `Observable`/`Computed`/`Observer`/`effect`/`batch` API misuse). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 13.

---

## Motivation

`effect()` is for side effects (I/O, logging, imperative UI updates) that must run eagerly whenever a dependency changes. Using it purely to keep a second `Observable` in sync with a derivation of others is a misuse of the API: it creates a mutable value that could independently be set out-of-band (breaking the single-source-of-truth guarantee `Computed` provides), eagerly recomputes even when nothing is currently reading the derived value, and duplicates state that `Computed` would instead expose as a read-only, memoized, lazily-evaluated value.

---

## Detection / Behavior

Flag an `effect(() { ... })` call whose callback body's only statement(s) are reads of `Observable.value` combined into an expression assigned to another `Observable`'s `.value` setter, with no other side effects (no I/O calls, no `print`, no calls to non-observable-state APIs).

### Should flag (bad code)

```dart
final price = Observable(10.0);
final quantity = Observable(1);
final total = Observable(0.0);

void wireUpTotal() {
  effect(() { // LINT — pure derivation via effect; use Computed instead
    total.value = price.value * quantity.value;
  });
}
```

### Should pass (good code)

```dart
final price = Observable(10.0);
final quantity = Observable(1);
late final Computed<double> total = Computed(
  () => price.value * quantity.value,
); // OK — lazily recomputed, no redundant mutable state
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific (observer/reactive-state library), architectural-correctness rather than a hard bug; matches saropa's placement for other opt-in package-specific rules.

---

## Edge Cases

1. **`effect` body that also performs a genuine side effect alongside the derivation write (e.g. `total.value = ...; analytics.log('total changed');`)** — should pass; the effect has a real reason to be eager, so `Computed` would not fully replace it.
2. **The derived `Observable` is written to from more than one `effect`/call site (i.e. not exclusively derived)** — should pass; `Computed` requires the value be purely derived and never independently assigned elsewhere, so multiple write sites disqualify the rewrite.
3. **Derivation reads a non-`Observable` value (e.g. a plain field or `DateTime.now()`)** — should still flag if at least one `Observable` read is present, since `Computed` can still depend on `Observable`s while also referencing ordinary values, though a correction message should note `Computed` re-evaluates only on `Observable` dependency change, not on the non-reactive input.

---

## Alternatives Considered

- **Auto-fix that rewrites `effect(() { target.value = expr; })` into `late final target = Computed(() => expr)`** — deferred; requires reliably locating and removing the original `Observable` declaration and every other reference to it, which is a multi-site rewrite better done manually with the lint as a pointer.

---

## Decision

---

## Implementation Notes

---

## Commits
