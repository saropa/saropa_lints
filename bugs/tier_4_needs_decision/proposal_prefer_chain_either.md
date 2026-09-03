# PROPOSAL: Flag Manual `Either` Unwrap-Then-Rewrap Chains — Use `.flatMap`/`.map` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_chaining_over_intermediate_run`, `prefer_do_notation`, `avoid_either_of_future`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_chain_either` to flag code that manually branches on an `Either` (via `.fold`, `isLeft`/`isRight` checks, or `.getOrElse` followed by re-wrapping) purely to feed the unwrapped value into another `Either`-returning operation, instead of composing directly with `.flatMap`/`.map`.

**Closes gap:** many_lints `prefer_chain_either` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

`Either`'s entire value proposition is short-circuiting composition: `.flatMap`/`.map` propagate a `Left` automatically without the caller re-checking it at every step. Manually unwrapping via `.fold` or a runtime `isLeft`/`isRight` check and then re-wrapping the result defeats that guarantee — it is easy to forget to propagate the original `Left` correctly, and it reintroduces the exact imperative branching fpdart is meant to eliminate.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Either<String, int> parseAndDouble(Either<String, int> input) {
  if (input.isRight()) {
    final value = input.getOrElse((_) => 0);
    return right(value * 2); // LINT — manual unwrap/rewrap; use input.map((v) => v * 2)
  }
  return input;
}
```

### Should pass (good code)

```dart
Either<String, int> parseAndDouble(Either<String, int> input) {
  return input.map((value) => value * 2); // OK — composed directly
}

Either<String, int> parseAndValidate(Either<String, int> input) {
  return input.flatMap((value) => value > 0 ? right(value) : left('non-positive')); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific composition idiom; only relevant to projects that have opted into functional-error-handling style, so it belongs alongside the rest of the fpdart family rather than a default-on tier.

---

## Edge Cases

1. **`.fold` used for genuinely branching into two different side effects (e.g. logging then returning different values)** — should pass; `.fold` is the correct tool when the two branches produce meaningfully different outcomes, not just re-wrapped values.
2. **`isLeft()`/`isRight()` check with no subsequent re-wrap (e.g. just returning a bool)** — should pass; only the unwrap-then-rewrap-into-`Either` shape is flagged.
3. **Nested `Either<L, Either<L, R>>` chains** — should flag each unwrap-rewrap independently; a quick fix should not attempt to auto-flatten multiple levels at once.
4. **Async equivalent (`TaskEither`)** — should flag the same pattern on `TaskEither`, since it shares the `.flatMap`/`.map` API.

---

## Alternatives Considered

- **Also cover `Option`'s equivalent unwrap/rewrap pattern in this same rule** — rejected; keep scope to `Either`/`TaskEither` and let a companion rule (not in this batch) cover `Option` separately, matching many_lints' own separation of concerns.

---

## Decision

---

## Implementation Notes

---

## Commits
