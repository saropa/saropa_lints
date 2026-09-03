# PROPOSAL: Flag Manual Either/Option Unwrapping in Favor of fpdart's `andThen`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_and_then` to flag manual pattern-matching/unwrapping of an `fpdart` `Either`/`Option`/`TaskEither` value (e.g. `.match(...)` or a manual `isLeft()`/`isRight()` branch) purely to chain into another `Either`/`Option`-returning operation, where `.andThen(...)`/`.flatMap(...)` expresses the same chain as a single combinator call without leaving the monadic type.

**Closes gap:** `many_lints` `prefer_and_then` (fpdart family; pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The entire value of adopting `fpdart`'s `Either`/`Option` types is staying inside the monadic chain so failures propagate automatically without manual branching at every step. Manually unwrapping a result just to immediately feed it into another `Either`-returning call reintroduces the imperative branching `fpdart` was adopted to avoid, and risks forgetting to propagate the `Left`/`None` case correctly on one of the manual branches.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Either<Failure, Order> processOrder(Cart cart) {
  final validated = validateCart(cart);
  if (validated.isLeft()) {
    return validated as Either<Failure, Order>; // LINT — manual unwrap-and-rebranch instead of andThen
  }
  return submitOrder(validated.getOrElse((_) => throw StateError('unreachable')));
}
```

### Should pass (good code)

```dart
Either<Failure, Order> processOrder(Cart cart) {
  return validateCart(cart).andThen(submitOrder); // OK — chains without leaving the Either
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: package-specific to `fpdart`'s combinator API; requires the `fpdart` dependency and only applies to codebases that have adopted its functional style.

---

## Edge Cases

1. **Manual `.match(...)` used because the two branches genuinely return different, non-`Either` types (e.g. one branch shows a dialog, the other navigates)** — should pass; `andThen` only replaces same-type-chaining unwraps, not branches that terminate the `Either` chain for good reason.
2. **`.getOrElse(...)` used to supply a default value, not to re-chain into another `Either`-returning call** — should pass; that's the correct, idiomatic terminal use of `Either`.
3. **Chain of three or more manual unwraps in sequence** — should flag each opportunity; a whole pipeline of manual unwraps is the strongest case for `andThen`/`flatMap` chaining.
4. **`Option` used instead of `Either`** — should flag under the same rationale; `Option.andThen`/`flatMap` closes the identical gap for the non-error-carrying monadic type.

---

## Alternatives Considered

- **Only flag `Either`, skip `Option`/`TaskEither`** — rejected; the upstream `many_lints` rule is documented against the fpdart family broadly, and the manual-unwrap anti-pattern applies identically across all three types.

---

## Decision

---

## Implementation Notes

---

## Commits
