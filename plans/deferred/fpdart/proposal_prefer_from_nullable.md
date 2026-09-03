# PROPOSAL: Flag Manual Null-Check-Then-Wrap — Use `Option.fromNullable` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_from_predicate`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_from_nullable` to flag a manual `value == null ? const None() : Some(value)` (or the equivalent `if`/ternary) pattern used to convert a nullable value into an fpdart `Option`, recommending the built-in `Option.fromNullable(value)` constructor instead.

**Closes gap:** many_lints `prefer_from_nullable` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

`Option.fromNullable` is the canonical, one-line fpdart idiom for this exact conversion. Spelling it out manually as a ternary or `if`/`else` adds visual noise, risks an off-by-one mistake (`Some(null)` if the null check is written backwards), and hides the intent ("this is a nullable-to-Option bridge") behind generic control flow that a reader has to parse to recognize.

---

## Detection / Behavior

Flag a conditional expression or `if`/`else` statement whose condition is a null check on `value` and whose two branches return `None()`/`const None()` and `Some(value)` respectively (in either order).

### Should flag (bad code)

```dart
Option<int> toOption(int? value) {
  return value == null ? const None() : Some(value); // LINT — use Option.fromNullable(value)
}
```

### Should pass (good code)

```dart
Option<int> toOption(int? value) {
  return Option.fromNullable(value); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific idiom substitution; part of the same family as the other fpdart constructor-preference rules.

---

## Edge Cases

1. **`Some(value!)` with a non-null assertion inside the non-null branch** — should still flag; the shape (null-check branching to `None`/`Some`) is what matters, not the exact null-safety spelling inside the branch.
2. **Branches that do additional work beyond wrapping (e.g. logging before returning `Some(value)`)** — should pass; only the pure wrap-only shape is flagged, since `fromNullable` cannot express extra side effects.
3. **Null check written as `value != null` with branches swapped** — should flag identically; the rule should be direction-agnostic.

---

## Alternatives Considered

- **Auto-fix that rewrites the ternary to `Option.fromNullable(value)`** — recommended as the initial quick fix given the pattern is purely mechanical (no side effects to preserve in the flagged shape); include in the initial implementation rather than deferring.

---

## Decision

---

## Implementation Notes

---

## Commits
