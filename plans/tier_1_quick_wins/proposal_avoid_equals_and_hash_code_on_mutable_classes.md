# PROPOSAL: Avoid Equals And Hash Code On Mutable Classes

**Status: Implemented**

Created: 2026-09-02

## Summary

Flags a class that overrides both `operator ==` and `hashCode` while also declaring one or more non-final instance fields.

## Existing Coverage

`AvoidMutableFieldInEquatableRule` (`avoid_mutable_field_in_equatable`, `lib/src/rules/packages/equatable_rules.dart`) covers the same defect but only for classes that extend `Equatable` or mix in `EquatableMixin`. This proposal is a genuine extension: it targets any class with a hand-written `operator ==`/`hashCode` pair, regardless of whether it uses the `equatable` package, which is the more common case in plain Dart/Flutter code.

## Motivation

`==` and `hashCode` are contractually required to stay in sync with the object's observable state for the lifetime the object spends in a hash-based collection (`HashSet`, `HashMap`, as a `Map` key, in a `Set`). If a field used by either method is mutable, changing it after insertion silently corrupts the collection: lookups fail, duplicates appear, and `remove()` stops working. These bugs are intermittent, hard to reproduce, and rarely caught by unit tests that don't mutate-then-query.

## Detection / Behavior

Triggers when a class declares both `operator ==` and `hashCode` (or `get hashCode`) and has at least one non-final, non-static instance field referenced by either method (or, conservatively, any non-final field on the class).

```dart
// BAD
class Point {
  Point(this.x, this.y);
  int x; // mutable
  int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

// GOOD
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
```

## Quick Fix

None — manual refactor required. Making fields `final` may require constructor changes or introducing a `copyWith` method, which is a design decision the tool should not make automatically.

## Alternatives Considered

A narrower version that only fires when the mutable field is provably read inside `==`/`hashCode` (via data-flow) would reduce false positives on classes with unrelated mutable fields, but requires flow analysis this package doesn't currently do elsewhere for this class of rule. Starting with "any non-final field on a class with `==`/`hashCode`" is consistent with the existing Equatable-specific rule's conservative approach.

## Decision

Implemented. Same correctness-bug class as the already-shipped `avoid_mutable_field_in_equatable`, just for the (more common) non-Equatable case — no reason to treat it differently.

## Implementation Notes

- **Rule class:** `AvoidEqualsAndHashCodeOnMutableClassesRule`
- **Rule name string:** `avoid_equals_and_hash_code_on_mutable_classes`
- **Files:**
  - `lib/src/rules/core/avoid_equals_and_hash_code_on_mutable_classes_rules.dart` — rule implementation (was already on disk when this pass started; found complete and unmodified).
  - `example/lib/core/avoid_equals_and_hash_code_on_mutable_classes_fixture.dart` — fixture. Was on disk but **truncated**: the trailing "GOOD near-miss: Equatable already covers this case elsewhere" section header had no class body under it. Added `EquatablePoint` (extends a locally-declared `Equatable` stand-in, with mutable fields AND hand-written `==`/`hashCode`) to actually exercise the Equatable-skip branch — a class that both matches the Equatable check AND would otherwise trigger this rule's structural pattern, proving the skip is real and not just "the rule never looked at this class."
  - `test/rules/core/avoid_equals_and_hash_code_on_mutable_classes_test.dart` — new unit test (the missing piece this pass was tasked with), 6 cases via `resolved_rule_harness`: fires on mutable field pair, fires once per mutable field (line-precise), silent on all-final (GOOD), silent with mutable field but no `==`/`hashCode` (near-miss), silent on the Equatable-covered near-miss, silent when only `==` (no `hashCode`) is overridden.
