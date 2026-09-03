# PROPOSAL: `avoid_untyped_safe_cast` — Flag a "Safe Cast" With No Concrete Target Type

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Flag an fpdart-style "safe cast" combinator/helper call (or a raw `as` cast used inside an `Option`/`Either` construction meant to safely wrap a cast) where the target type is unspecified or infers to `dynamic` — an untyped safe cast defeats the purpose of the wrapper, since `dynamic` accepts anything and the "safety" degenerates into a no-op that always succeeds.

**Closes gap:** `many_lints` `avoid_untyped_safe_cast` (github.com/Nikoro/many_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "fpdart / functional-programming ecosystem" theme.

---

## Motivation

The whole point of a "safe cast" wrapper (an fpdart-style helper that turns a potentially-failing `as SomeType` into an `Option<SomeType>`/`Either<Failure, SomeType>` instead of throwing) is that it reports failure through the wrapper's type instead of a `CastError`/`TypeError`. If the target type is left unspecified and infers to `dynamic` — e.g. `Option.tryCatch(() => value as dynamic)` or a generic `safeCast<T>()` helper called without an explicit type argument in a context where `T` infers to `dynamic` — the cast can never fail (`dynamic` accepts any value), so the function always returns `Some`/`Right` regardless of what `value` actually is. The code reads as if it validates the runtime type of `value`, but it validates nothing; a caller who later relies on the wrapped value having the expected shape gets a runtime error somewhere downstream instead of a clean `None`/`Left` at the cast site. This is the same class of footgun as an untyped `as dynamic` cast in general Dart code, but sharper here because the surrounding code explicitly signals "this is the safe, validated path."

---

## Detection / Behavior

### Should flag (bad code)

```dart
import 'package:fpdart/fpdart.dart';

// Target type is unspecified — infers to dynamic, so the cast can never fail.
Option<dynamic> parseConfig(Object? raw) {
  return Option.tryCatch(() => raw as dynamic); // LINT — dynamic safe cast is a no-op
}

// Generic helper called without a type argument that would let the compiler
// infer a concrete type from context also infers to dynamic here.
final result = safeCast(raw); // LINT — no target type available
```

### Should pass (good code)

```dart
import 'package:fpdart/fpdart.dart';

Option<Map<String, Object?>> parseConfig(Object? raw) {
  return Option.tryCatch(() => raw as Map<String, Object?>); // OK — concrete target type
}

final result = safeCast<UserProfile>(raw); // OK — explicit type argument
```

---

## Proposed Tier

Tier: Comprehensive
Justification: fpdart is a niche, opt-in functional-programming dependency, consistent with the tier placement proposed for the rest of the fpdart family (`avoid_unrun_task` and others) — should not activate for the majority of projects with no fpdart dependency.

---

## Edge Cases

1. **Cast target is `Object` or `Object?`** — should flag same as `dynamic`; both accept virtually any value, so the safety check is equally vacuous (a value is always an `Object?`).
2. **Cast target is a type parameter `T` that is itself unconstrained and not pinned by an explicit type argument at the call site** — should flag; without a concrete argument, `T` infers to `dynamic` at that call site and the same vacuous-cast problem applies.
3. **Cast target is a concrete but overly broad type intentionally** (e.g. `as num` where both `int` and `double` are valid and acceptable) — should pass; `num` is a real, non-trivial constraint even though it accepts two subtypes, unlike `dynamic`/`Object` which accept everything.
4. **`as dynamic` used outside any Option/Either/safe-cast wrapper** (an ordinary cast in unrelated code) — should pass; this rule is scoped to the safe-cast pattern specifically, not general `as dynamic` usage, since a generic "avoid dynamic casts" rule is a different (and likely already-covered) concern.
5. **Explicit type argument provided but with `dynamic` as the argument itself** (`safeCast<dynamic>(raw)`) — should flag; explicit `dynamic` is exactly as vacuous as inferred `dynamic`.

---

## Alternatives Considered

- **Generalize to flag any `as dynamic` cast anywhere in the codebase** — rejected for this proposal; that is a broader, more general "avoid dynamic casts" rule with a different risk profile (not every `as dynamic` sits inside a safety wrapper claiming to validate the cast) and may already exist in saropa's general type-safety rules — check `lib/src/rules/data/type_safety_rules.dart` before building a separate general rule to avoid duplicate coverage.
- **Only detect the literal fpdart `Option.tryCatch`/`Either.tryCatch` call shape** rather than also a generic `safeCast<T>()` helper convention — considered as a narrower, lower-false-positive first cut; the many_lints rule name suggests broader "safe cast" combinator coverage, so both shapes are included here, but the fpdart-specific `tryCatch` shape is the safer starting point if implementation effort needs to be scoped down.

---

## Decision

---

## Implementation Notes

Package-specific (fpdart) — same gating consideration as `avoid_unrun_task`: only activate for projects depending on `fpdart`. Detecting "target type infers to `dynamic`" requires `usesTypeResolution: true` and inspecting the static type of the `AsExpression`'s type annotation (or the inferred type argument for a generic helper call) rather than string-matching on `dynamic` literally, since the interesting case (`safeCast(raw)` with no explicit argument) has no literal `dynamic` token in the source at all.

---

## Commits
