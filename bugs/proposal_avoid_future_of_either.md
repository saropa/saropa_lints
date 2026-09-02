# PROPOSAL: Flag `Future<Either<L, R>>` — Use `TaskEither` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_either_of_future`, `avoid_future_of_option`, `avoid_nested_do_notation`, `avoid_removed_fpdart_api`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_future_of_either` to flag declarations typed as `Future<Either<L, R>>` — fpdart provides `TaskEither<L, R>` as the direct, composable representation of "an asynchronous operation that can fail," and wrapping a plain `Future` around `Either` forces callers to `await` first and then separately fold/map the `Either`, instead of chaining fpdart combinators end-to-end.

**Closes gap:** many_lints `avoid_future_of_either` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Future<Either<L, R>>` type-checks and "works," but it defeats the purpose of adopting fpdart: none of `Either`'s `.map`/`.flatMap`/`.fold` combinators can see through the outer `Future`, so every call site has to `await` first, then manually branch. `TaskEither` composes with `.flatMap` across async steps without ever unwrapping early, keeping the functional-composition style consistent from the network call down to the UI layer.

---

## Detection / Behavior

Flag any variable declaration, field declaration, or function/method return type that is exactly `Future<Either<L, R>>`.

### Should flag (bad code)

```dart
Future<Either<String, User>> fetchUser(String id) async {
  // LINT — Future<Either<...>> should be TaskEither<...>
  try {
    final user = await _api.getUser(id);
    return right(user);
  } catch (e) {
    return left(e.toString());
  }
}
```

### Should pass (good code)

```dart
TaskEither<String, User> fetchUser(String id) {
  // OK — TaskEither models the async-and-fallible operation directly
  return TaskEither.tryCatch(
    () => _api.getUser(id),
    (error, _) => error.toString(),
  );
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) API-usage rule; only relevant to teams that have opted into functional-programming style, matching the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **`async` function whose body is a single `await`-and-return of an existing `Either`-returning call** — should still flag at the declaration/return-type level; the fix is to convert the whole chain to `TaskEither`.
2. **`Future<Either<L, R>>` used as a function *parameter* type (accepting an already-Future'd Either from external code)** — should flag the same; the boundary conversion belongs at the call site via `TaskEither.tryCatch` or `.toTaskEither()`, not by threading the awkward nested type through the codebase.
3. **Interop boundary with a non-fpdart third-party API that genuinely returns `Future<Either<...>>`** — needs discussion; consider a documented escape hatch (`// ignore:` with justification) for external SDK boundaries rather than special-casing in the rule.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Provide an automatic quick fix rewriting the signature to `TaskEither`** — deferred to a follow-up; the body also needs restructuring (replacing `try/catch` + manual `left`/`right` with `TaskEither.tryCatch`), which is not a mechanical rename and risks producing code that doesn't compile.

---

## Decision

---

## Implementation Notes

---

## Commits
