# Fix: `avoid_case_sensitive_path_comparison` URI camelCase detection

Pre-existing test failure in `avoid_case_sensitive_path_comparison_fixture_test.dart` — the "does NOT fire on import URI comparison by name" test was failing because the import-URI suppression in `_isDartImportUri` could not detect camelCase `Uri` segments after lowercasing the identifier name.

## Root cause

`_isDartImportUri` ran a regex `(?:^|[^a-z])uri(?:$|[^a-z])` against `expr.name.toLowerCase()`. Lowercasing destroyed camelCase boundaries: `namedUri` became `nameduri`, and the regex saw a lowercase `d` before `uri` — no word boundary, no match.

A secondary issue: the test fixture used `pathFirst` as a variable name, which legitimately triggers the path-variable heuristic (`_hasPathAsWord` correctly identifies "path" followed by uppercase `F` as a word boundary). The test was asserting no diagnostic, but the rule was correctly firing on a path-like variable.

## Fix

**Rule (`windows_rules.dart`):** Replaced the lowercased regex check with a new `_hasUriAsWord` function that delegates to a shared `_hasCamelCaseWord(source, wordRegex)` helper — the same generic function now backs both `_hasPathAsWord` and `_hasUriAsWord`. It operates on the original (case-preserved) identifier name, checking for camelCase word boundaries around each occurrence. Correctly handles: `namedUri` (camelCase boundary ✓), `uriString` (word start ✓), `URI` (uppercase ✓), `security` (no boundary ✗), `burial` (no boundary ✗).

**Test:** Renamed `pathFirst` → `otherUri` in the by-name test and `pathFirst` → `firstSpec` in the loop-variable test, so each test isolates one suppression mechanism without accidentally triggering the path heuristic. Added two false-positive guard tests: embedded "uri" in unrelated words (`security`, `mercurial`) must not trigger URI suppression, and a path variable compared against a `security`-like operand must still fire.

## Finish Report (2026-09-05)

- **Files changed:** `lib/src/rules/platforms/windows_rules.dart`, `test/rules/platforms/avoid_case_sensitive_path_comparison_fixture_test.dart`, `CHANGELOG.md`, this report
- **Tests:** 23/23 pass in the fixture test suite (added snake_case boundary guards)
- **Code review:** medium + low follow-up — zero findings
- **Refactoring:** Extracted `_hasCamelCaseWord` generic helper from duplicated `_hasPathAsWord`/`_hasUriAsWord` logic. Uses `startsUpper` (0x41–0x5A range check) instead of hardcoded codepoints per word.
- **Snake_case:** Verified that underscore boundaries already work (0x5F is not in 0x61–0x7A range) — added test coverage for `file_path` and `named_uri` to pin this.
- **Risk:** Low — the shared helper is a strict superset of the prior logic; all 23 test cases pass including embedded-word and snake_case guards
