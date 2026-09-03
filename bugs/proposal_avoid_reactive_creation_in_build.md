# PROPOSAL: Flag Reactive/Observable Object Creation Inside `build()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_io_in_computed`, `avoid_observable_write_during_observer_build`, `avoid_reactive_write_in_computed`

**Package dependency:** an observable/reactive-state package (e.g. `mobx`, `signals`). This rule only applies when such a package is a declared dependency.

---

## Summary

Add `avoid_reactive_creation_in_build` to flag construction of a new `Observable`/`Computed`/`signal()` instance directly inside a widget's `build()` method (or an `Observer`'s `builder` callback) — a reactive primitive created inside `build()` is recreated on every rebuild, discarding all of its prior subscribers and any accumulated state, which silently breaks reactivity: nothing observing the *previous* instance ever hears about changes to the *new* one.

**Closes gap:** all_observer_lint `avoid_reactive_creation_in_build`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Reactive primitives (`Observable`, `Computed`, `signal`) are meant to be created once and live for the lifetime of the owning object, exactly like a `StreamController` or `AnimationController`. Because `build()` runs on every frame/rebuild, an `Observable(0)` created inline there is a *new* object each time — any widget that previously subscribed to it is now watching a stale, orphaned instance, and the "reactive" value silently stops updating despite the code looking correct at a glance.

---

## Detection / Behavior

Flag an `InstanceCreationExpression`/factory call constructing a known reactive type (`Observable(...)`, `Computed(...)`, `signal(...)`, or a project-configured list of such constructors) found directly within the body of a `build()` method or an `Observer` `builder` callback.

### Should flag (bad code)

```dart
@override
Widget build(BuildContext context) {
  final counter = Observable(0); // LINT — new Observable created on every build
  return Observer(builder: (_) => Text('${counter.value}'));
}
```

### Should pass (good code)

```dart
final _counter = Observable(0); // OK — created once, outside build()

@override
Widget build(BuildContext context) {
  return Observer(builder: (_) => Text('${_counter.value}'));
}
```

---

## Proposed Tier

Tier: Professional
Justification: Silently broken reactivity (no compile error, no obvious runtime error — just values that stop updating) is a significant, hard-to-diagnose correctness bug; warrants earlier placement than most package-specific rules given the severity of the failure mode.

---

## Edge Cases

1. **Reactive object constructed inside `initState()` and stored in a field, read (not created) in `build()`** — should pass; this is the correct pattern the rule is steering developers toward.
2. **Reactive object created inside `build()` but memoized via a caching mechanism (e.g. `late final` lazily initialized on first build, never recreated after)** — should pass if the analyzer can confirm single-assignment semantics (e.g. `late final` field, not a local variable recreated every call); flag local-variable creation inside `build()` regardless of apparent "caching" via `??=` on a local, since locals don't survive across rebuilds.
3. **Reactive object created inside a `build()` method of a `StatelessWidget` whose instance itself is rebuilt fresh each time from a parent (i.e. no stable place to hoist the field to)** — needs discussion; document the recommended fix (lift state to a `StatefulWidget` or an external controller/store) since `StatelessWidget` genuinely has no safe place to hoist to.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only warn, never treat as an error-severity diagnostic** — rejected as the default; the failure mode (silently stale UI) is severe enough to warrant WARNING severity by default, though projects can override severity via `analysis_options_custom.yaml`.

---

## Decision

---

## Implementation Notes

---

## Commits
