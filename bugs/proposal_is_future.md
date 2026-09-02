# PROPOSAL: Flag Unreliable `is Future` Runtime Type Checks

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `is_future` to flag an `is Future` / `is Future<T>` type-check used to branch behavior on whether a value is asynchronous, instead of using the value's static (already-known) type or `async`/`await`. Runtime `is Future` checks are fragile because `Future<T>` erasure and `FutureOr<T>` make the check unreliable across generic boundaries.

**Closes gap:** `essential_lints` `is_future` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Branching on `value is Future` to decide whether to `await` something is a common workaround for poorly-typed APIs (often `dynamic` or `FutureOr<T>` parameters), but it's brittle: a `Future` subclass, a synchronous `FutureOr<T>` value, or a `dynamic` value that happens not to satisfy `is Future` all produce surprising behavior. The static type system already expresses "this may or may not be a Future" via `FutureOr<T>`, and the correct handling is `await Future.value(x)` or a proper `FutureOr<T>` signature — not a runtime type test.

---

## Detection / Behavior

Flag an `IsExpression` whose type annotation resolves to `Future` or `Future<T>` (excluding checks that are themselves inside generated/mock code).

### Should flag (bad code)

```dart
void handle(dynamic result) {
  if (result is Future) { // LINT — fragile runtime check; prefer FutureOr<T> typing + await
    result.then((value) => print(value));
  } else {
    print(result);
  }
}
```

### Should pass (good code)

```dart
Future<void> handle(FutureOr<Object?> result) async {
  final value = await result; // OK — FutureOr<T> + await handles both cases uniformly
  print(value);
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Catches a genuinely fragile async pattern with a clear, low-effort alternative (`FutureOr<T>` + `await`); broadly applicable enough for Recommended, not niche enough for Comprehensive.

---

## Edge Cases

1. **`is! Future` negated check** — should flag identically; the underlying fragility is the same regardless of negation.
2. **Check against a `Future<T>` return value coming from a third-party API the author doesn't control** — should still flag; correctionMessage should suggest wrapping with `Future.value()`/`await` rather than assuming control of the source type.
3. **Type-check used purely for logging/diagnostics, not control flow** — needs discussion; may still be worth flagging since `is Future` is unreliable even for diagnostics, but could be lower-severity.
4. **Generated code (`.g.dart`, `.mocks.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only flag when followed by `.then(...)` in the same branch** — rejected; narrows detection unnecessarily and misses the equally-fragile negative-branch pattern.

---

## Decision

---

## Implementation Notes

---

## Commits
