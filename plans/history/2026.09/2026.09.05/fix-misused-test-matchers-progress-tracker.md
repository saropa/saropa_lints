# Fix: misused test matchers across the test suite

Five `expect()` calls across four test files used `expect(x.length, N)` with a
raw integer literal as the matcher argument instead of `hasLength()`. The
`avoid_misused_test_matchers` rule flagged all of them.

## Finish Report (2026-09-05)

**Files changed:**

- `test/report/progress_tracker_max_issues_test.dart` — lines 52, 70
- `test/rules/flow/duplicate_value_test.dart` — line 121
- `test/rules/core/avoid_equals_and_hash_code_on_mutable_classes_extended_test.dart` — line 69
- `test/rules/stylistic/new_instance_cascade_test.dart` — line 226

**Change:** Replaced all `expect(x.length, N)` → `expect(x, hasLength(N))`.

**Rationale:** `hasLength` provides descriptive failure output
(`Expected: an object with length of <3>, Actual: [...]`) versus the opaque
`Expected: <3>, Actual: <5>` from a raw literal.

**Scope check:** Grepped the full `test/` tree for `expect(*.length, \d+)` — zero
remaining violations after the fix. Also verified no `expect(x, true/false/null)`
literal-matcher violations exist (all existing uses pass the literal as a function
argument, not as the matcher).

**`reportData.violationsFound` not changed:** `expect(reportData.violationsFound, 5)`
uses a plain `int` property, not `.length`. The lint rule targets `.length` with
raw literals specifically. Leaving the raw integer is correct here.

**Verification:** All affected tests pass (46 tests across 4 files, all green).
