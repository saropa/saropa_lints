# PROPOSAL: Flag `Either<L, Future<R>>` — Use `TaskEither` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_future_of_either`, `avoid_future_of_option`, `avoid_nested_do_notation`, `avoid_removed_fpdart_api`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_either_of_future` to flag declarations typed as `Either<L, Future<R>>` (a `Future` nested inside the `Right`/`Left` of an `Either`) — fpdart provides `TaskEither<L, R>` specifically to represent an asynchronous computation that can fail, and nesting a raw `Future` inside `Either` produces a value that cannot be awaited or chained through fpdart's combinators without manually unwrapping first.

**Closes gap:** many_lints `avoid_either_of_future` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Either<L, Future<R>>` is a type that type-checks but is almost never what the author wants: the `Future` is opaque to `Either`'s `map`/`flatMap`/`fold` combinators, so callers must manually branch on the `Either` and then separately await the `Future`, defeating the point of using fpdart's functional composition. `TaskEither<L, R>` exists precisely to model "an async operation that produces a `Left` or `Right`" and composes correctly with `.flatMap`, `.map`, and `.run()`.

---

## Detection / Behavior

Flag any variable declaration, field declaration, or function/method return type that is `Either<L, Future<R>>` (i.e. `Either` whose right-hand type argument, or left-hand type argument, is itself a `Future`/`FutureOr`).

### Should flag (bad code)

```dart
Either<String, Future<int>> fetchCount() {
  // LINT — Future nested inside Either; combinators can't see through it
  return right(_fetchCountFromNetwork());
}
```

### Should pass (good code)

```dart
TaskEither<String, int> fetchCount() {
  // OK — TaskEither models an async computation that can fail
  return TaskEither.tryCatch(
    () => _fetchCountFromNetwork(),
    (error, _) => error.toString(),
  );
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) correctness/API-usage rule; only relevant to teams that have opted into functional-programming style, matching the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **`Either<L, Future<R>>` used only as an intermediate before immediate `.fold`-and-await** — still flag; even short-lived misuse should route through `TaskEither`.
2. **`Either<Future<L>, R>` (Future in the `Left` position)** — should flag; the type is symmetric and the mistake is the same on either side.
3. **`Either<L, R>` where `R` is a user type that merely contains a `Future` field internally** — should pass; the rule targets the direct type argument, not nested user types.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Flag any `Future` type argument anywhere in generics** — rejected; too broad, would false-positive on legitimate collections of futures (`List<Future<T>>`).

---

## Decision

---

## Implementation Notes

---

## Commits
