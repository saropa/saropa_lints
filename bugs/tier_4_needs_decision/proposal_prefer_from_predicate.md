# PROPOSAL: Flag Manual Predicate-Check-Then-Wrap — Use `Option.fromPredicate`/`Either.fromPredicate` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_from_nullable`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_from_predicate` to flag a manual `condition(value) ? Some(value) : const None()` (or the `Either` equivalent, `condition(value) ? right(value) : left(error)`) pattern, recommending the built-in `Option.fromPredicate`/`Either.fromPredicate` constructors instead.

**Closes gap:** many_lints `prefer_from_predicate` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

Same rationale as `prefer_from_nullable`: fpdart ships a purpose-built constructor for "wrap this value only if a predicate holds," and spelling that out manually as a ternary duplicates a value reference (once in the predicate call, once in the `Some`/`right` branch), which is exactly the kind of duplication `fromPredicate` was designed to eliminate.

---

## Detection / Behavior

Flag a conditional expression whose condition is `predicate(value)` (or `value.someBoolProperty`/method call on `value`) and whose two branches are `Some(value)`/`const None()` for `Option`, or `right(value)`/`left(...)` for `Either`.

### Should flag (bad code)

```dart
Option<int> positiveOrNone(int value) {
  return value > 0 ? Some(value) : const None(); // LINT — use Option.fromPredicate(value, (v) => v > 0)
}

Either<String, int> positiveOrError(int value) {
  return value > 0 ? right(value) : left('not positive'); // LINT — use Either.fromPredicate
}
```

### Should pass (good code)

```dart
Option<int> positiveOrNone(int value) {
  return Option.fromPredicate(value, (v) => v > 0); // OK
}

Either<String, int> positiveOrError(int value) {
  return Either.fromPredicate(value, (v) => v > 0, (v) => 'not positive'); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific idiom substitution; part of the same family as `prefer_from_nullable`.

---

## Edge Cases

1. **Predicate references a different variable than the one wrapped** — should pass; `fromPredicate` requires the predicate to test the same value being wrapped, so a mismatch is not a valid rewrite target.
2. **`left(...)` branch computed from `value` (e.g. `left('invalid: $value')`)** — should still flag for the `Either` case since `Either.fromPredicate`'s third argument is itself a function of the value, so the rewrite is still valid.
3. **Compound boolean predicate (`value > 0 && value < 100`)** — should still flag; the predicate can be any boolean expression closed over `value`.

---

## Alternatives Considered

- **Combine with `prefer_from_nullable` into one rule** — rejected; keep as two separate rules matching many_lints' own separation, since one targets null-checks specifically and the other arbitrary predicates, and combining would complicate the single-responsibility AST match.

---

## Decision

---

## Implementation Notes

---

## Commits
