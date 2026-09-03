# PROPOSAL: Flag Undisposed `all_observer` Reactive Resources

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific: `all_observer`)
Related rules: none

---

## Summary

Add `dispose_reactive_resources` to flag `all_observer` reactive resources (`effect()` handles, `Observable`/`ObservableList` subscriptions, `computed()` disposers) created in a `State`/controller lifecycle scope but never disposed, causing memory leaks and stale reactivity after the owning object is destroyed.

**Closes gap:** `all_observer_lint` `dispose_reactive_resources`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "all_observer" gaps section.

---

## Motivation

`effect()` and similar `all_observer` primitives return a disposer function/handle that must be invoked (typically in `dispose()`) to stop tracking and release listeners. Forgetting this is the exact same class of bug saropa already flags for `StreamSubscription`/`AnimationController` in `avoid_disposing_late_fields`-adjacent rules, just for a different reactive-state library saropa has no current awareness of.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    effect(() => print(counter.value)); // LINT — effect() disposer is discarded; resource is never disposed
  }
}
```

### Should pass (good code)

```dart
class _MyWidgetState extends State<MyWidget> {
  late final Dispose _disposeEffect;

  @override
  void initState() {
    super.initState();
    _disposeEffect = effect(() => print(counter.value)); // OK — disposer captured
  }

  @override
  void dispose() {
    _disposeEffect(); // OK — disposed in State.dispose()
    super.dispose();
  }
}
```

---

## Proposed Tier

Tier: Professional
Justification: memory-leak-class bug, same severity family as saropa's existing controller/subscription disposal rules; package-specific to `all_observer` keeps it below Essential/Recommended, but the bug class itself is high-severity, warranting Professional over Comprehensive.

---

## Edge Cases

1. **`effect()` return value discarded but the effect is intentionally "fire once and self-dispose" (e.g. returns a value used to auto-cancel internally)** — needs discussion; if `all_observer` has a documented auto-disposing variant, that call pattern should be exempted, otherwise treat discard as always-flag.
2. **Disposer captured in a local variable but never called anywhere in the class, including `dispose()`** — should flag; capturing without calling is equivalent to discarding for this rule's purpose.
3. **`effect()` created inside a top-level function/script (no `State`/lifecycle object involved)** — needs discussion; may be an intentional process-lifetime effect (e.g. a CLI tool) with no meaningful "dispose" scope — likely should pass, restricting the rule to `State.initState`-or-similar lifecycle contexts.
4. **Multiple `effect()` calls in `initState()`, some disposed and some not** — should flag only the undisposed ones individually, not the whole method.

---

## Alternatives Considered

- **Treat all discarded `effect()` return values as errors even outside lifecycle scopes** — rejected; would over-flag legitimate one-shot process-level effects with no natural disposal scope, narrowing detection to recognized lifecycle-owning classes (`State`, controllers with a `dispose()` method) reduces false positives.

---

## Decision

---

## Implementation Notes

Shares reactive-type/tracking-context detection with `copied_reactive_collection_outside_tracking` and `effect_without_reactive_read` — build the shared `all_observer` recognition helper once.

---

## Commits
