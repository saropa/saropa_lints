# PROPOSAL: Flag Unreliable `is Future` Runtime Type Checks

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `is_future` to flag an `is Future` / `is Future<T>` type-check used to branch behavior on whether a value is asynchronous, instead of using the value's static (already-known) type or `async`/`await`. Runtime `is Future` checks are fragile because `Future<T>` erasure and `FutureOr<T>` make the check unreliable across generic boundaries.

**Closes gap:** `essential_lints` `is_future` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Branching on `value is Future` to decide whether to `await` something is a common workaround for poorly-typed APIs (often `dynamic` or `FutureOr<T>` parameters), but it's brittle: a `Future` subclass, a synchronous `FutureOr<T>` value, or a `dynamic` value that happens not to satisfy `is Future` all produce surprising behavior. The static type system already expresses "this may or may not be a Future" via `FutureOr<T>`, and the correct handling is `await Future.value(x)` or a proper `FutureOr<T>` signature — not a runtime type test.

---

## Detection / Behavior

Flag an `IsExpression` whose type annotation resolves to `Future` or `Future<T>` (excluding checks that are themselves inside generated/mock code).

### Should flag (bad code)

```dart
void handle(dynamic result) {
  if (result is Future) { // LINT — fragile runtime check; prefer FutureOr<T> typing + await
    result.then((value) => print(value));
  } else {
    print(result);
  }
}
```

### Should pass (good code)

```dart
Future<void> handle(FutureOr<Object?> result) async {
  final value = await result; // OK — FutureOr<T> + await handles both cases uniformly
  print(value);
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Catches a genuinely fragile async pattern with a clear, low-effort alternative (`FutureOr<T>` + `await`); broadly applicable enough for Recommended, not niche enough for Comprehensive.

---

## Edge Cases

1. **`is! Future` negated check** — should flag identically; the underlying fragility is the same regardless of negation.
2. **Check against a `Future<T>` return value coming from a third-party API the author doesn't control** — should still flag; correctionMessage should suggest wrapping with `Future.value()`/`await` rather than assuming control of the source type.
3. **Type-check used purely for logging/diagnostics, not control flow** — needs discussion; may still be worth flagging since `is Future` is unreliable even for diagnostics, but could be lower-severity.
4. **Generated code (`.g.dart`, `.mocks.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only flag when followed by `.then(...)` in the same branch** — rejected; narrows detection unnecessarily and misses the equally-fragile negative-branch pattern.

---

## Decision

---

## Implementation Notes

---

## Commits

## Finish Report (2026-09-04)

### Issues

- **Tier mismatch: rule shipped in `essentialRules`, not `recommendedOnlyRules`.** The proposal (line 54) and the CHANGELOG entry (`CHANGELOG.md` line 101: "`is_future` catches runtime `x is Future` type checks (Recommended)") both say Recommended tier. But `lib/src/tiers.dart` line 778 lists `'is_future'` inside the `essentialRules` set (block opened at line 311, closed at line 784) — it is grouped under the "Tier 1 quick wins — batch 4" comment inside `essentialRules`, not under `recommendedOnlyRules` (which starts at line 788, right after). This means the rule fires in the Essential tier today, contradicting the documented tier and inflating Essential's diagnostic surface with a stylistic/code-smell rule that the proposal explicitly scoped as "not niche enough for Comprehensive... [but not] Essential" reasoning. Needs a one-line move from `essentialRules` to `recommendedOnlyRules`.

### Concerns

