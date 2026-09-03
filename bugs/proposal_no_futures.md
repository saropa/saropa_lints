# PROPOSAL: Flag Bare `Future`/`async` Usage Outside the Sanctioned Async Boundary

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `no_future_outcome_type`

---

## Summary

Add `no_futures` to flag declaring a function/method as returning a bare `Future<T>` (or being `async`) outside of a project-configured "async boundary" layer (e.g. a repository/data-source layer), pushing teams toward a safer async wrapper (structured concurrency helper, cancellation-aware task type, or the project's `AsyncOutcome`-style type) everywhere else in the codebase.

**Closes gap:** `df_safer_dart_lints` `no_futures` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Bare `Future`s have no built-in cancellation, no structured error channel distinct from synchronous exceptions, and no protection against being awaited after the widget/isolate that started them is gone — exactly the class of hazards `df_safer_dart_lints` targets. Concentrating raw `Future` usage at one sanctioned boundary layer means the rest of the codebase works through a safer, project-defined wrapper that adds cancellation and structured error handling.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class OrderService {
  Future<Order> submitOrder(Cart cart) async { // LINT — bare Future outside the sanctioned async boundary
    return api.submit(cart);
  }
}
```

### Should pass (good code)

```dart
class OrderService {
  CancelableTask<Order> submitOrder(Cart cart) { // OK — routed through the project's safe async wrapper
    return CancelableTask(() => api.submit(cart));
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: requires the project to have adopted a specific safe-async wrapper convention and to configure which layer is the sanctioned boundary; not actionable without that setup.

---

## Edge Cases

1. **Function inside the configured boundary layer (e.g. `*_data_source.dart` files)** — should pass; that layer is where bare `Future`s are expected to originate.
2. **`main()` and top-level `async` entry points** — should pass; these are unavoidable async boundaries in any Dart program.
3. **Overriding a `Future`-returning method from an external interface (e.g. Flutter's `State.didChangeDependencies`)** — should pass; the signature is dictated by the framework, not the author.
4. **`Future.value`/`Future.sync` used purely to satisfy a required synchronous-looking API without genuine async work** — needs discussion; may still count as "bare Future usage" under a strict reading.

---

## Alternatives Considered

- **Ban `Future` unconditionally everywhere, including the boundary layer** — rejected; the boundary layer necessarily talks to genuinely async platform/HTTP APIs, which return `Future` by definition, so a total ban has no valid escape hatch.

---

## Decision

---

## Implementation Notes

---

## Commits
