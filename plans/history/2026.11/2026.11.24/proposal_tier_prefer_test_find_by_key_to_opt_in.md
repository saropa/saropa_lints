# PROPOSAL: move `prefer_test_find_by_key` out of the default set, or narrow it

**Status: Fixed**

Created: 2026-11-24
Rule: `prefer_test_find_by_key`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (line ~3008)
Type: Tier change / rule narrowing

---

## Summary

The rule reports every `find.byType(...)` call in a test file (`runWithReporter` matches `methodName == 'byType'` with target `find`, lines ~3030-3040). It has no condition on whether the type is ambiguous. In the contacts app this produces 2,979 findings across `test/`, the largest single rule in the project (more than half of all non-`prefer_static_method` findings).

## Why this is a problem

- `find.byType(SomeWidget)` is the idiomatic Flutter test finder when exactly one instance exists, and it is robust to key churn. Replacing it needs a `Key` added to every widget under test in `lib/`, so the fix changes production code in about 2,979 places for no behavior change.
- A mass key-addition crosses into app code and shared widgets, which is far outside what a test-style hint should demand.

## Proposed change (either)

1. Report only when the finder is likely ambiguous: the same `byType` argument is used with `findsNWidgets`, `.first`, `.at(n)` or `.last` in the same test.
2. Or move the rule to an opt-in tier (not in `recommended`), keeping the diagnostic for projects that want key-based testing.

## Downstream impact

contacts app: 2,979 findings in `test/`, none fixable without adding keys to production widgets. This project records them as not fixed in its plan (`docs/PLAN_LINT_BURNDOWN.md`) until the rule changes.

## Finish Report (2026-11-24)

### Outcome

Option 2 (opt-in) implemented. Option 1 (narrow detection) not done.

### Changes

- `lib/src/tiers.dart`: `prefer_test_find_by_key` moved from `recommendedOnlyRules` to `stylisticRules`.
- Removed from the `testingRules` pack, because `test/integrity/saropa_lints_test.dart` forbids pack rules in the stylistic track. Maintainer decision: keep the rule out of the pack.
- Regenerated `extension/src/rulePacks/ruleTierDefinitions.ts` and `extension/src/rulePacks/rulePackDefinitions.ts` with `dart run tool/generate_rule_pack_registry.dart`. The regeneration also picked up the missing `prefer_generated_data_classes: professional` entry and a sort-order change.
- `example/analysis_options_template.yaml` (~line 1047) annotated as stylistic opt-in.
- Added to `lib/src/init/stylistic_rulesets.dart` next to `prefer_test_data_builder`.

### Verification

`saropa_lints_test` 24 passed / 0 failed, `testing_best_practices_rules_test` 69 passed / 0 failed, `_tier_integrity.py` all checks pass.

### Unverified

`init` and `--stylistic-all` behavior. Bulk-enable now turns this rule on.
