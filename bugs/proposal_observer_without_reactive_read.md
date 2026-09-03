# PROPOSAL: Flag a MobX `Observer` Widget That Reads No Observable

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_assign_all_for_reactive_list_replace`

---

## Summary

Add `observer_without_reactive_read` to flag a MobX `Observer` widget whose `builder` callback never reads an `Observable`/`ObservableList`/computed value (or any tracked reactive value via a store getter). An `Observer` with no reactive read inside it can never be notified of a change — it renders once and stays frozen, which defeats its entire purpose and usually means the developer meant to read a different value than what's in the callback.

**Closes gap:** `all_observer_lint` `observer_without_reactive_read` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Observer` exists purely to subscribe its `builder` to whatever observables that builder reads during execution, using MobX's reactive-tracking mechanism. If the builder body reads only plain fields or non-observable values, the `Observer` wrapper is dead weight that also masks the real bug: the UI silently never updates when the store changes, and there's no compile error to point at the mistake — only a runtime "why isn't this updating" report.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CounterView extends StatelessWidget {
  final CounterStore store;
  const CounterView(this.store);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Text('${store.staticLabel}'), // LINT — reads a plain, non-observable field
    );
  }
}
```

### Should pass (good code)

```dart
class CounterView extends StatelessWidget {
  final CounterStore store;
  const CounterView(this.store);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Text('${store.count}'), // OK — `count` is an @observable field
    );
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to `mobx`/`flutter_mobx`'s `Observer` widget; requires those dependencies and knowledge of which store members are `@observable`/`@computed`.

---

## Edge Cases

1. **Builder reads an observable indirectly through a method call that itself reads observables internally** — needs discussion; static analysis can't see through arbitrary method bodies, so this may require limiting detection to direct field/getter reads recognizable as `@observable`/`@computed`.
2. **Builder body is empty or returns a constant widget with no store reference at all** — should flag with high confidence; clearly no reactive read is possible.
3. **`Observer` used only to scope a `context`-dependent rebuild unrelated to MobX (misuse of the widget for something else)** — should still flag; the rule concerns MobX reactivity regardless of the (mis)intended purpose.
4. **Nested `Observer` where the outer reads reactively but an inner nested `Observer` doesn't** — should flag the inner `Observer` independently; each `Observer` is evaluated on its own builder body.

---

## Alternatives Considered

- **Require explicit type information confirming a field is `@observable` before flagging** — accepted as the intended detection strategy; without this the rule cannot distinguish "reads a plain field" from "reads an observable field named similarly," and would be too noisy without it.

---

## Decision

---

## Implementation Notes

---

## Commits
