# PROPOSAL: Avoid FutureOr Return Type

**Status: Implemented**

Created: 2026-09-02

**Closes gap:** `flutter_skill_lints` `avoid_futureor_return_type` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags functions that declare `FutureOr<T>` as their return type, which forces callers into runtime type-checking (`is Future`) branches.

## Existing Coverage

Saropa already has `prefer_unwrapping_future_or` (`code_quality_prefer_rules.dart`) which flags `FutureOr` usage requiring manual type checking. This proposal may be closeable by extending that rule's scope to cover return-type declarations specifically, or by confirming it already does.

## Detection / Behavior

```dart
// Bad
FutureOr<int> getValue() => 42;

// Good
Future<int> getValue() async => 42;
int getValueSync() => 42;
```

## Quick Fix

Split into two overloads or pick one concrete return type (sync or async).

## Alternatives Considered

- Closing as HAVE if `prefer_unwrapping_future_or` already covers this pattern — verify before implementing.

## Finish Report (2026-09-04)

### Issues

- **Duplicate diagnostics with `prefer_unwrapping_future_or`.** `code_quality_prefer_rules.dart` (lines ~1574-1587) already reports on the exact same node — a top-level `FunctionDeclaration` whose `returnType` is a bare `FutureOr` `NamedType` — when the body is a `BlockFunctionBody` with no `await`. For that overlapping subset (the common case: a sync function body with an explicit `FutureOr<T>` return type), a caller now gets TWO diagnostics on the same line: `prefer_unwrapping_future_or` (INFO) and `avoid_futureor_return_type` (WARNING). The "Existing Coverage" section of this proposal explicitly flagged this and said "verify before implementing" — that verification was not done; the new rule was added without narrowing or retiring the overlapping branch in `code_quality_prefer_rules.dart`. Neither rule's tests exercise the combination, so the double-firing is unverified but reproducible from reading both implementations side by side.
- **Override exemption is annotation-based, not resolution-based.** `avoid_futureor_return_type_rules.dart` lines 102-105 skip reporting only when `@override` metadata is literally present on the declaration. Dart does not require `@override` to correctly implement an interface method (only the separate `annotate_overrides` lint recommends it) — a class that `implements` an interface declaring `FutureOr<T> compute()` without adding `@override` will have its override incorrectly flagged as if it were an independent declaration the author could change unilaterally. This contradicts the rule's own stated design intent (dartdoc lines 88-91: "the author cannot change alone"). Not covered by any test — the one override test (`compute()` in `_Impl`) always includes `@override`.

### Concerns

- **Pure lexeme matching, no type resolution** (line 100: `returnType.name.lexeme != 'FutureOr'`). A project-local class literally named `FutureOr` in an unrelated library would also be flagged. This is an accepted trade-off for a `RuleCost.trivial` rule (consistent with the project's "exact-name check only" doctrine per the code comment), but it is a real false-positive class that isn't mentioned in the dartdoc's BAD/GOOD examples or in the proposal.
- **Stale test-file header.** `test/rules/core/avoid_futureor_return_type_test.dart` lines 3-8 state the rule "is not yet wired into the global tier registry." That is no longer true: it is registered in `lib/saropa_lints.dart:2923`, `lib/src/tiers.dart:783` (inside `essentialRules`), `lib/src/scan/rule_category_map.dart:299`, and exported from `lib/src/rules/all_rules.dart:208`. The comment should be corrected or removed so future readers don't waste time re-verifying wiring that already exists.
- **`@override`-name string check is a project-wide idiom, not a local defect** — the same `a.name.name == 'override'` pattern is duplicated across 14 rule files (grep-verified), so this is a systemic limitation shared by the whole codebase, not something to fix in isolation here.

### Test Coverage Gaps

- No test for `FutureOr<int>?` (nullable FutureOr return type) — the lexeme check should still match since nullability is a separate AST field, but this is unverified.
- No test for a getter override exemption (only a method override, `compute()`, is tested; getters/setters share the same `_reportIfFutureOr` call path but the getter-specific branch is untested).
- No test for extension methods, mixin methods, or operators — all route through `addMethodDeclaration` but none are exercised.
- No test demonstrating (or guarding against) the double-diagnostic overlap with `prefer_unwrapping_future_or` described above.
- No test for the interface-implementation-without-`@override` false positive described above.
- No false-positive test for a locally-declared class literally named `FutureOr` (documents the accepted trade-off rather than leaving it implicit).

### Opportunities

- Retire or narrow the inline FutureOr-return-type branch in `code_quality_prefer_rules.dart` (the `context.addFunctionDeclaration` block, roughly lines 1574-1587) now that `avoid_futureor_return_type` covers return-type declarations unconditionally and more precisely (including methods/getters, which the old branch does not reach — it only checks top-level `FunctionDeclaration`). This would eliminate the duplicate-diagnostic risk rather than requiring users to tolerate two overlapping warnings.
- No new shared utility is warranted for the `@override` check — it is already a repeated one-line idiom across 14 files; introducing a helper here alone would not reduce total duplication meaningfully without a broader sweep.

### Recommendations

1. **(High)** Decide the relationship with `prefer_unwrapping_future_or`: either narrow/remove its FutureOr-return-type branch in favor of this rule, or explicitly document in both rules' dartdoc why both are expected to fire together on the same line.
2. **(High)** Document the `@override`-annotation-dependent override exemption as a known limitation in the dartdoc (it only suppresses when the annotation is physically present), since fixing it properly would require type resolution and a cost-tier change.
3. **(Medium)** Correct the stale "not yet wired into the global tier registry" comment in the test file header — the rule is fully registered.
4. **(Low)** Add the missing tests listed above (nullable FutureOr, getter override, extension/mixin/operator methods) to close coverage gaps before the next tier-1 batch review.
