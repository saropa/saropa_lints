# PROPOSAL: Flag Nested fpdart `Do` Notation Blocks

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_either_of_future`, `avoid_future_of_either`, `avoid_future_of_option`, `avoid_get_or_else_swallowing_failure`, `avoid_removed_fpdart_api`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_nested_do_notation` to flag one fpdart `Do` notation block (`Either.Do((_) { ... })`, `TaskEither.Do((_) { ... })`, etc.) declared directly inside the body of another `Do` block — nesting defeats the readability purpose of `Do` notation, which exists specifically to flatten a chain of `.flatMap` calls into sequential, linear-looking statements; a nested `Do` reintroduces the same visual/control-flow indentation the outer `Do` was adopted to avoid.

**Closes gap:** many_lints `avoid_nested_do_notation` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`Do` notation's entire value is flattening monadic chains into readable, sequential code. Nesting one `Do` block inside another produces exactly the layered, hard-to-follow structure `Do` was meant to eliminate, and usually indicates the inner computation should be extracted into its own function returning `Either`/`TaskEither`/`Option` and then invoked (and `await`'d/bound) from the outer `Do` block as a single step.

---

## Detection / Behavior

Flag any `Do(...)`-style factory invocation (`Either.Do`, `Option.Do`, `TaskEither.Do`, `TaskOption.Do`, or configured equivalents) found lexically within the closure body of another such invocation.

### Should flag (bad code)

```dart
Either<String, int> compute() => Either.Do((_) {
  final a = _(_stepOne());
  final b = _(Either.Do((_) { // LINT — nested Do block
    final x = _(_stepTwoA());
    final y = _(_stepTwoB());
    return x + y;
  }));
  return a + b;
});
```

### Should pass (good code)

```dart
Either<String, int> _stepTwo() => Either.Do((_) {
  final x = _(_stepTwoA());
  final y = _(_stepTwoB());
  return x + y;
});

Either<String, int> compute() => Either.Do((_) {
  final a = _(_stepOne());
  final b = _(_stepTwo()); // OK — extracted, invoked as one step
  return a + b;
});
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) style rule targeting readability of functional-composition code; matches the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **Inner `Do` block is inside a closure passed as an *argument* to a call within the outer `Do`, not directly a step of it (e.g. inside a `.map()` callback)** — should still flag; nesting is nesting regardless of the exact intermediate call, since the readability cost is the same.
2. **Two `Do` blocks that are siblings (one after another, not nested) in the same function** — should pass; sequential, non-nested `Do` blocks are fine and don't recreate the indentation problem.
3. **Inner `Do` block for a *different* monad type than the outer (`TaskEither.Do` inside `Either.Do`)** — should still flag; the nesting/readability problem is the same regardless of whether the monads match.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Provide an automatic quick fix extracting the inner `Do` block into a private function** — deferred; inferring captured variables and a correct return type automatically is non-trivial and risks producing code that doesn't compile; flag now, consider a fix in a follow-up.

---

## Decision

---

## Implementation Notes

---

## Commits
