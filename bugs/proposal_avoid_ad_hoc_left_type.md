# PROPOSAL: Flag Ad-Hoc `Left`/`Right` Type Arguments in fpdart `Either`

**Status: Open**

Created: 2026-09-02
Type: New rule (package-specific — depends on the `fpdart` functional-programming package)
Related rules: none (first fpdart-family rule; see Implementation Notes on scoping this as a deliberate
package-adoption decision)

---

## Summary

Add `avoid_ad_hoc_left_type` to flag an `Either<L, R>` (or `TaskEither<L, R>`) value whose `L` (left/error)
type argument is an inline, unnamed, ad-hoc shape (a raw `String`, `Object`, or an anonymously-inferred
literal type) instead of a declared, reusable domain error/failure type. `fpdart`'s `Either` models the
error channel through its left type parameter, so an ad-hoc left type defeats the whole point of a typed
error channel — every call site has to re-discover what kind of failure can occur by reading the
implementation instead of the type signature.

**Closes gap:** `many_lints` `avoid_ad_hoc_left_type` (fpdart family, github.com/... many_lints). This is
part of Gap Theme 1 "fpdart / functional-programming ecosystem" — a deliberate adopt-fpdart-support decision,
not an incremental addition. Implementing this proposal (and its sibling fpdart proposals) as specified
closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`fpdart` is a widely used Dart/Flutter functional-programming package (`Either`, `Option`, `Task`,
`TaskEither`, `Do`-notation) and saropa currently has zero rules recognizing any of its types — a 100% gap
per the audit. This proposal targets the specific, well-defined footgun of the left-type-parameter being
left ad-hoc: teams adopting `Either`-based error handling specifically to get typed, exhaustive error
handling lose that benefit the moment `L` becomes `String`/`Object`/`dynamic`, since callers can no longer
pattern-match on a closed failure type.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Either<String, User> fetchUser(String id) { // LINT — avoid_ad_hoc_left_type: 'String' is an ad-hoc left type; declare a Failure type
  if (id.isEmpty) return Left('id required');
  return Right(User(id: id));
}
```

### Should pass (good code)

```dart
sealed class UserFailure {}
class InvalidIdFailure extends UserFailure {}

Either<UserFailure, User> fetchUser(String id) { // OK — declared, reusable failure type
  if (id.isEmpty) return Left(InvalidIdFailure());
  return Right(User(id: id));
}
```

---

## Proposed Tier

Tier: Comprehensive (package-dependent — see `fpdart` dependency note)
Justification: Only fires in projects depending on `fpdart`; type-design guidance rather than a universal
Dart correctness concern, matching saropa's placement for other single-package API-usage rules.

---

## Edge Cases

1. **`Either<Object, T>` used deliberately at a library boundary to accept any failure type from an
   upstream dependency** — needs discussion; `Object` may be an intentional escape hatch at an integration
   seam — consider exempting explicit `Object`/`Exception` when paired with a documented boundary comment, or
   scoping the rule to flag only `String`/primitive left types by default.
2. **`Either<Never, T>` or `Either<Unit, T>`** (fpdart idioms for "cannot fail" / "fails with no data") —
   should pass; these are recognized, intentional fpdart idioms, not ad-hoc shapes.
3. **A type alias wrapping the ad-hoc type** (`typedef AppError = String;`) — needs discussion; technically
   still `String` underneath, but the alias itself signals declared intent — likely still flag unless the
   alias is itself a distinct wrapper class, not a plain typedef.
4. **Project does not depend on `fpdart`** — must not fire; gate on package presence like saropa's other
   ecosystem-specific rules.

---

## Alternatives Considered

- **Defer this whole rule family until a broader "adopt fpdart" scoping decision is made** — this is the
  live alternative per `plans/GAP_ANALYSIS.md`'s own framing of Gap Theme 1 ("scope it as a deliberate
  'adopt fpdart package support' decision... not incremental additions"). This proposal is written assuming
  that decision is made affirmatively; if fpdart support is declined as a category, this and its sibling
  fpdart proposals (`avoid_bare_await_in_do`, `avoid_dollar_outside_do_frame`) should be declined together
  for the same reason, not individually re-litigated.

---

## Decision

---

## Implementation Notes

- Modeling `fpdart`'s type system (`Either`/`Option`/`Task`/`TaskEither`/`Do`) is shared infrastructure
  across all ~22 fpdart-family gap rules — implement a shared fpdart-type-recognition helper once, rather
  than duplicating `Either`/type-argument detection per rule.

---

## Commits
