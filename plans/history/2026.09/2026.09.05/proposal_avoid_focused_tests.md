# PROPOSAL: Flag Focused Tests (`solo: true`) Left in Committed Code

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_focused_tests` to flag `test(...)` and `group(...)` calls (from `package:test` / `package:flutter_test`) that pass `solo: true` — a debugging aid that restricts the test run to only the focused test(s)/group(s). Left in committed code, it silently skips every other test in the suite, including in CI, giving a false "all green" signal.

**Closes gap:** many_lints `avoid_focused_tests`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`solo: true` is a legitimate local debugging tool — run just the test you're iterating on — but it is trivially easy to forget to remove before committing. Once merged, CI reports success while silently running a fraction of the suite, which is far more dangerous than an obviously failing test because nobody notices.

---

## Detection / Behavior

Flag any `MethodInvocation` of `test(...)` or `group(...)` where a named argument `solo` is passed with the literal value `true`.

### Should flag (bad code)

```dart
test('computes total', () {
  expect(calculateTotal([1, 2, 3]), 6);
}, solo: true); // LINT — focused test skips the rest of the suite in CI
```

### Should pass (good code)

```dart
test('computes total', () {
  expect(calculateTotal([1, 2, 3]), 6); // OK — no solo flag
});
```

---

## Proposed Tier

Tier: Essential
Justification: A focused test silently disables the rest of the suite in CI — a correctness/safety-net regression on par with a skipped test, warranting default-on placement.

---

## Edge Cases

1. **`solo: false`** — should pass; explicitly disabled.
2. **`solo` set via a non-literal expression (e.g. a variable)** — needs discussion; flag only the literal-`true` case for a reliable, false-positive-free first version, and treat runtime-computed values as out of scope.
3. **Test files under a `debug_only/` or similarly named local-only directory not committed to CI** — needs discussion; default to flagging everywhere, since the whole risk is a forgotten local debug aid making it into a committed/pushed file.
4. **`@Skip('reason')` annotation** — out of scope; that is a distinct, deliberate skip mechanism with its own visibility (a reason string), not the focus-hides-everything-else footgun this rule targets.

---

## Alternatives Considered

- **Also flag `@TestOn` platform restrictions** — rejected; `@TestOn` is a legitimate, visible, permanent restriction (not a forgotten debug leftover) and out of scope.

---

## Decision

---

## Implementation Notes

- Rule class: `AvoidFocusedTestsRule` in `lib/src/rules/testing/test_rules.dart`
- Tier: Essential (WARNING severity)
- Detection: flags `test()`/`group()` calls with `solo: true` named argument
- Scoped to test files only (`FileType.test`)
- No fixture created — rule is simple enough for instantiation test only
- No quick fix — removal of `solo: true` is trivial manual edit

---

## Commits
