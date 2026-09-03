# PROPOSAL: Flag Method Tear-Offs Taken From a Reassignable Variable

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `mutable_tearoff` to flag a method tear-off (`final callback = someVar.method;`) whose receiver is a non-`final` local variable, field, or parameter. A tear-off captures the *current* value of the receiver at the moment it is taken — if the receiver is later reassigned, the tear-off silently keeps pointing at the old instance, which reads as a live binding but is not one.

**Closes gap:** `essential_lints` `mutable_tearoff` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Tear-offs look like references to "the current value of `x.method`", but they are actually bound to the object `x` held *at tear-off time*. When `x` is mutable, a reader reasonably assumes reassigning `x` changes what the stored callback does — it doesn't. This is a common source of stale-callback bugs in controller/notifier patterns where a field is swapped out (e.g. hot-reload, re-initialization) after a tear-off was already handed to a listener.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Controller {
  Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap; // LINT — tear-off from mutable field `handler`

  void swapHandler(Handler next) {
    handler = next; // onTap still calls the OLD handler's handleTap
  }
}
```

### Should pass (good code)

```dart
class Controller {
  final Handler handler = Handler(); // OK — final receiver, tear-off is safe
  late final VoidCallback onTap = handler.handleTap;
}
```

---

## Proposed Tier

Tier: Professional
Justification: catches a real stale-reference correctness bug, but only in the specific case of tearing off from a mutable receiver — not common enough to be Essential, but a genuine bug class worth Professional-tier coverage.

---

## Edge Cases

1. **Tear-off from a local variable that is reassigned before the tear-off is taken** — should pass; only the receiver's mutability at the point of tear-off matters, not its later history.
2. **Tear-off from `this` inside a class with mutable fields** — should pass; `this` itself cannot be reassigned even if fields are mutable.
3. **Tear-off from a `final` field whose *object* is internally mutable (e.g. a `final` controller with mutable state)** — should pass; the rule only concerns reassignment of the receiver reference, not the receiver's internal state.
4. **Tear-off immediately invoked (`someVar.method()`)** — should pass; this is a normal call, not a stored tear-off.

---

## Alternatives Considered

- **Flag tear-offs from any non-final receiver regardless of whether the tear-off is stored** — rejected; a tear-off passed directly as a one-shot argument (e.g. `list.forEach(mutableVar.method)`) is not a staleness risk since it isn't retained past the call.

---

## Decision

---

## Implementation Notes

---

## Commits
