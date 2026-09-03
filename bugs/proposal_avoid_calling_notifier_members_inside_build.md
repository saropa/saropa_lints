# PROPOSAL: Flag Notifier Self-Calls Inside `build()`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ref_watch_outside_build`, `avoid_ref_read_inside_build`

---

## Summary

Flag a Riverpod `Notifier`/`AsyncNotifier` subclass calling its own methods or reading its own getters directly inside its own `build()` method, instead of accessing state through the normal `state` field or constructor-time setup.

**Closes gap:** DCM `avoid-calling-notifier-members-inside-build` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

A `Notifier.build()` method runs once per provider lifecycle to compute the initial state. Calling the notifier's own instance methods (especially ones that mutate `state`) from inside `build()` is a common Riverpod anti-pattern: `state` is not yet assigned during the first `build()` call, so a self-call that reads `state` can throw `LateInitializationError`, and a self-call that assigns `state` mid-`build()` produces a confusing double-initialization that fights the return value of `build()` itself. This is exactly the class of bug `avoid_ref_watch_outside_build` and `avoid_ref_read_inside_build` already guard against for `ref` usage — this rule closes the analogous gap for the notifier's own members. saropa_lints has no rule scoped to `Notifier.build()` self-calls today (confirmed by grep — zero matches for `avoid_calling_notifier_members_inside_build` in `lib/src/rules/`).

---

## Detection / Behavior

### Should flag (bad code)

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() {
    _loadInitialValue(); // LINT — calls own instance method from build()
    return 0;
  }

  void _loadInitialValue() {
    state = 42; // reassigns state mid-build via a self-call
  }

  void increment() {
    state = state + 1;
  }
}
```

```dart
class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() async {
    return refreshFromCache(); // LINT — public self-call inside build()
  }

  Future<Settings> refreshFromCache() async {
    final cached = await _readCache();
    state = AsyncData(cached); // mutates state from within build()'s call graph
    return cached;
  }
}
```

### Should pass (good code)

```dart
class CounterNotifier extends Notifier<int> {
  @override
  int build() {
    return _computeInitial(); // OK — pure helper, returns the value, does not touch state
  }

  int _computeInitial() => 0;

  void increment() {
    state = state + 1; // OK — outside build(), state already initialized
  }
}
```

```dart
class SettingsNotifier extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() async {
    return _readCache(); // OK — pure read, no state mutation, no self-call to a mutating member
  }

  void refresh() {
    state = AsyncValue.data(_current); // OK — called by UI action, not from build()
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This is a structural/correctness convention specific to Riverpod's `Notifier` lifecycle, not a broad correctness bug (it can produce a real `LateInitializationError`, but only when the self-called method touches `state`) — most Riverpod codebases will find it valuable but it's narrower than the widely-applicable Essential/Recommended rules already covering `ref.watch`/`ref.read` misuse. Consistent with sibling Riverpod naming/structure rules proposed alongside it (all Comprehensive).

---

## Edge Cases

1. **Self-call to a pure helper that never touches `state`** — should pass; detection should ideally distinguish "reads/writes state" methods from pure helpers, but a simpler first pass (any self-call from within `build()`, flagged at INFO/WARNING) is acceptable given false positives are rare and the correction is trivial (inline the helper or make it a top-level function).
2. **Calling an inherited method from `Notifier`/`AsyncNotifier` itself (e.g. `ref`, `state` getter)** — should pass; only user-defined instance methods/getters on the notifier class count.
3. **Calling a `static` method on the same class** — should pass; static members have no `state` coupling.
4. **`build()` awaiting a `Future` returned by a self-call in `AsyncNotifier`** — should flag; the same lifecycle hazard applies whether the call is awaited or not.
5. **Self-call from a nested closure inside `build()` (e.g. inside a `Future.microtask`)** — should flag if the closure executes synchronously as part of `build()`'s own call graph; needs care not to flag closures that are stored and invoked later (e.g. as an event handler), matching the same "don't recurse into stored callbacks" pattern used in `AvoidRefReadInsideBuildRule`.

---

## Alternatives Considered

- **Reuse `avoid_ref_read_inside_build`'s AST visitor pattern wholesale** — rejected as the sole detection; that rule targets `ref.read()` calls, this rule targets same-class member calls, which requires resolving `MethodInvocation`/`PropertyAccess` targets against the enclosing class's own member set (via `staticElement` or a simple `Set<String>` of declared member names), not a hardcoded `ref` identifier check.
- **Flag only methods that assign to `state`** — more precise but requires a preliminary pass to classify each method as "state-mutating" before the `build()` walk; deferred as a possible v2 of this rule rather than blocking the initial implementation, since the simple detection already produces low false-positive risk given the effort to write a pure vs. state-touching helper split.
