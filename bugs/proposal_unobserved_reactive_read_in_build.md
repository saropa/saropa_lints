# PROPOSAL: Flag `Observable`/`Computed` Read in `build()` Outside a Tracking Context

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ref_read_inside_build` (Riverpod equivalent concept)

---

## Summary

Add `unobserved_reactive_read_in_build` for the `all_observer` reactive-state package: flag a `.value`/`.get()` read of an `Observable`/`Computed` inside `build()` that is NOT wrapped in the package's tracking construct (e.g. `Observer(builder: ...)`), so the widget silently never rebuilds when that value changes.

**Closes gap:** `all_observer_lint` `unobserved_reactive_read_in_build` (github.com/CriandoGames/all_observer_lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer_lint" section (0/20 coverage).

---

## Motivation

This is the `all_observer` package's version of the exact bug class saropa already polices for Riverpod (`avoid_ref_read_inside_build`) and Provider (`avoid_context_read_in_build` family): reading reactive state through the "untracked" accessor inside a widget's `build()` produces a widget that renders once with stale data and never updates again. Because `all_observer` is a niche package, saropa has zero rules recognizing its API today.

---

## Detection / Behavior

Flag a property/method access resolving to `Observable<T>.value` or `Computed<T>.value` inside a `build()` method body when the access is not nested inside an `Observer(builder: (context) { ... })` closure or equivalent tracking scope.

### Should flag (bad code)

```dart
class CounterView extends StatelessWidget {
  final counter = Observable(0);

  @override
  Widget build(BuildContext context) {
    return Text('${counter.value}'); // LINT — untracked read, widget won't rebuild
  }
}
```

### Should pass (good code)

```dart
class CounterView extends StatelessWidget {
  final counter = Observable(0);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) => Text('${counter.value}'), // OK — read inside tracking scope
    );
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rule (`all_observer` dependency required) — flag as a package rule, appropriate for Comprehensive/Pedantic per the package-specific-rule convention.

---

## Edge Cases

1. **Read inside a nested `Observer` builder that is itself inside an outer non-tracking widget** — should pass; only the innermost enclosing scope matters.
2. **Read inside `initState()`/event handlers, not `build()`** — should pass; this rule is scoped to `build()` only, matching the Riverpod/Provider precedent.
3. **`all_observer` package not a project dependency** — rule should no-op entirely (standard package-rule gating).
4. **Read via a local variable aliasing `counter.value` computed outside `build()` but used inside it** — should discuss; may require light data-flow tracing to avoid false negatives, or ship as a known limitation in v1.

---

## Alternatives Considered

- **Generalize into a single "untracked reactive read" rule spanning Riverpod/Provider/`all_observer`** — rejected for v1; each package's tracking-scope API shape differs enough that a shared visitor adds complexity without saving much code; revisit if a fourth reactive package needs the same pattern.

---

## Decision

---

## Implementation Notes

---

## Commits
