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
