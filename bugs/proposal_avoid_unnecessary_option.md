# PROPOSAL: Flag Round-Tripping Through `Option` With No Branching

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none (no existing fpdart-specific rule file in `lib/src/rules/packages/`)

---

## Summary

Add `avoid_unnecessary_option` to flag wrapping a value in `Option.of(...)`/`Some(...)` and then immediately unwrapping it again (`.getOrElse(...)`, `.toNullable()`, a pattern match) within the same expression or local scope, with no intervening branching, `Option`-combinator chaining, or storage of the `Option` value elsewhere. This round-trip adds fpdart's `Option` machinery around a value without ever using it for what `Option` is for — expressing and safely propagating the possibility of absence.

**Closes gap:** `many_lints` `avoid_unnecessary_option` (pub.dev, fpdart family). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 1" (fpdart rules).

---

## Motivation

`Option<T>` earns its keep when a value's absence needs to flow through a pipeline of `.map()`/`.flatMap()`/`.filter()` calls without repeated null checks, or when a function's return type needs to make "no value" explicit and force callers to handle it. Wrapping a value with `Option.of(x)` and unwrapping it with `.getOrElse(() => fallback)` two lines later — with nothing happening to the `Option` in between — does not use any of that: it is exactly equivalent to `x ?? fallback` on the underlying nullable value, just with more ceremony and an unnecessary allocation. This pattern typically appears when a team adopts fpdart broadly and applies `Option` reflexively even to code paths that never actually branch on presence/absence, or as leftover scaffolding from a refactor that removed the branching logic but left the `Option` wrapper behind.

---

## Detection / Behavior

Flag an `Option.of(...)`/`Option(...)`/`Some(...)` construction whose result is, within the same expression or the same local variable's next use with no other read, immediately unwrapped via `.getOrElse(...)`, `.toNullable()`, `.fold(...)` with both branches returning the same shape, or a `switch`/pattern match on `Some`/`None` where the `None` branch is unreachable because the input is provably non-null and no absence check occurs elsewhere.

### Should flag (bad code)

```dart
int resolveCount(int? rawCount) {
  final option = Option.fromNullable(rawCount);
  return option.getOrElse(() => 0); // LINT — round-trip through Option adds nothing over `rawCount ?? 0`
}
```

### Should pass (good code)

```dart
int resolveCount(int? rawCount) {
  return rawCount ?? 0; // OK — direct nullable-coalescing, no Option needed
}

Option<int> parseAndValidate(String input) {
  return Option.fromNullable(int.tryParse(input))
      .filter((n) => n > 0) // OK — Option is genuinely used for its combinator chain
      .map((n) => n * 2);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific (fpdart) rule that only applies to projects using `Option` — an opt-in tier alongside other fpdart-family rules keeps it out of the way for the majority of projects that do not depend on fpdart.

---

## Edge Cases

1. **`Option.of(x).getOrElse(() => fallback)` where `x` and `fallback` have different types requiring the `Option` for type unification** — should pass; if the round-trip is doing real type-level work (not just presence checking), it is not the no-op pattern this rule targets. In practice this is rare since `getOrElse`'s fallback must match `T` anyway, but worth a defensive check.
2. **The `Option` value is stored in a variable and read more than once before being unwrapped** — should pass; multiple reads (e.g. one `.isSome()` check and one `.getOrElse()`) indicate the `Option`'s presence-tracking is actually being used, not just round-tripped.
3. **`.getOrElse()` callback has a side effect** (e.g. `.getOrElse(() { log('missing'); return 0; })`) — should pass; the `None` branch does real work beyond producing a bare fallback value, so collapsing to `??` would lose that behavior.
4. **Chained through an intermediate `.map()` that is itself an identity transform** (e.g. `Option.of(x).map((v) => v).getOrElse(() => fallback)`) — should still flag; an identity `.map()` in the middle does not change the fact that the whole chain is equivalent to `x ?? fallback`.
5. **`Option` returned from a function signature (not immediately unwrapped in the same scope)** — should pass entirely; this rule only targets *local* round-trips within one function/expression, not `Option`-typed API boundaries, since the caller side may have a legitimate reason to receive an `Option`.

---

## Alternatives Considered

- **Detect via a general "identity round-trip through any wrapper type" heuristic** (also catching similar `Either`/`Result` patterns) — rejected for the initial version; scoping tightly to `Option` keeps the detection logic simple and matches `many_lints`' own scope (a separate proposal would be needed for an `Either`-specific equivalent, and none has been requested).
- **Suggest an auto-fix that rewrites the round-trip to `??`** — worth pursuing once the rule lands; the rewrite is mechanical for the simple `Option.fromNullable(x).getOrElse(() => y)` → `x ?? y` case, though the `.toNullable()` and pattern-match variants need slightly different rewrite templates and should be scoped as follow-up work rather than blocking the initial detection-only rule.

---

## Decision

---

## Implementation Notes

Package-specific (fpdart) rule — same candidate home as `avoid_throw_in_fp_callback` (see `bugs/proposal_avoid_throw_in_fp_callback.md`): a new `lib/src/rules/packages/fpdart_rules.dart` file, gated on the fpdart package actually being a project dependency, following the established package-detection pattern used elsewhere in `lib/src/rules/packages/`. If both fpdart proposals are implemented, land them in the same file to share the fpdart-type-resolution helpers rather than duplicating them. Suggest Comprehensive or Pedantic tier per the batch instructions.

---

## Commits
