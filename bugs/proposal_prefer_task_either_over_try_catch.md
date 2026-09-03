# PROPOSAL: Flag `try`/`catch` Around an Async Operation — Use `TaskEither.tryCatch` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_chaining_over_intermediate_run`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_task_either_over_try_catch` to flag a `try`/`catch` block wrapping an `await`ed async call inside a function whose return type is (or should be, given the fpdart-adopting codebase) `TaskEither`, recommending `TaskEither.tryCatch(() => future, (error, stack) => mappedError)` instead — which captures the same failure but returns it as a `Left` rather than throwing.

**Closes gap:** many_lints `prefer_task_either_over_try_catch` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

Once a codebase has adopted `TaskEither` as its error-handling type for async operations, a stray `try`/`catch` inside a `TaskEither`-returning function is a leak: it catches the exception in an imperative style disconnected from the function's own declared error channel, and the caller has no static guarantee the function won't also throw for cases the author forgot to wrap. `TaskEither.tryCatch` makes the exception-to-`Left` conversion the function's actual return value, so every failure path is visible in the type signature.

---

## Detection / Behavior

Flag a `try`/`catch` statement located inside a function/method whose declared return type is `TaskEither<L, R>` (or `Future<Either<L, R>>`), where the `try` block contains an `await` and the `catch` block converts the caught error into a `Left`/returns early.

### Should flag (bad code)

```dart
TaskEither<String, int> fetchCount() {
  return TaskEither(() async {
    try {
      final count = await _networkFetch(); // LINT — inside TaskEither-returning code, use TaskEither.tryCatch
      return right(count);
    } catch (e) {
      return left(e.toString());
    }
  });
}
```

### Should pass (good code)

```dart
TaskEither<String, int> fetchCount() {
  return TaskEither.tryCatch(
    () => _networkFetch(),
    (error, stack) => error.toString(),
  ); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific idiom, scoped to `TaskEither`-returning functions; matches the rest of the fpdart family's tier placement.

---

## Edge Cases

1. **`try`/`catch` inside a `TaskEither`-returning function that is NOT wrapping the async operation feeding the return value (e.g. logging-only catch that rethrows)** — should pass; only flag when the catch block is the mechanism producing the function's `Left`.
2. **`try`/`catch` inside a non-`TaskEither`, non-`Either`-returning function** — should pass; scope strictly to functions whose return type is fpdart's async-error type.
3. **`try`/`catch`/`finally` where `finally` performs cleanup (e.g. closing a resource)** — should still flag the `try`/`catch` shape for the `TaskEither.tryCatch` rewrite; `finally`-based cleanup is orthogonal and `TaskEither.tryCatch` doesn't preclude wrapping the whole thing in a `try`/`finally` if genuinely needed, so the correction message should note that caveat rather than silently dropping it.

---

## Alternatives Considered

- **Auto-fix that rewrites the `try`/`catch` into `TaskEither.tryCatch`** — worth pursuing once the detection is stable, since the source-to-error mapping is often mechanical; defer to implementation, as the `catch` block's error-transformation logic can be arbitrarily complex and a naive fix could drop it.

---

## Decision

---

## Implementation Notes

---

## Commits
