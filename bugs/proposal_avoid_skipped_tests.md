# PROPOSAL: Flag Skipped Tests (`skip: true` / Skip Reason)

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_skipped_tests` to flag `test()`, `testWidgets()`, or `group()` calls with a `skip:` argument set to `true` or a non-null skip-reason string. A skipped test provides zero regression signal while looking, at a glance, like a passing suite — it silently rots until someone notices the skip and either fixes or deletes it, which in practice can take months or never happens.

**Closes gap:** many_lints `avoid_skipped_tests` (github.com/Nikoro/many_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "10. Test hygiene" theme: "`avoid_skipped_tests` (`skip:`/`@Skip`), `avoid_focused_tests` (`solo: true`), `require_mirror_test` ... — many_lints."

---

## Motivation

`skip: true` (or a skip-reason string, which the `test` package's API also accepts as a truthy skip signal) is meant as a temporary escape hatch — "this test is flaky/broken, come back to it." In practice it is rarely revisited: CI stays green, the test suite's pass count looks healthy, and the skip becomes permanent tech debt that hides a real gap in coverage. saropa_lints already has test-quality coverage in `lib/src/rules/testing/test_rules.dart` (empty `group()` bodies, snake_case test names, real-device-only test detection) but no existing check for skipped tests — a grep for `skip:`/`Skip` in that file returns no matches. Surfacing every skip as a lint gives the skip visible, permanent pressure instead of letting it disappear into a green CI run.

---

## Detection / Behavior

### Should flag (bad code)

```dart
void main() {
  test('calculates tax correctly', () {
    expect(calculateTax(100), 8.5);
  }, skip: true); // LINT — skipped test provides no regression signal

  test('handles empty cart', () {
    expect(calculateTotal([]), 0);
  }, skip: 'flaky on CI, see JIRA-1234'); // LINT — skip reason still means the test never runs
}
```

### Should pass (good code)

```dart
void main() {
  test('calculates tax correctly', () {
    expect(calculateTax(100), 8.5); // OK — test runs and provides signal
  });

  test('handles empty cart', () {
    expect(calculateTotal([]), 0); // OK — no skip argument
  });
}
```

---

## Proposed Tier

Tier: Recommended
Justification: A skipped test is an active, ongoing coverage gap that a team should see on every analysis run, not just during a deep pedantic pass — closer in severity to other "silently rotting" issues saropa already treats as default-visible, but not Essential since a handful of legitimately time-boxed skips (e.g. platform-gated tests) are a normal, low-risk occurrence that shouldn't block a baseline-strict project.

---

## Edge Cases

1. **`skip:` argument that is a compile-time-`false` literal or omitted entirely** — should pass; the test runs normally.
2. **`skip:` driven by a `const bool.fromEnvironment(...)` or a platform check (e.g. `skip: !Platform.isIOS`)** — should still flag; the rule targets the presence of a `skip:` argument that can evaluate to a truthy skip, not just static-`true` literals, since a conditionally-skipped test is equally invisible to whoever isn't on the excluded platform when they read the CI summary. Flag any non-`false`-literal `skip:` expression, and document that platform-gated skips are an expected, acceptable source of intentional lint noise (suppressible via `// ignore:` with a one-line reason per project convention).
3. **`group()`-level `skip:` that skips every nested `test()`** — should flag at the `group()` call site; skipping an entire group is a larger coverage gap than skipping one test and deserves at least equal visibility.
4. **`@Skip('reason')` file-level annotation** (skips the whole test file) — should flag; same rot risk as an individual test skip, arguably worse since it's easy to miss a whole-file skip when scanning individual `test()` calls. Requires visiting the file's `Annotation` list, not just call expressions.
5. **Non-test files** — should pass trivially; the rule only inspects `*_test.dart` files (or files containing `test`/`testWidgets`/`group` calls from `package:test`/`package:flutter_test`), consistent with how the existing `test_rules.dart` file scopes its checks (see line ~504: "Only warn if file contains test() or testWidgets() calls").

---

## Alternatives Considered

- **Only flag `skip: true` literal, not string skip-reasons** — rejected; a skip-reason string is functionally identical to `skip: true` for the test runner (the test still never executes), and excluding strings would let the overwhelming majority of real-world skips (which nearly always carry a reason for audit purposes) slip through unflagged, defeating the rule's purpose.
- **Track skip duration/age and only flag after N days** — appealing for reducing noise on genuinely fresh, intentional skips, but rejected as out of scope: saropa_lints' static-analysis model has no persistent state across runs to track "how long has this been skipped," and would require new infrastructure disproportionate to this rule's scope. A flat "flag every skip" is simpler and matches many_lints' own behavior.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/testing/test_rules.dart`, alongside the existing empty-`group()` and test-naming rules — reuse the file's existing method-invocation-name matching (`test`, `testWidgets`, `group`) and its "only scan files with test/testWidgets calls" file-scoping guard (~line 504). Detection: for each matched `MethodInvocation`, inspect the `argumentList` for a named `skip:` argument whose value is not the boolean literal `false`; for the whole-file case, additionally visit `CompilationUnit.directives`/`declarations` for an `@Skip(...)` annotation.

---

## Commits
