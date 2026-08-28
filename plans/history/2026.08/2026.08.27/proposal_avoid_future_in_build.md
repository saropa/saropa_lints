# PROPOSAL: `avoid_future_in_build` — Detect Future creation inside build methods

**Status: Fixed (duplicate — existing rules strengthened)**

Created: 2026-08-27
Type: New rule
Related rules: none

---

## Summary

Flag `FutureBuilder` widgets whose `future:` argument is a method invocation (not a field reference), when the `FutureBuilder` is inside a `build()` method. This catches the async-in-build anti-pattern where a new Future is created on every rebuild, causing FutureBuilder to re-subscribe and re-fire the async work.

---

## Motivation

A full audit of `d:\src\contacts` found ~65 call sites passing a fresh `Future` from a method call directly into a `FutureBuilder` (or a widget parameter that feeds one). Each rebuild creates a new `Future` object; `FutureBuilder` compares by identity, so it restarts its subscription every time — re-firing DB queries, network calls, or computations and causing a brief flash to the loading state.

The correct pattern is to cache the Future in a `State` field (via `initState` or `??=` lazy assignment) and pass the cached field to `FutureBuilder`.

Prior art: the `unnecessary_rebuild` family of rules in other ecosystems; Riverpod's `ref.watch` vs `ref.read` distinction exists for the same reason.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: DatabaseIO.loadCount(), // LINT — method invocation in build
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }
}

class MyStateful extends StatefulWidget {
  @override
  State<MyStateful> createState() => _MyStatefulState();
}

class _MyStatefulState extends State<MyStateful> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: fetchData(widget.id), // LINT — method invocation in build
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }
}
```

### Should pass (good code)

```dart
class _MyWidgetState extends State<MyWidget> {
  late final Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _countFuture = DatabaseIO.loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture, // OK — field reference, not a method call
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }
}

class _LazyWidget extends State<LazyWidget> {
  Future<int>? _countFuture;

  @override
  Widget build(BuildContext context) {
    _countFuture ??= DatabaseIO.loadCount(); // OK — ??= caches after first call
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snapshot) => Text('${snapshot.data}'),
    );
  }
}
```

---

## Proposed Tier

Tier: Recommended
Justification: This catches a real, common bug (not a style preference) that causes unnecessary I/O, UI flicker, and test flakiness. The fix is always straightforward (cache in a field). Low false-positive risk since method invocations in the `future:` argument of a `FutureBuilder` inside `build()` are almost always wrong.

---

## Edge Cases

1. **`Future.value(x)` literals** — should pass (no I/O, deterministic). The rule should only flag method invocations that are NOT `Future.value` or `Future.error` constructors.
2. **Ternary with null** — `future: condition ? method() : null` should flag (the non-null branch creates a future inline).
3. **`??=` lazy assignment** — `_future ??= method()` should pass (the `??=` is the caching idiom).
4. **Custom widget parameters named `future:`** — should not flag; only flag when the enclosing widget type is `FutureBuilder` or a known wrapper.
5. **Named parameters that accept `Future<T>` on other widgets** — consider a broader variant that flags any `Future<T>` parameter receiving a method invocation in build. This would catch the `countFuture:` pattern. Could be a separate rule or a configuration option.

---

## Alternatives Considered

- **Only enforce via code review** — doesn't scale; 60+ sites were missed across years of development.
- **Change the API to accept builders instead of Futures** — being done in parallel for `countFuture` → `countBuilder`, but new code can still introduce the same pattern with other parameters.

---

## Decision

Closed as duplicate. Both `avoid_future_in_build` and `pass_existing_future_to_future_builder` already existed but had detection bugs that silenced most violations. Fixed in this session:
- `avoid_future_in_build` v3: removed name-prefix heuristic, now catches all method invocations
- `pass_existing_future_to_future_builder` v9: tightened cache-method exemption, exempted `Future.value()`/`Future.error()`

---

## Implementation Notes

Detection approach:
1. Register on `InstanceCreationExpression` where the type is `FutureBuilder`
2. Find the `future:` named argument
3. Check if the argument expression is a `MethodInvocation` or `FunctionExpressionInvocation`
4. Walk up the AST to confirm we're inside a `build()` method (method name == 'build', return type is `Widget`)
5. Exclude `??=` assignments (the parent is `AssignmentExpression` with `??=` operator)
6. Exclude `Future.value()` and `Future.error()` constructors

---

## Commits

<!-- Add commit hashes as implementation lands -->
