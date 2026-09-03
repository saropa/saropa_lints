# PROPOSAL: Flag `.getOrElse()` Fallbacks That Discard the `Left`/`None` Without Handling It

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_either_of_future`, `avoid_future_of_either`, `avoid_future_of_option`

**Package dependency:** `fpdart`. This rule only applies to projects using `package:fpdart` and should only run when fpdart is a declared dependency.

---

## Summary

Add `avoid_get_or_else_swallowing_failure` to flag `Either.getOrElse(() => fallback)` and `Option.getOrElse(() => fallback)` calls whose fallback closure is a bare constant/default with no logging, reporting, or rethrow of the discarded `Left`/`None` case — the failure information fpdart deliberately preserved in the `Either`/`Option` is thrown away silently at the exact point it becomes available.

**Closes gap:** many_lints `avoid_get_or_else_swallowing_failure` (fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

The entire value proposition of `Either<L, R>` over throwing exceptions is that the failure (`L`) is a first-class, inspectable value instead of an invisible side channel. Calling `.getOrElse(() => defaultValue)` without ever looking at the `L` that `getOrElse`'s callback receives (`Left`'s value, when in scope via `.getOrElse((failure) => ...)`) throws that information away — functionally identical to an empty `catch` block, just wearing fpdart's clothing.

---

## Detection / Behavior

Flag any `.getOrElse(...)` call on an `Either`/`Option`-typed receiver whose closure body neither references its failure parameter (for `Either`) nor contains any logging/reporting call, and is a trivial constant/expression fallback.

### Should flag (bad code)

```dart
final total = calculateTotal(order).getOrElse((_) => 0); // LINT — Left value ignored, no logging
```

### Should pass (good code)

```dart
final total = calculateTotal(order).getOrElse((failure) {
  logger.warning('calculateTotal failed, defaulting to 0', error: failure); // OK — failure observed
  return 0;
});
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) rule targeting a subtle silent-failure pattern; matches the tier placement of saropa's other fpdart rules.

---

## Edge Cases

1. **Fallback closure ignores the failure parameter but the failure is genuinely inconsequential (e.g. `Option.getOrElse` on a value that is optional by design, like a display placeholder)** — needs discussion; consider scoping the rule to `Either.getOrElse` only (where a `Left` represents an actual failure) and excluding `Option.getOrElse` (where `None` is often a legitimate "no value" state, not a failure) to avoid over-flagging.
2. **Fallback closure rethrows (`(failure) => throw StateError(failure)`)** — should pass; the failure is surfaced, just via exception instead of a default value.
3. **`.getOrElse(() => someLoggedFunction())` where the called function does its own logging internally** — needs discussion; static analysis cannot see inside the called function, so a first version may require the logging call to be inline, accepting some false negatives.
4. **Generated code (`.g.dart`, `.freezed.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Ban `.getOrElse()` entirely in favor of `.fold()`** — rejected; `.getOrElse()` is legitimate when the fallback genuinely doesn't need the failure (e.g. a documented, intentional default) — the rule targets silent swallowing, not the API itself.

---

## Decision

---

## Implementation Notes

---

## Commits
