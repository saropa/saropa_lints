# PROPOSAL: Flag Reassigning/Clearing a MobX ObservableList Instead of Using `assignAll`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `observer_without_reactive_read`

---

## Summary

Add `prefer_assign_all_for_reactive_list_replace` to flag replacing the entire contents of a MobX `ObservableList` by reassigning the field to a new list (`items = newItems;`) or by calling `.clear()` immediately followed by `.addAll(...)`, when `.assignAll(newItems)` performs the same replacement as a single, correctly-batched reactive operation.

**Closes gap:** `all_observer_lint` `prefer_assign_all_for_reactive_list_replace` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Reassigning an `ObservableList` field to a brand-new list breaks reference identity for anything holding onto the original observable instance — reactions and computed values that captured the original `ObservableList` reference stop tracking the new one. `.clear()` followed by `.addAll(...)` preserves the reference but fires two separate reactive notifications (one for the empty state, one for the refill), which can cause an observer to render a transient, visually-jarring empty state mid-update. `.assignAll()` replaces the contents in place as a single atomic reactive change.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class TodoStore {
  final ObservableList<Todo> todos = ObservableList<Todo>();

  void replaceAll(List<Todo> next) {
    todos.clear(); // LINT — clear() + addAll() fires two separate reactive notifications
    todos.addAll(next);
  }
}
```

### Should pass (good code)

```dart
class TodoStore {
  final ObservableList<Todo> todos = ObservableList<Todo>();

  void replaceAll(List<Todo> next) {
    todos.assignAll(next); // OK — single atomic reactive replacement
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to `mobx`'s `ObservableList` API; requires the `mobx` dependency and knowledge of which fields are `ObservableList`-typed.

---

## Edge Cases

1. **`.clear()` called with no following `.addAll(...)` (a genuine, permanent empty-out, not a replace)** — should pass; the rule targets the clear-then-refill pattern specifically, not clearing alone.
2. **Field reassignment where the field is not itself observable-tracked (a plain `List`, not `ObservableList`)** — should pass; the rule only applies to `ObservableList`-typed targets.
3. **`.addAll(...)` called without a preceding `.clear()`, appending to existing contents** — should pass; this is legitimate incremental growth, not a full replacement.
4. **Statements between `.clear()` and `.addAll(...)` (e.g. a log line)** — should still flag if the two calls target the same list with no observable-affecting statement between them; intervening non-reactive statements don't change the two-notification behavior.

---

## Alternatives Considered

- **Only flag field reassignment, skip the `clear()`+`addAll()` pattern** — rejected; both produce the same category of MobX reactivity bug (broken reference identity vs. double notification) and both are closed by the same `assignAll()` fix.

---

## Decision

---

## Implementation Notes

---

## Commits
