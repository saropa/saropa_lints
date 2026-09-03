# PROPOSAL: Flag Deeply Nested `.flatMap` Chains — Use fpdart's Do-Notation Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_chain_either`, `prefer_chaining_over_intermediate_run`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_do_notation` to flag `Either`/`Option`/`TaskEither` pipelines with 3+ nested `.flatMap` callbacks, recommending fpdart's `Either.Do`/`Option.Do`/`TaskEither.Do` builder (`$.apply`-style) instead, which reads as a flat sequence of bound values rather than a right-drifting pyramid of nested closures.

**Closes gap:** many_lints `prefer_do_notation` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

Deeply nested `.flatMap` calls suffer the same "pyramid of doom" readability problem as nested callbacks in any language — each level indents further and each intermediate value's scope is implicit in the closure nesting. fpdart's do-notation exists specifically to let each bound value read as a flat statement (`final a = await $(taskA); final b = await $(taskB(a));`), which is far easier to scan and modify than nested `.flatMap` closures.

---

## Detection / Behavior

Flag a `.flatMap` call chain where the callback of an outer `.flatMap` itself contains another `.flatMap` call nested inside its callback, three or more levels deep, all on `Either`/`Option`/`TaskEither` receivers.

### Should flag (bad code)

```dart
Either<String, int> compute(Either<String, int> a) {
  return a.flatMap((x) =>
    fetchB(x).flatMap((y) =>
      fetchC(y).flatMap((z) => // LINT — 3+ levels of nested flatMap; use Either.Do
        right(x + y + z))));
}
```

### Should pass (good code)

```dart
Either<String, int> compute(Either<String, int> a) {
  return Either.Do(($) {
    final x = $(a);
    final y = $(fetchB(x));
    final z = $(fetchC(y));
    return x + y + z; // OK — flat do-notation sequence
  });
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific style rule targeting a readability smell, not a correctness bug; matches the rest of the fpdart family's tier placement.

---

## Edge Cases

1. **Exactly 2 levels of nesting** — should pass; the threshold matches many_lints' own 3-level trigger to avoid flagging simple, still-readable two-step chains.
2. **`.map` (not `.flatMap`) nested inside a `.flatMap` callback** — should not count toward the nesting depth; `.map` doesn't introduce another `Either`-returning branch point.
3. **Chain broken up with named intermediate functions instead of inline closures** — should pass; the rule inspects lexical nesting depth in one expression, not the total number of `.flatMap` calls across a function.

---

## Alternatives Considered

- **Flag any 2+ level nesting** — rejected; too aggressive, would fire on the common and still-readable two-step chain pattern that many_lints itself treats as acceptable.

---

## Decision

---

## Implementation Notes

---

## Commits
