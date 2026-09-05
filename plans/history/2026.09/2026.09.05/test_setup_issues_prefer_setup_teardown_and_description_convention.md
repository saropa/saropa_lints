# Test-suite hygiene: prefer_setup_teardown and require_test_description_convention

Twenty-six lint diagnostics in `bugs/test_setup_issues.json` (a raw Problems-panel
export, not a tracked markdown bug report) flagged duplicated per-test setup code
(`prefer_setup_teardown`, 6 occurrences) and vague test descriptions
(`require_test_description_convention`, 20 occurrences) across 13 test files. The
description-convention findings turned out to trace back to a single defect in the
rule itself rather than 20 independent wording problems.

## What changed

**Test files (13):** Extracted duplicated per-test setup into `setUp()`/`setUpAll()`
or local helper functions:
- `test/cli/cross_file_test.dart` — shared fixture analysis result via `setUp()`.
- `test/init/write_rule_packs_custom_file_test.dart` — `writeTemplateWithPacks()` helper.
- `test/integrity/handle_throwing_invocations_metadata_crash_test.dart` —
  `_createConsumerProject()` helper factoring out the temp-project/pubspec/analysis_options
  boilerplate shared by all three regression cases.
- `test/native/plugin_logger_test.dart` — `_withTempProjectDir()` helper, applied to
  every test that previously hand-rolled create-dir/write-pubspec/try-finally-delete.
- `test/scan/fixture_lint_integration_test.dart` — `setUpAll()` caching a single
  `ExampleAnalysis` record (`fromAnalyze`/`fromCustom`/`combined`) so `dart analyze`
  and `dart run custom_lint` each run once for the whole group instead of once per test.

Vague test names (`'RequireSdkUpperBoundRule'`, `'fixture exists'`, `'plain dot call'`,
etc.) were reworded to state the expected behavior across
`test/config/pubspec_constraint_parser_test.dart`,
`test/integrity/{api_network_fixture_expect_lint_contract_test,fixture_integrity_test,
plan_c_fixture_expect_lint_contract_test,positioned_outside_stack_fixture_contract_test}.dart`,
`test/report/memory_eviction_test.dart`,
`test/scan/{rule_quick_fix_presence_test,rule_tier_index_test}.dart`,
`test/utils/{comment_utils_test,target_matcher_utils_test}.dart`.

**Rule fix (`lib/src/rules/testing/testing_best_practices_rules.dart`,
`RequireTestDescriptionConventionRule`):** The rule read
`firstArg.stringValue?.toLowerCase() ?? ''` to judge a test description's wording.
`StringLiteral.stringValue` is unconditionally `null` for any `StringInterpolation`
(a non-constant expression), so every parameterized/data-driven test description —
e.g. `test('${c.rule} should exist ...', ...)`, a common idiom in this codebase's
fixture-contract tests — was judged against an empty string and therefore always
flagged, regardless of what words it actually contained. Rewording those descriptions
to include a "good" indicator word (`should`, `returns`, etc.) had no effect, because
the check never read the literal text at all.

Added `_literalText(StringLiteral)`, which concatenates only the literal
(non-interpolated) segments of a `SimpleStringLiteral`, `StringInterpolation`, or
`AdjacentStrings`, and switched the rule to use it instead of `.stringValue`. This
makes the rule judge interpolated descriptions by their actual literal wording,
closing the false-positive class instead of requiring every data-driven test to avoid
interpolation in its description.

## Verification

- `dart run saropa_lints scan . --tier comprehensive --files <15 touched test files>
  --format json`: before the rule fix, 5 `require_test_description_convention` and 1
  `prefer_setup_teardown` diagnostic remained (all in files whose descriptions already
  contained a "should"-class word); after the rule fix, 0 remained.
- `dart test test/rules/testing/testing_best_practices_rules_test.dart`: 70/70 passed
  (rule-instantiation and fixture-existence tests; this file has no dedicated
  behavioral coverage for the fixed rule — see Not Yet Verified below).
- `dart analyze` on the touched files hit an unrelated Dart AOT runtime crash
  ("Could not start thread DartWorker") in this environment; not attempted again
  after the initial crash, per project guidance against foreground analyzer runs.

## Not yet verified

- No dedicated regression test was added for `_literalText`/`RequireTestDescriptionConventionRule`.
  `RequireTestDescriptionConventionRule.applicableFileTypes` is `{FileType.test}`,
  which is determined by path (`isTestPath`), so the usual `example/lib/*_fixture.dart`
  fixture pattern cannot exercise this rule — a fixture placed there is silently never
  scanned by it. A real regression test would need to live under `test/` and be
  resolved through whatever harness (if any) can instantiate `SaropaContext` against
  synthetic source classified as a test file; that harness was not identified in the
  time available. The rule fix is currently verified only by before/after scan output
  on real repository test files.
- `test/scan/fixture_lint_integration_test.dart` (tagged `slow`) was not executed —
  it runs a full `dart analyze` + `dart run custom_lint` pass over the `example/`
  package, which takes minutes; the refactor was verified by reading, not running.
- This session ran concurrently with several other sessions performing the identical
  task against the same working tree (a multi-agent farm scenario). Files were
  observed changing on disk mid-session (e.g. another session had already reworded
  several of the same test descriptions, and added `setUpAll` caching to
  `fixture_lint_integration_test.dart`). The final state of each file reflects
  whichever session's edit landed last, converged upon and extended here; some wording
  differs from what this session originally wrote, per instructions to treat externally
  changed files as current state rather than reverting them.

## Explicitly out of scope

Running the same scan at `--tier comprehensive` surfaced 139 additional pre-existing
diagnostics across these same 15 files (`no_magic_string_in_tests`,
`no_optional_operators_in_tests`, `no_magic_number_in_tests`,
`prefer_descriptive_test_name`) that were never part of the original 26-item request
and were not touched.

## Deferred

A `CHANGELOG.md` entry for the `require_test_description_convention` fix was drafted
locally but not committed: `extension/package.json` currently carries an uncommitted
version bump (`16.1.915`, vs. the last published tag `v16.0.0-beta.3`) made by a
different concurrent session, which trips this repo's `changelog_guard.py`
pre-commit hook whenever `CHANGELOG.md` is staged. Per project rules, version numbers
in `pubspec.yaml`/`package.json` are never hand-edited by an agent, so that drift was
left for whichever session owns it to resolve; the changelog entry should be
committed once it is.
