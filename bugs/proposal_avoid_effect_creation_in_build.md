# PROPOSAL: Flag `all_observer` `effect()` Creation Inside a Widget `build()` Method

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `all_observer` reactive-state package)
Related rules: `async_inside_batch` (companion `all_observer` proposal), `avoid_ref_watch_outside_build` /
`avoid_ref_read_inside_build` (saropa's analogous Riverpod build-scoping rules — same shape, different library)

---

## Summary

Add `avoid_effect_creation_in_build` to flag calling `all_observer`'s `effect(() { ... })` directly inside a
`StatelessWidget`/`State.build()` method. `build()` can run many times (every rebuild), so creating a new
`effect` subscription there registers a fresh, un-disposed reactive listener on every rebuild instead of once
per widget lifetime — a subscription leak that compounds with every parent-triggered rebuild.

**Closes gap:** `all_observer_lint` `avoid_effect_creation_in_build` (github.com/CriandoGames/all_observer_lint).
Implementing this proposal as specified fully closes this competitive gap for projects using the
`all_observer` package — see `plans/GAP_ANALYSIS.md` "all_observer_lint" section (20/20 GAP).

---

## Motivation

This is structurally the same footgun saropa already polices for Riverpod (`avoid_ref_watch_outside_build`,
`avoid_ref_read_inside_build`, `avoid_calling_notifier_members_inside_build`): reactive-framework
subscriptions and listeners must be created once, outside the rebuild-driven `build()` method, or they leak
and multiply. `all_observer`'s `effect()` has the identical lifecycle hazard, and saropa currently has zero
`all_observer`-aware rules despite already owning this exact pattern class for Riverpod — it is a direct
extension of a lint shape saropa's rule authors already understand.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Counter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    effect(() { // LINT — avoid_effect_creation_in_build: new effect() subscription created every rebuild
      print('count changed: ${count.value}');
    });
    return Text('${count.value}');
  }
}
```

### Should pass (good code)

```dart
class Counter extends StatefulWidget {
  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  late final Dispose _dispose;

  @override
  void initState() {
    super.initState();
    _dispose = effect(() { // OK — created once, in initState
      print('count changed: ${count.value}');
    });
  }

  @override
  void dispose() {
    _dispose(); // OK — cleaned up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${count.value}');
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `all_observer` dependency note)
Justification: Only fires in projects depending on `all_observer`; matches the tier saropa assigns its
existing Riverpod build-scoping analogs; correctness/leak risk rather than a universal Dart style concern.

---

## Edge Cases

1. **`effect()` call inside a method called FROM `build()` but not textually inside `build()` itself**
   (e.g. a private `_setupEffect()` helper invoked from `build()`) — needs discussion; matches the same
   call-graph-depth limitation saropa's existing `avoid_ref_watch_outside_build` already has to handle for
   Riverpod — direct syntactic containment is the safe minimum, cross-method tracing is a stretch goal.
2. **`effect()` inside `initState()`/`didChangeDependencies()`** — should pass; these run once per widget
   lifetime (or once per dependency change), not on every rebuild.
3. **`effect()` inside a non-widget function** (plain Dart class, controller, `main()`) — should pass; the
   rule targets Flutter widget `build()` methods specifically.
4. **Project does not depend on `all_observer`** — must not fire; gate on package presence like saropa's
   other ecosystem-specific rules.

---

## Alternatives Considered

- **Generalize into one "no reactive-subscription creation in build()" rule spanning Riverpod AND
  `all_observer`** — appealing for code reuse, but rejected for this proposal to keep scope matching the
  cited gap; the shared detection logic (AST containment check for `build()`) can still be factored into a
  common helper at implementation time without merging the public rule identities.

---

## Decision

---

## Implementation Notes

---

## Commits
