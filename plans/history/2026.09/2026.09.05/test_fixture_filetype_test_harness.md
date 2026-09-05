# FileType.test fixture harness for require_test_description_convention

Rules with `applicableFileTypes => {FileType.test}` only fire on paths matching
`ProjectFile.isTestPath()` — files ending in `_test.dart` or containing `/test/`,
`/test_driver/`, or `/integration_test/` in the path. The existing fixture for
`require_test_description_convention` lived at
`example/lib/testing_best_practices/require_test_description_convention_fixture.dart`,
which does not match any `isTestPath` pattern, so the rule was silently never
exercised by the integration test suite.

## Changes

- **Deleted** `example/lib/testing_best_practices/require_test_description_convention_fixture.dart`
  (stub with `void main() {}` and a TODO).
- **Created** `example/lib/test/require_test_description_convention_fixture.dart`
  at a path containing `/test/` so `isTestPath` returns true. Contains 3 BAD
  cases (single-word, too-short, PascalCase descriptions) and 5 GOOD cases
  (descriptions with indicator words, interpolated descriptions with literal
  good words, and long multi-word descriptions). The interpolated GOOD cases
  are regression guards for the `_literalText()` fix from commit 531799f7.
- **Added** `'require_test_description_convention'` to `expectedFromFixtures` in
  `test/scan/fixture_lint_integration_test.dart` so the rule is asserted when
  `dart run custom_lint` runs against the example project.
- **CHANGELOG** entry added under the current unreleased section.

## Verification

- `dart run saropa_lints scan` against the fixture: 3 hits on BAD cases, 0 on
  GOOD cases (expected).
- `dart test test/rules/testing/testing_best_practices_rules_test.dart`: 69/69 passed.
- `dart test test/integrity/fixture_integrity_test.dart`: 2358/2358 passed.

## Finish Report (2026-09-05)

The root cause was a path mismatch: fixture files for `FileType.test`-gated rules
were placed in subdirectories (`testing_best_practices/`) that do not contain
`/test/` in their path, so the native `custom_lint` plugin's `applicableFileTypes`
filter skipped them silently. The fix is trivial — place such fixtures under
`example/lib/test/` where `isTestPath` matches. This pattern already works for
32 other testing-rule fixtures in that directory.

A CI script (`scripts/check_fixture_filetype_match.py`) was added to audit all
80 `FileType.test`-gated rules (34 in `testing_best_practices_rules.dart`, 28
in `test_rules.dart`, and 18 across `async_rules.dart`, `numeric_literal_rules.dart`,
`config_rules.dart`, and package-specific rule files). The script found 39
fixtures at non-matching paths, 33 at correct paths (including the one relocated
in this session), and 8 rules with no fixture at all. Moving the remaining 39
fixtures is follow-up work — the script makes the scope visible.
