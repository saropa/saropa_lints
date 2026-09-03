# PROPOSAL: Flag `ref.keepAlive()` Called Outside a Provider's Own Build Scope

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `notifier_build`

---

## Summary

Add `only_use_keep_alive_inside_keep_alive` to flag a call to Riverpod's `ref.keepAlive()` made from outside the body of the provider whose `ref` is being used — e.g. storing a `Ref` and calling `keepAlive()` on it later from an unrelated callback, or calling it on a `ref` captured from a different provider's scope.

**Closes gap:** `riverpod_lint` `only_use_keep_alive_inside_keep_alive` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`ref.keepAlive()` tells Riverpod "don't auto-dispose this specific provider instance when its last listener unsubscribes," and that decision only makes sense evaluated synchronously within the provider's own build/creation scope — Riverpod's disposal tracking is tied to that scope. Calling it later, from a stored `ref` or from inside an unrelated callback, targets a `ref` whose lifecycle context has already moved on, producing keep-alive behavior that doesn't do what the call site visually suggests.

---

## Detection / Behavior

### Should flag (bad code)

```dart
@riverpod
Stream<Data> dataStream(Ref ref) {
  final controller = StreamController<Data>();
  controller.onListen = () {
    ref.keepAlive(); // LINT — keepAlive() called from an async callback outside the provider's build scope
  };
  return controller.stream;
}
```

### Should pass (good code)

```dart
@riverpod
Stream<Data> dataStream(Ref ref) {
  ref.keepAlive(); // OK — called synchronously within the provider's own build scope
  final controller = StreamController<Data>();
  return controller.stream;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to Riverpod's `Ref.keepAlive()` API; requires the `riverpod`/`riverpod_annotation` dependency.

---

## Edge Cases

1. **`keepAlive()` called inside a synchronous helper function that is itself called directly and synchronously from the provider body, passing `ref` as a parameter** — needs discussion; may be a legitimate pattern if the helper executes within the same synchronous call stack as the build.
2. **`keepAlive()` called inside a `Future`/`Stream` callback registered during the synchronous build phase but invoked later** — should flag; execution has left the synchronous build scope even though the callback was registered inside it.
3. **`keepAlive()`'s returned `KeepAliveLink` stored and its `.close()` called later** — should pass; the rule targets the *call to* `keepAlive()`, not later use of its returned handle.
4. **Multiple `keepAlive()` calls within the same synchronous build body** — should pass; each is independently within scope.

---

## Alternatives Considered

- **Flag any `ref` stored outside the provider body regardless of what's called on it** — rejected as broader than the observed upstream rule; scoping specifically to `keepAlive()` calls matches the named rule and avoids over-flagging other legitimate deferred `ref` usage (like `ref.read` in a debounced callback).

---

## Decision

---

## Implementation Notes

---

## Commits
