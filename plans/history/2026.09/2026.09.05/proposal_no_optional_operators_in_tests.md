# PROPOSAL: Flag Null-Aware/Bang Operators Inside Test Files

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `no_internal_method_docs`

---

## Summary

Add `no_optional_operators_in_tests` to flag use of `?.`, `??`, `??=`, and `!` inside `_test.dart` files (and any file under a configured test directory), pushing test authors toward direct, unconditional assertions instead of null-tolerant access that can silently mask a bug the test was meant to catch.

**Closes gap:** `ripplearc_linter` `no_optional_operators_in_tests` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Null-aware operators exist to let production code degrade gracefully when a value might legitimately be absent. A test asserting behavior should never *want* graceful degradation — if the value under test is unexpectedly `null`, the test should fail loudly with a clear stack trace at that line, not silently short-circuit through `?.` or fall back through `??` to a default that happens to satisfy the assertion anyway.

---

## Detection / Behavior

### Should flag (bad code)

```dart
test('returns the user name', () {
  final user = repository.findUser('1');
  expect(user?.name, 'Alice'); // LINT — `?.` in a test silently passes `null` through to the matcher
});
```

### Should pass (good code)

```dart
test('returns the user name', () {
  final user = repository.findUser('1');
  expect(user, isNotNull); // OK — explicit assertion
  expect(user!.name, 'Alice'); // OK per project convention, or restructure to avoid `!` entirely
});
```

---

## Proposed Tier

Tier: Comprehensive
Justification: intentionally opinionated about test-writing style; not every team agrees `!`/`?.` are unwelcome in tests, so it belongs in an opt-in tier rather than Recommended/Professional.

---

## Edge Cases

1. **`!` used on a value already asserted non-null on a preceding line via `expect(value, isNotNull)`** — needs discussion; arguably safe in practice but still matches the pattern textually.
2. **Test helper/fixture files that are not themselves `_test.dart` but are only ever imported by tests** — should pass by default; scope is limited to files matching the test file pattern unless configured to include helper directories.
3. **`??` used to supply a default for an optional test *input* parameter, not an assertion target** — needs discussion; may be lower-risk than `??` used directly around expected/actual values.
4. **Non-`test`/`expect` code inside a test file, e.g. a local helper function definition** — should still flag; the rule scopes to the file, not just literal `test()`/`group()` bodies, since setup code can hide the same masking risk.

---

## Alternatives Considered

- **Only flag `?.`/`??` inside `expect(...)` argument expressions, not the whole test file** — considered as a narrower, less noisy variant; deferred pending user feedback on false-positive rate from the broader file-wide version.

---

## Decision

---

## Implementation Notes

---

## Commits