- **False negative: Dart 3 pattern matching is not covered.** The visitor only registers `context.addIsExpression`, so `switch (result) { case Future(): ... }` / `if (result case Future _)` (object patterns / type patterns) — which express the exact same fragile runtime check the rule targets — are structurally different AST nodes (`ObjectPattern`/pattern-matching guards, not `IsExpression`) and will not be flagged. Not necessarily in scope for v1, but the DartDoc and proposal don't mention this as a known gap, so a user hitting it via pattern-matching may reasonably expect the rule to catch it.
- **Comment at lines 94-96 overstates equivalence with `async_rules.dart`'s `_staticTypeIsFuture`.** `_staticTypeIsFuture` (async_rules.dart line 5365) deliberately walks `allSupertypes` to catch custom `Future` *subclasses/implementers* used as a value's static type. `is_future_rules.dart` line 97 checks only `testedType.isDartAsyncFuture` on the type *literally written* in the `is` clause (`node.type.type`) — it will not fire on `x is MyCustomFuture` even though that is exactly the kind of "Future subclass" fragility called out in the rule's own DartDoc ("a Future subclass ... can produce surprising results"). This is very likely the *correct* scope (matching a user-written custom-Future check isn't obviously fragile in the same way), but the comment's claim that it follows "the identical `_staticTypeIsFuture` helper pattern" is misleading — the semantics differ (annotation type vs. value's resolved static type, and no supertype walk here). Worth rewording so a future maintainer doesn't assume subtype coverage exists.
- **`RuleCost.high` + `usesTypeResolution: true` on every `IsExpression` node.** The `requiredPatterns: {'Future'}` prefilter limits this to files that mention "Future" at all (comments/strings included, since it's presumably a substring scan), which is a coarse gate — a file with an unrelated `Future` mention anywhere pays for the visitor registration even if no `is` expression exists. This matches the pattern generally used elsewhere in the codebase, so not a defect, but it's the only mitigation; there's no early-return AST filter (e.g., skipping `IsExpression` nodes whose type name text isn't `"Future"`) before the resolved-type check, which is a cheap syntactic win still available (`node.type.name2.lexeme == 'Future'` or similar) ahead of touching `.type.type`.

### Opportunities

- **Fixture/test gap: nullable `Future<T>?` check.** Neither the fixture nor the test suite exercises `result is Future<int>?` / `result is Future?`. `isDartAsyncFuture` is documented elsewhere in this codebase (see `return_rules.dart` line 598-604 comment, and the historical `avoid_returning_null_for_future` nullable-Future bug in `plans/history/2026.06/2026.06.10/`) as true for both `Future<T>` and `Future<T>?` — this is a known footgun class in this repo specifically, so a regression test confirming `is_future` still fires (or intentionally doesn't) on the nullable variant would close a gap that has bitten this codebase before.
- **Fixture/test gap: custom `Future` subclass / implementer.** Given the "Concerns" note above about scope vs. `_staticTypeIsFuture`, a test asserting `x is SomeFutureSubclass` does NOT fire would document the intended scope boundary explicitly, rather than leaving it implicit.
- **No test exercises the `requiredPatterns` prefilter itself** (e.g., a file containing "Future" only inside a string literal or comment, with no actual `IsExpression`) — low risk since it's a pure performance gate, but the other prefiltered rules in this codebase (per `saropa_lint_rule.dart` docs) sometimes get separate coverage for the gate's correctness; consider only if the team's convention requires it elsewhere.
- **ROADMAP.md has no `is_future` entry.** `CLAUDE.md`'s "Adding a New Lint Rule" step 3 requires a ROADMAP.md entry; a search found none. Low priority since the CHANGELOG entry documents the rule, but the project's own checklist calls for both.

### Recommendations

1. **(High)** Move `'is_future'` from `essentialRules` to `recommendedOnlyRules` in `lib/src/tiers.dart` — one-line fix, resolves the Issues-section tier mismatch against both the proposal and the CHANGELOG.
2. **(Medium)** Add two fixture/test cases: `result is Future<int>?` (nullable Future — known footgun class in this repo) and `result is SomeCustomFutureSubclass` (documents that subclass checks are intentionally out of scope).
3. **(Low)** Reword the code comment at `lib/src/rules/core/is_future_rules.dart` lines 94-96 to stop claiming identity with `_staticTypeIsFuture`'s supertype-walking behavior, since the two helpers check different things (annotation type vs. resolved value type) and diverge on custom Future subclasses.
4. **(Low)** Add a one-line ROADMAP.md entry for `is_future` per the project's own rule-authoring checklist.
5. **(Optional)** Note the Dart 3 pattern-matching gap (`case Future():`) in the rule's DartDoc as a known limitation, or file a follow-up if catching it is judged worthwhile.
