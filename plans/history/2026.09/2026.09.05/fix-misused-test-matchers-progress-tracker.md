# Fix: misused test matchers + quick-fix for avoid_misused_test_matchers

Five `expect()` calls across four test files used `expect(x.length, N)` with a
raw integer literal as the matcher argument instead of `hasLength()`. The
`avoid_misused_test_matchers` rule flagged all of them. Additionally, the rule
had no quick-fix — users had to rewrite manually.

## Finish Report (2026-09-05)

### Dogfood fixes (5 violations across 4 files)

- `test/report/progress_tracker_max_issues_test.dart` — lines 52, 70
- `test/rules/flow/duplicate_value_test.dart` — line 121
- `test/rules/core/avoid_equals_and_hash_code_on_mutable_classes_extended_test.dart` — line 69
- `test/rules/stylistic/new_instance_cascade_test.dart` — line 226

Replaced all `expect(x.length, N)` → `expect(x, hasLength(N))`.

### Quick-fix implementation

New file: `lib/src/fixes/test/replace_misused_test_matcher_fix.dart`

`ReplaceMisusedTestMatcherFix` handles all three patterns the rule detects:
- `expect(x, true)` → `expect(x, isTrue)` (boolean literal → isTrue)
- `expect(x, false)` → `expect(x, isFalse)` (boolean literal → isFalse)
- `expect(x, null)` → `expect(x, isNull)` (null literal → isNull)
- `expect(x.length, N)` → `expect(x, hasLength(N))` (length + integer → hasLength)

For boolean/null patterns, only the matcher argument is replaced. For the
length pattern, the entire `expect()` invocation is rewritten because both
the actual expression and the matcher change.

Registered via `fixGenerators` on `AvoidMisusedTestMatchersRule` in
`test_rules.dart`.

### Hardening

- Grepped `test/` for `expect(*.length, \d+)` — zero remaining violations.
- Grepped `test/` for `expect(x, true/false/null)` literal matchers — all
  existing uses pass the literal as a function argument, not as the matcher.
- Grepped `example/` for similar patterns — fixture file
  `avoid_misused_test_matchers_fixture.dart` updated with proper bad/good
  examples.
- `expect(reportData.violationsFound, 5)` confirmed correct as-is: plain
  `int` property, not `.length`. The lint targets `.length` specifically.

### Verification

- 46 tests across 4 dogfood test files pass (2 + 17 + 11 + 16).
- Rule instantiation test not executed (test_rules_test.dart times out due
  to file size — pre-existing issue unrelated to this change).
