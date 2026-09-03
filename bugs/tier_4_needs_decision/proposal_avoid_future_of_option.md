# PROPOSAL: Flag `Future<Option<T>>` — Use `TaskOption` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_either_of_future`, `avoid_future_of_either`, `avoid_nested_do_notation`, `avoid_removed_fpdart_api`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_future_of_option` to flag declarations typed as `Future<Option<T>>` — fpdart provides `TaskOption<T>` as the direct, composable representation of "an asynchronous operation that may not produce a value," and wrapping a plain `Future` around `Option` forces an `await` before any `Option` combinator (`.map`, `.flatMap`, `.getOrElse`) can be used.

**Closes gap:** many_lints `avoid_future_of_option` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Just as `Future<Either<L, R>>` should be `TaskEither`, `Future<Option<T>>` should be `TaskOption<T>`. Without it, `Option`'s combinators can't see through the outer `Future`, so every call site awaits first and then manually checks `isSome`/`isNone`, undermining the point of adopting fpdart's option type for null-safety composition.

---

## Detection / Behavior

Flag any variable declaration, field declaration, or function/method return type that is exactly `Future<Option<T>>`.

### Should flag (bad code)

```dart
Future<Option<User>> findCachedUser(String id) async {
  // LINT — Future<Option<...>> should be TaskOption<...>
  final user = await _cache.get(id);
  return user == null ? none() : some(user);
}
```

### Should pass (good code)

```dart
TaskOption<User> findCachedUser(String id) {
  // OK — TaskOption models the async-and-optional lookup directly
  return TaskOption.tryCatch(() => _cache.get(id));
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) API-usage rule; only relevant to teams that have opted into functional-programming style, matching the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **`Future<Option<T>>` used as a function parameter accepting an externally-produced value** — should flag the same as the `avoid_future_of_either` parameter case; the conversion belongs at the boundary via `.toTaskOption()`.
2. **`Future<T?>` (nullable, not `Option`)** — out of scope; this rule targets `Option` specifically, not nullable types in general.
3. **Interop boundary with a non-fpdart third-party API** — needs discussion; same escape-hatch consideration as `avoid_future_of_either`.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Merge into a single generic "avoid Future-wrapping an fpdart monad" rule covering both `Either` and `Option`** — rejected in favor of matching the two distinct upstream rule names (`avoid_future_of_either`, `avoid_future_of_option`) for parity and independently tunable messaging, since the correct replacement type differs (`TaskEither` vs `TaskOption`).

---

## Decision

---

## Implementation Notes

---

## Commits
