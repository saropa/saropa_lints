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

## Commits
