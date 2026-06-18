# `avoid_cascade_shuffle` — flag in-place `..shuffle()` on a shared collection

**Status: Fixed**

Created: 2026-06-16
Resolved: 2026-06-18
Rule: `avoid_cascade_shuffle` (class `AvoidCascadeShuffleRule`)
Location: `lib/src/rules/code_quality/complexity_rules.dart`
Tier: Recommended (`recommendedOnlyRules` in `lib/src/tiers.dart`)
Severity: WARNING · `ruleType: bug` · `RuleCost.low` · tag `maintainability` · message version `{v1}`

---

## Summary

`(collection..shuffle()).first` reads one element but, as a side effect,
permanently reorders the shared collection. `List.shuffle()` mutates in place
and returns `void`, so the cascade hands back the *same* list object — every
other reader of that collection now sees a scrambled order. The author almost
always wanted a random pick from a throwaway copy.

There was no rule detecting this. The report was originally filed as a false
negative against an existing `avoid_cascade_shuffle` rule, but no such rule
existed in the package. It is corrected here to record what it actually was: a
request for a new rule, now implemented.

---

## Reproducer

```dart
void checkPattern() {
  final List<String> masterPool = ['A', 'B', 'C'];

  // LINT: mutates masterPool in place; the shuffled order leaks to all readers
  final singleItem = (masterPool..shuffle()).first;

  // OK: shuffles a throwaway copy, leaving masterPool untouched
  final cleanItem = (List.of(masterPool)..shuffle()).first;
}
```

---

## Detection logic

`AvoidCascadeShuffleRule` registers `addCascadeExpression` and flags a cascade
only when all three hold, which keeps it conservative and free of copy false
positives:

1. A cascade section invokes `shuffle()`.
2. The cascade target is a reference to existing storage — `SimpleIdentifier`,
   `PrefixedIdentifier`, or `PropertyAccess`. Fresh copies (`List.of(...)`,
   `[...x]`, `x.toList()`) are left alone because the mutation dies with the
   temporary.
3. The cascade's result is consumed. A standalone `pool..shuffle();` statement
   discards the value, which means the in-place shuffle was the intent, not a
   bug.

The diagnostic points at the `shuffle()` section, not the whole chain. No quick
fix — whether to copy is a judgment the author must make.

---

## Resolution

- **Rule:** `AvoidCascadeShuffleRule` in
  `lib/src/rules/code_quality/complexity_rules.dart`, beside the existing
  cascade rule `AvoidCascadeAfterIfNullRule`.
- **Registration:** factory `AvoidCascadeShuffleRule.new` in `lib/saropa_lints.dart`.
- **Tier:** `'avoid_cascade_shuffle'` added to `recommendedOnlyRules` in `lib/src/tiers.dart`.
- **Fixture:** `example/lib/complexity/avoid_cascade_shuffle_fixture.dart`
  (bad variable case, bad field case, plus `List.of`, spread-copy, and
  discarded-statement OK cases).
- **Tests:** instantiation + fixture-existence entries in
  `test/rules/code_quality/complexity_rules_test.dart`.
- **Changelog:** entry under `[Unreleased] → Added`.

---

## Verification

Scan CLI against a temp file exercising all four cases reported exactly one
`avoid_cascade_shuffle` WARNING — on `(pool..shuffle()).first` only. The
`List.of`, spread-copy, and discarded-statement cases produced no diagnostic.

```
dart run saropa_lints scan <dir> --tier recommended --format json
```

`dart test test/rules/code_quality/complexity_rules_test.dart` (33 tests) and
`dart test test/integrity/saropa_lints_test.dart` both pass — the integrity test
confirms the new tier entry maps to a registered plugin rule.

---

## Finish Report (2026-06-18)

The report was originally filed as a regression (false negative in an existing
rule) and carried fabricated evidence: an "Attribution Evidence" grep block
claiming a match in a non-existent file, "Changes Made"/"Tests Added"/"Commits"
sections describing work never done, and a "Suggested Fix" using the wrong base
class (`DartLintRule` with the deprecated `reportErrorForNode`) for this package,
which uses `SaropaLintRule` + `runWithReporter` + `SaropaDiagnosticReporter`.

Verification before acting: grep confirmed no `avoid_cascade_shuffle` reference
anywhere in `lib/`, `test/`, or `example/`, and no `lib/src/rules/maintainability/`
directory. The anti-pattern itself was real and uncovered — existing `shuffle`
references belong to unrelated rules (setState mutation, ignored-return-value,
toList-required), none of which flags a cascade shuffle on a non-fresh
collection.

The rule was then implemented per the package's actual conventions, registered,
tiered, fixtured, tested, and documented. ROADMAP.md is now a pointer to
`plans/` and no longer carries per-rule rows, so no ROADMAP edit was needed.
