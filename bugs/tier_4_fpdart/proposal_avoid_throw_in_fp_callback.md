# PROPOSAL: Flag `throw` Inside fpdart Combinator Callbacks

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_throw_in_catch_block` (general throw-hygiene, not fpdart-specific), none in `lib/src/rules/packages/` yet — no existing `fpdart_rules.dart` file found

---

## Summary

Add `avoid_throw_in_fp_callback` to flag a `throw` statement or throw expression written inside a callback passed to an fpdart-style functional-programming combinator — `.map()`, `.flatMap()`, `.bind()`, `.chain()` on `Either`, `Option`, `Task`, `TaskEither`, and similar fpdart types. Throwing inside these callbacks silently reintroduces exception-based control flow into code that exists specifically to make error handling explicit and typed.

**Closes gap:** `many_lints` `avoid_throw_in_fp_callback` (pub.dev, fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 1" (fpdart rules).

---

## Motivation

The entire value proposition of `Either<L, R>`/`Option<T>`/`Task<T>` is that failure is a typed, inspectable value (`Left`, `None`) instead of a thrown exception that unwinds the stack and must be caught somewhere unrelated to where it originated. A `throw` inside a `.map()`/`.flatMap()` callback defeats that: callers who pattern-match on `Either`/`Option` never see the failure — it escapes as an uncaught exception instead, often crossing an `async` boundary where it becomes much harder to trace back to the fpdart pipeline that produced it. This is a well-known fpdart footgun specifically because the type signature *looks* like it guarantees no exceptions, making a stray `throw` inside a combinator callback a silent trap for anyone reading the call site. A grep of `lib/src/rules/packages/` confirms no `fpdart_rules.dart` file exists yet — this would be the first fpdart-specific rule in the package.

---

## Detection / Behavior

### Should flag (bad code)

```dart
Either<String, int> parsePositive(String input) {
  return Either.fromNullable(int.tryParse(input), () => 'not a number').map((n) {
    if (n <= 0) {
      throw ArgumentError('must be positive'); // LINT — throw inside .map() defeats Either's typed error channel
    }
    return n;
  });
}
```

### Should pass (good code)

```dart
Either<String, int> parsePositive(String input) {
  return Either.fromNullable(int.tryParse(input), () => 'not a number').flatMap((n) {
    if (n <= 0) {
      return Either.left('must be positive'); // OK — failure expressed as a typed Left, not a thrown exception
    }
    return Either.right(n);
  });
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) rule that only applies to projects that have opted into functional-programming-style error handling — irrelevant noise for the majority of projects not using fpdart, so it belongs alongside saropa's other opt-in, library-specific rules rather than a broadly-enabled tier.

---

## Edge Cases

1. **`throw` inside a `try`/`catch` that is itself inside the combinator callback, where the `catch` block converts the exception into a `Left`/`None`** — should pass; the throw is caught and converted before escaping the callback, so the typed-error contract is preserved.
2. **`throw` inside a nested closure that is NOT itself the direct combinator callback** (e.g. a callback passed to `List.forEach` inside the `.map()` body) — needs discussion; strictly the throw is still inside the outer `.map()` callback's lexical scope, so flagging is defensible, but a narrower implementation that only checks the combinator callback's own body (not further-nested closures) is simpler and lower-risk for false positives; start narrow.
3. **`TaskEither`/`Task` callbacks that are `async` and use `throw` before an `await`** — should flag same as synchronous callbacks; `Task`/`TaskEither` carry the same typed-error contract as `Either`.
4. **Rethrow (`rethrow`) inside a `.map()` callback used purely for logging before converting to `Left`** — should still flag if the rethrow ultimately escapes the callback uncaught; should pass if followed by conversion to a typed error value.
5. **Non-fpdart types with a coincidentally-named `.map()`/`.flatMap()`** (e.g. `Iterable.map`, `Stream.flatMap` from `rxdart`) — should pass; the rule must resolve the receiver's static type against fpdart's `Either`/`Option`/`Task`/`TaskEither` types specifically, not match on method name alone, to avoid false positives on unrelated `.map()` calls.

---

## Alternatives Considered

- **Flag `throw` anywhere inside any function that returns `Either`/`Option`** (not just inside combinator callbacks) — rejected as too broad; a function's own body legitimately choosing to throw before ever constructing an `Either` (e.g. a precondition check at the top of the function) is a different, more debatable style question than throwing *inside* a combinator callback that fpdart already invokes on your behalf as part of the typed pipeline.
- **Warn instead of flag-as-error, since some teams intentionally mix exceptions and `Either`** — addressed via tier placement (Comprehensive, opt-in) rather than severity; teams that want the fpdart discipline enforced strictly can enable it, others simply don't enable the tier/rule.

---

## Decision

---

## Implementation Notes

This is a package-specific (fpdart) rule — new file `lib/src/rules/packages/fpdart_rules.dart` (does not currently exist; confirmed via grep of `lib/src/rules/packages/`). Type resolution should check the combinator receiver's static type against fpdart's exported classes (`Either`, `Option`, `Task`, `TaskEither`, `IOEither`) via `DartType.getDisplayString()`/element source library check, following the same package-detection pattern used by other files in `lib/src/rules/packages/` (e.g. `bloc_rules.dart`, `equatable_rules.dart`) to confirm the fpdart package is actually a dependency before firing. Suggest Comprehensive or Pedantic tier per the batch instructions; Comprehensive chosen above since this is a real correctness footgun once a project has adopted fpdart, not merely a style nit.

---

## Commits