- **Recommended tier:** `essential`. This proposal has no "Proposed Tier" section of its own to defer to, so the tier was chosen by parity with `avoid_mutable_field_in_equatable` (`lib/src/tiers.dart` line 391), which is in `essentialRules` — same defect class (silent hash-collection corruption from a mutating equality key), same `impact: LintImpact.error` / `ruleType: RuleType.bug`. Not this agent's call to register it — per task instructions, `lib/src/tiers.dart` / `lib/saropa_lints.dart` / `all_rules.dart` / `CHANGELOG.md` were left untouched for the centralized wiring pass.
- **False-positive risks:**
  - The rule is intentionally conservative (matches the sibling Equatable rule's design): it flags *any* non-final instance field on a class that overrides both `==` and `hashCode`, not just fields actually read inside those two methods. A class with an unrelated mutable cache/counter field alongside a `==`/`hashCode` pair keyed only on immutable fields will still be flagged. This is documented in the proposal's own "Alternatives Considered" section as an accepted tradeoff, not a defect.
  - Equatable-based classes are correctly skipped via a structural `extends`/`with` clause name check (`Equatable` / `EquatableMixin`) — verified in the added fixture/test that this skip fires even when the class independently satisfies this rule's own trigger pattern.
  - No false positive found during verification; scan output for the fixture matched line-for-line with the `expect_lint` markers (lines 14, 16, 31) and showed zero hits on the two GOOD sections.

## Finish Report (2026-09-04)

### Issues

- **Stale/incorrect comment in the test file.** `test/rules/core/avoid_equals_and_hash_code_on_mutable_classes_test.dart` lines 2-8 claim "The rule is not yet wired into the global tier registry (a separate process handles the three-way registration centrally...)". This is false as of this review: the rule IS registered in all three required places — `lib/saropa_lints.dart:2922` (`AvoidEqualsAndHashCodeOnMutableClassesRule.new`), `lib/src/tiers.dart:312` (`essentialRules` set), and `lib/src/rules/all_rules.dart:207` (export). CHANGELOG.md:101 also already documents it as part of the 19-rule quick-win batch. The comment should be removed or corrected so future readers don't think registration is still pending.
- **No test/fixture for inherited mutable fields.** `_findMutableFields` (rule file, lines 177-188) only walks `node.bodyMembers` of the class that declares `==`/`hashCode`. A subclass that declares `==`/`hashCode` referencing a mutable field inherited from a plain (non-Equatable) superclass is a false negative — not caught, not tested, not documented as a known limitation. Given the sibling `avoid_mutable_field_in_equatable` rule's scope, this is likely an accepted conservative boundary, but it isn't called out anywhere (proposal's "False-positive risks" section only discusses false positives, not this false negative).

### Concerns

- **Equatable detection is name-only, not type-resolved.** `_extendsOrMixesInEquatable` (lines 135-150) matches on `superclass.name.lexeme == 'Equatable'` / `mixin.name.lexeme == 'EquatableMixin'` — a textual/structural check, not a resolved-type check against `package:equatable`. Any project-local class or mixin that happens to be named `Equatable`/`EquatableMixin` for unrelated reasons will silently skip this rule (false negative). The fixture at `example/lib/core/avoid_equals_and_hash_code_on_mutable_classes_fixture.dart` lines 77-79 deliberately declares such a stand-in to test the skip path, which is good, but it also documents the exact scenario that would misfire in a real (if unlikely) codebase collision. Consider a comment in the rule acknowledging this tradeoff explicitly (currently only implied by the DartDoc, not stated as a known limitation).
- **Only direct `extends`/`with` is checked, not transitive inheritance.** A class extending an intermediate class that itself extends `Equatable` (`class A extends Equatable {} class B extends A { ... }`) is not recognized as Equatable-covered by `_extendsOrMixesInEquatable`, so `B` could get double-flagged by both this rule and (if `B` also has mutable fields) potentially miss the Equatable-specific rule's own inheritance handling — worth confirming the sibling rule has the same limitation for consistency, but not verified here.
- **Abstract `==`/`hashCode` declarations (no body) still count as "hand-written".** `_findEqualsOperator`/`_findHashCodeGetter` (lines 153-174) match on operator/getter name alone, not on whether the member has a `FunctionBody` beyond an empty/abstract declaration (`bool operator ==(Object other);`). An abstract class merely declaring these signatures without implementing them, plus a mutable field, would still fire — arguably correct (contract still applies to concrete subclasses) but not tested either way.
- **Conservative "any mutable field" trigger is a known, documented tradeoff** (proposal's "Alternatives Considered" and "False-positive risks" sections) — consistent with the sibling Equatable rule, not a defect, but will produce noise on classes with unrelated mutable cache/counter fields alongside a `==`/`hashCode` pair keyed only on immutable fields. No `// ignore:`-friendly narrowing exists for this case beyond suppressing the whole field.

### Opportunities

- **Test coverage gaps that are cheap to close:**
  - No test for the inverse of the "only ==" case: a class overriding only `hashCode` without `==` (asymmetric — currently only "only ==, no hashCode" at test file lines 141-158 is covered).
  - No test for `late final` fields (should be silent — `isFinal` returns true for `late final`, but this is never exercised).
  - No test for multiple mixins where `EquatableMixin` is not first (`with Foo, EquatableMixin`) — the loop at lines 143-146 handles it correctly, but there's no regression test pinning that.
  - No test replicating the fixture's `MutableUser` case (one final + one mutable field, mixed) at the unit-test level — only exercised via the fixture, not via `resolved_rule_harness`.
  - No test for `implements Equatable` (as opposed to `extends`/`with`) — an unusual but legal way to satisfy an interface; currently would NOT be skipped (false negative, since `_extendsOrMixesInEquatable` never checks `implementsClause`). Minor, but worth a one-line test or an explicit "not handled" note.
- **Message length/format:** the `LintCode` message (rule file lines 83-91) is well over 200 chars, starts with `[avoid_equals_and_hash_code_on_mutable_classes]`, and has a `correctionMessage` — meets all documented message requirements. No changes needed here.
- **Code quality is solid:** every private helper is under 15 lines, each has a doc comment explaining intent (not just what), `SaropaLintRule` base class is used correctly with `impact`/`cost`/`ruleType`/`tags` all set, and `requiredPatterns` is used as a legitimate cheap pre-filter. No simplification opportunities found beyond the test/documentation gaps above.

### Recommendations

1. **(High)** Fix the stale test-file header comment (lines 2-8) claiming the rule isn't registered — it is, in all three places plus CHANGELOG. Leaving it will mislead the next person who touches this file.
2. **(Medium)** Add a one-line acknowledgment (DartDoc or inline comment) that `_extendsOrMixesInEquatable` is a structural/name-based check, not a resolved-type check, so a project-local `Equatable`-named class/mixin unrelated to `package:equatable` will be skipped — matches existing fixture behavior, just needs to be stated as an explicit known limitation rather than left implicit.
3. **(Low)** Add the handful of cheap regression tests listed under Opportunities (late final field, hashCode-only without ==, multi-mixin ordering, mixed final/mutable fields, `implements Equatable`) to close the coverage gaps without requiring any rule changes.
4. **(Low)** Consider whether inherited mutable fields (from a non-Equatable superclass) should be in scope for a future iteration; if not, add one sentence to the proposal's "False-positive risks" section (which currently only lists false positives) noting this as an accepted false-negative boundary, for symmetry with how the Equatable-skip tradeoff is documented.

## Commits
