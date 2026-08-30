# Fix: prefer_sorted_parameters conflicts with dart format

GitHub issue [#321](https://github.com/saropa/saropa_lints/issues/321): `prefer_sorted_parameters` demanded flat alphabetical ordering across all named parameters, which conflicted with `dart format`'s `always_put_required_named_parameters_first` convention. When a function mixed required and optional named parameters, the formatter and the lint rule produced irreconcilable orderings.

## Changes

- **`lib/src/rules/architecture/structure_rules.dart`** — `PreferSortedParametersRule.checkParameters()` now separates named parameters into required and optional groups. Required named params must come first (matching `dart format`), and each group is checked for alphabetical order independently. Added `_isUnsorted()` static helper. Bumped rule version to v7. Updated DartDoc examples, `exampleBad`/`exampleGood`, and `LintCode` message to describe group-aware sorting.
- **`example/lib/structure/prefer_sorted_parameters_fixture.dart`** — Added BAD cases for optional-before-required and unsorted-required-group. Added GOOD cases for required-first-alphabetical and single-required-before-single-optional.
- **`lib/src/fixes/structure/sort_named_parameters_fix.dart`** — New quick fix `SortNamedParametersFix` that auto-reorders named parameters into the correct required-first-alphabetical grouping. Registered on the rule via `fixGenerators`.
- **`CHANGELOG.md`** — Entry under `### Fixed` in `[15.2.5] — Unreleased` referencing #321.

## Finish Report (2026-08-30)

The `PreferSortedParametersRule` enforced a single flat alphabetical sort across all named parameters. Dart's formatter (`dart format` tall style) places required named parameters before optional named parameters, then sorts within each group. The two tools were irreconcilable when a function had both required and optional named parameters with names that span both groups' alphabetical ranges.

The fix partitions named parameters into required and optional lists during the visitor pass. A required parameter appearing after an optional parameter flags the violation immediately (grouping error). Otherwise, each group is checked for alphabetical order independently via `_isUnsorted()`. This matches `dart format`'s output exactly: `{required String alpha, required String zebra, String? gamma}` is valid even though `gamma` < `zebra` in flat sort order.

A quick fix (`SortNamedParametersFix`) was added that rebuilds the parameter list with required named params first (alphabetical) then optional named params (alphabetical), preserving positional params, annotations, default values, and type annotations via `toSource()`.

Test: `dart test test/rules/architecture/structure_rules_test.dart --name "PreferSortedParametersRule"` — passed.
