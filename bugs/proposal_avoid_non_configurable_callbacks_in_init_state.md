# PROPOSAL: Flag Hardcoded Inline Callbacks Constructed Directly in `initState`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_non_configurable_callbacks_in_init_state` to flag `initState()` bodies that wire up a listener/callback using an inline closure literal that is not backed by an overridable method or an injectable field — for example `_controller.addListener(() { setState(() {...}); })` — instead of `_controller.addListener(_onControllerChanged)`, where `_onControllerChanged` is a named method a subclass could override or a test could invoke/verify directly.

**Closes gap:** dart_code_linter `avoid_non_configurable_callbacks_in_init_state`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

An anonymous closure wired up in `initState()` cannot be referenced, overridden, unit-tested in isolation, or replaced by a subclass — it can only be exercised indirectly by driving the whole widget through a full listener trigger. Naming the callback as a method turns an opaque, closed-over block into a first-class, independently testable and overridable unit, at zero runtime cost.

---

## Detection / Behavior

Flag a `FunctionExpression` (closure literal) passed directly as an argument within `initState()` to a listener/callback-registration call (`addListener`, `addObserver`, event-stream `.listen()`, or a project-configured list of such APIs).

### Should flag (bad code)

```dart
@override
void initState() {
  super.initState();
  _controller.addListener(() { // LINT — inline closure, not overridable/testable
    setState(() {});
  });
}
```

### Should pass (good code)

```dart
@override
void initState() {
  super.initState();
  _controller.addListener(_onControllerChanged); // OK — named, overridable, testable
}

void _onControllerChanged() {
  setState(() {});
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Testability/style rule with legitimate exceptions (very short, self-contained closures); appropriate for a deep-review tier rather than default-on.

---

## Edge Cases

1. **A one-line, trivial closure with no captured state (`() => setState(() {})`)** — needs discussion; consider a length/complexity threshold (e.g. flag only closures with more than one statement) to avoid penalizing genuinely trivial wiring.
2. **Closure captures multiple local variables from `initState` that would need to become fields to extract into a method** — should still flag; the fix requires promoting captured locals to fields, which is exactly the refactor that makes the callback overridable/testable.
3. **`initState` registers a `StreamSubscription.listen()` with an inline closure used only to cancel-and-reassign, not real logic** — needs discussion; likely still worth flagging for consistency, but document as a candidate for a narrower complexity threshold if false-positive reports arrive.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Provide an automatic quick fix that extracts the closure into a named method** — deferred; extracting captured locals as fields safely (without breaking initialization order) is non-trivial; flag now, consider a fix in a follow-up.

---

## Decision

---

## Implementation Notes

---

## Commits
