# Rule Instantiation test coverage backfill

The project's health-metrics script (`scripts/modules/_rule_metrics.py`) flags a rule category test file as missing "Rule Instantiation" coverage whenever the literal string `Rule Instantiation` does not appear anywhere in the file backing that category. 11 rule categories had a behavioral test file (via the resolved-rule harness) but no group asserting the rule's own metadata contract (`code.lowerCaseName`, `code.problemMessage` prefix/length, `code.correctionMessage` non-null).

## Change

Added a `group('<rule_name> - Rule Instantiation', ...)` block to 9 test files, each instantiating the rule class and asserting:
- `rule.code.lowerCaseName` equals the rule's code name
- `rule.code.problemMessage` contains `[<code_name>]`
- `rule.code.problemMessage.length` is `greaterThan(50)`
- `rule.code.correctionMessage` is not null

Files:
- `test/rules/code_quality/getters_in_member_list_test.dart`
- `test/rules/code_quality/initializers_ordering_test.dart`
- `test/rules/code_quality/mutable_tearoff_test.dart`
- `test/rules/core/avoid_equals_and_hash_code_on_mutable_classes_extended_test.dart`
- `test/rules/core/avoid_futureor_return_type_test.dart`
- `test/rules/core/is_future_test.dart`
- `test/rules/data/no_direct_iterable_access_test.dart`
- `test/rules/stylistic/new_instance_cascade_test.dart`
- `test/rules/widget/avoid_mounted_check_in_finally_test.dart`

Two additional files already contained an equivalent metadata-assertion group under a differently-worded group name (`'$_rule metadata'` and `'NeverDiscardBuildContextRule — instantiation'`), so the marker string was satisfied by adding a one-line comment rather than a duplicate group:
- `test/rules/data/use_compare_without_case_test.dart`
- `test/rules/widget/never_discard_build_context_test.dart`

## Verification

All 11 modified files pass under `dart test`. Re-ran the category-resolution logic from `_rule_metrics.py` (stem matching `{category}_rules_test` / `{category}_test`, marker-string presence check) against the current tree — all 11 previously-flagged categories now resolve to a test file containing the marker.

No rule source or fixture files changed; this is coverage-only.

## Finish Report (2026-09-04)

Follow-up hardening after the initial backfill:

1. **Shared assertion helper.** Extracted `test/support/rule_instantiation_assertions.dart` (`assertRuleMetadata(rule, expectedCode)`) and refactored the 9 newly-added groups to call it instead of repeating the 4-assertion block. Net effect: 10 files changed, 50 insertions / 55 deletions.
2. **Documented the convention.** Added a "Rule Instantiation coverage" section and a checklist item to `.claude/skills/lint-rules/SKILL.md` explaining that `_rule_metrics.py`'s check is a literal substring match, not a Dart-side lint — the convention was previously undocumented. This file is gitignored (`.claude/`), so the addition is local to this machine only.
3. **CI-blocking integrity test.** The metrics script's finding was previously a soft dashboard warning only — nothing blocked a PR from merging a category test file missing the marker. Added `test/integrity/rule_instantiation_coverage_test.dart`, which ports the Python script's category-discovery, test-file-resolution (including the split-category alias table), and marker-check logic to Dart and fails with a ready-to-paste snippet when a category's existing test file lacks the group. Categories with no resolved test file at all are skipped (a separate, pre-existing "unit test coverage" gap tracked elsewhere, not this test's concern). Verified directly against `_compute_rule_instantiation_stats` on the live tree: 174/174 categories covered, 0 missing.
4. **CHANGELOG update skipped.** The repo's top CHANGELOG section (`[16.0.0-beta.1]`) currently carries no `— Unreleased` suffix, so no active unreleased section exists to append to; the file (along with `CHANGELOG_ARCHIVE.md` and `extension/src/i18n/locale_coverage.json`) also carries pre-existing uncommitted changes unrelated to this task, from outside this session. Rather than create a new section against that ambiguous state, the update was skipped — this work is non-user-facing test/tooling infrastructure with no CHANGELOG-worthy behavior change regardless.

Verification: `dart test test/integrity/rule_instantiation_coverage_test.dart` passes; the 9 refactored rule-category test files plus the two already-conforming ones (211 tests total across the batch) pass under `dart test`.
