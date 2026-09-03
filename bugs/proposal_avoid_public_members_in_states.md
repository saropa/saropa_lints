# PROPOSAL: Flag Public Fields/Methods on `State<StatefulWidget>` Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_public_members_in_states` to flag public (non-underscore-prefixed) fields and methods declared on a `State<T>` subclass — `State` objects are Flutter-internal implementation detail accessed only via `GlobalKey`/`context.findAncestorStateOfType`, and exposing public members on them invites external code to reach into a widget's private mutable state directly, bypassing the `StatefulWidget`'s own public API surface (its constructor parameters) entirely.

**Closes gap:** pyramid_lint `avoid_public_members_in_states`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Flutter's own convention is that a `StatefulWidget`'s public configuration lives on the widget class, while its `State` class holds private, mutable, lifecycle-bound implementation. A public member on `State` is a backdoor: it can be reached via `GlobalKey<MyState>().currentState?.someMethod()`, which couples calling code to internal implementation details that were never designed as a stable API, breaks encapsulation, and makes it impossible to refactor the `State` class's internals without a wider blast radius than intended.

---

## Detection / Behavior

Flag any field or method declaration on a class extending `State<...>` (directly or transitively) whose name does not begin with `_`, excluding required overrides (`build`, `initState`, `dispose`, etc.) and the `widget` getter itself.

### Should flag (bad code)

```dart
class _CounterState extends State<Counter> {
  int count = 0; // LINT — public field on State

  void increment() { // LINT — public method on State
    setState(() => count++);
  }

  @override
  Widget build(BuildContext context) => Text('$count');
}
```

### Should pass (good code)

```dart
class _CounterState extends State<Counter> {
  int _count = 0; // OK — private

  void _increment() { // OK — private
    setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) => Text('$_count');
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Encapsulation-breaking `GlobalKey`-reach-through-`State` is a recurring real-world Flutter architecture smell; default-on placement is warranted, with framework-required overrides excluded to avoid noise.

---

## Edge Cases

1. **Framework-required overrides (`build`, `initState`, `dispose`, `didUpdateWidget`, `didChangeDependencies`)** — should pass; these are mandated by the `State` contract and cannot be renamed private.
2. **Public method intentionally exposed for a documented `GlobalKey`-based imperative API (e.g. a `FormState`-style `validate()`/`save()` pattern used by Flutter's own `Form` widget)** — needs discussion; this is a real, framework-sanctioned pattern (`FormState.validate()`). Recommend excluding classes/members annotated with a documented marker (e.g. `@visibleForImperativeApi` convention) or allowing suppression with justification, rather than blanket-exempting all `State` public members.
3. **`widget` getter (inherited from `State`, exposes the associated `StatefulWidget`)** — should pass; this is inherited framework API, not a project-declared member.
4. **Public getter with no corresponding setter, used only for a test helper (`@visibleForTesting`)** — should pass if annotated `@visibleForTesting`, matching the existing Flutter convention for intentionally test-only public surface.

---

## Alternatives Considered

- **Flag `GlobalKey<SomeState>` usage instead of the `State` class's members** — rejected; flagging at the `State` declaration site catches the problem at its source (before any `GlobalKey` reach-through exists) rather than only after a caller has already built the anti-pattern.

---

## Decision

---

## Implementation Notes

---

## Commits
