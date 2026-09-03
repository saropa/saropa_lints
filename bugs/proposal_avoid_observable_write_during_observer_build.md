# PROPOSAL: Flag Writes to Observable State During an `Observer` Build

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_io_in_computed`, `avoid_reactive_creation_in_build`, `avoid_reactive_write_in_computed`

**Package dependency:** an observable/reactive-state package exposing an `Observer` widget and mutable observables (e.g. `mobx`, `flutter_mobx`, `signals`). This rule only applies when such a package is a declared dependency.

---

## Summary

Add `avoid_observable_write_during_observer_build` to flag a write to an observable/reactive variable made directly inside an `Observer`'s `builder` callback (or a `build()` method that reads observables reactively) — writing to an observable while the reactive system is in the middle of tracking reads for that same build can trigger an immediate re-build (or, worse, an infinite build loop), and is a classic reactive-framework footgun equivalent to calling `setState()` synchronously from inside `build()`.

**Closes gap:** all_observer_lint `avoid_observable_write_during_observer_build`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Reactive frameworks track which observables are *read* during a build so they know when to re-run it. Writing to an observable during that same build is fundamentally different from writing during an event handler: it can retrigger the very build that's currently running, and depending on the framework's re-entrancy guards this either throws, silently no-ops, or loops. It is directly analogous to Flutter's own "setState() called during build" error, just without the framework catching it for you.

---

## Detection / Behavior

Flag any assignment (or `.value =`) to a variable statically known to be an observable/reactive type, found within the `builder` callback of an `Observer` widget or within a `build()` method of a widget that reads observables reactively.

### Should flag (bad code)

```dart
Observer(
  builder: (context) {
    if (counter.value > 10) {
      counter.value = 0; // LINT — writing to an observable during Observer's build
    }
    return Text('${counter.value}');
  },
);
```

### Should pass (good code)

```dart
Observer(
  builder: (context) {
    return Text('${counter.value}'); // OK — build only reads
  },
);

void resetIfOverLimit() {
  if (counter.value > 10) {
    counter.value = 0; // OK — write happens in an action/event handler, not during build
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (observable/reactive state library) correctness rule; only relevant to MobX/Signals-style projects, appropriate for a deep-review tier.

---

## Edge Cases

1. **Write to an observable local to the build closure itself (not shared/hoisted state)** — should pass; the risk is specifically re-triggering *shared* observable tracking, and a fresh local created and mutated entirely within one build call carries no such risk.
2. **Write wrapped in a `Future.microtask(() => counter.value = 0)` inside the builder** — should pass; deferring the write outside the synchronous build call sidesteps the re-entrancy hazard, which is the standard recommended workaround.
3. **Write to an observable inside a nested `Observer` further down the widget tree, within the outer `Observer`'s builder** — should flag the same; still executes synchronously as part of a build pass.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Rely on the underlying reactive framework's own runtime assertion/error instead of a static lint** — rejected; a runtime error only surfaces when the exact code path executes (often intermittently, under specific state), whereas a static lint catches the pattern at write time before it ships.

---

## Decision

---

## Implementation Notes

---

## Commits
