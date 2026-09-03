# PROPOSAL: Flag `Either<L, void>`/`TaskEither<L, void>` — Use fpdart's `Unit` Instead

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `prefer_unit_over_void` to flag `Either<L, void>`, `Option<void>`, or `TaskEither<L, void>` type usage, recommending fpdart's `Unit` type (and its singleton value `unit`) instead — `void` cannot be used as a real generic type argument in Dart the way a function's return position can, which produces awkward workarounds (`right(null)` typed as `Right<L, void>` doesn't actually type-check cleanly), while `Unit`/`unit` is a real, instantiable value designed exactly for this "successful, no payload" case.

**Closes gap:** many_lints `prefer_unit_over_void` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 1.

---

## Motivation

`void` is a special Dart construct meaning "the return value is meaningless, don't use it," not a normal type — it cannot be legally instantiated as a generic type argument value the way `Either`'s `Right(value)` constructor expects. Code that writes `Either<String, void>` typically has to fudge around this with `right(null)` and rely on the compiler treating `null` as convertible, which is exactly the "escape hatch to nullable" pattern the rest of the fpdart family of rules is meant to prevent. fpdart's `Unit` type and `unit` singleton value exist precisely to give "I succeeded, there's nothing else to say" a real, instantiable representative.

---

## Detection / Behavior

Flag any type annotation, generic type argument, or return type that is `Either<L, void>`, `Option<void>`, or `TaskEither<L, void>`.

### Should flag (bad code)

```dart
Either<String, void> validate(int value) { // LINT — use Either<String, Unit>
  if (value < 0) return left('negative');
  return right(null);
}
```

### Should pass (good code)

```dart
Either<String, Unit> validate(int value) {
  if (value < 0) return left('negative');
  return right(unit); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart-specific type-correctness idiom; part of the same family as the other fpdart rules.

---

## Edge Cases

1. **Ordinary Dart function returning plain `void` (no fpdart wrapper type)** — should pass; this rule targets `void` used as an fpdart wrapper's generic type argument specifically, not `void` as an ordinary function return type.
2. **`Future<void>` (no `Either`/`Option`/`TaskEither` involved)** — should pass; same scoping rationale.
3. **`Either<void, R>` (void on the left/error side)** — should also flag; `Unit` applies symmetrically to either type parameter position.

---

## Alternatives Considered

- **Recommend `Either<L, Never>` or a custom sentinel instead of `Unit`** — rejected; `Unit`/`unit` is fpdart's own purpose-built idiom for this, matching what the rest of the fpdart ecosystem (and many_lints) expects, so recommending a different pattern would fragment the codebase's fpdart style rather than converge it.

---

## Decision

---

## Implementation Notes

---

## Commits
