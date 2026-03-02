# Require Test Ordering

**GitHub:** [https://github.com/saropa/saropa_lints/issues/41](https://github.com/saropa/saropa_lints/issues/41)

**Opened:** 2026-01-23T14:01:54Z

---

## Detail

### Problem  
Integration tests may depend on database state from previous tests. Test dependencies should be documented or setUp should be used to ensure required state.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing test dependencies and setup logic.
- **Test diversity:** Different frameworks and patterns for test setup.
- **False positives:** Some tests may intentionally depend on previous state.

### Desired Outcome  
- Detect integration tests with undocumented dependencies.
- Warn about potential test pollution.
- Suggest documenting dependencies or using setUp for state management.

### References  
- See ROADMAP.md section: "require_test_ordering"

---

## Roadmap task spec (merged from bugs/roadmap/task_require_test_ordering.md)

# Task: `require_test_ordering`

## Summary
- **Rule Name**: `require_test_ordering`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.4 Testing Rules (Integration Testing)

## Problem Statement

Integration tests often depend on database state, shared preferences, or in-memory state left by previous tests. When test order is undefined or tests assume a specific order, CI can be flaky and failures are hard to debug. This rule should flag integration test groups (e.g. `integration_test` package or `test_driver`-based tests) that either (1) have no documented ordering guarantees or (2) do not reset state in `setUp`/`setUpAll`, so implementers add documentation or proper `setUp` to achieve known initial state.

## Description (from ROADMAP)

> Integration tests may depend on database state from previous tests. Document dependencies or use `setUp` to ensure required state.

## Code Examples

### Bad (should trigger)

```dart
// integration_test/app_test.dart
import 'package:integration_test/integration_test_driver.dart' as integration;

void main() {
  integration.integrationDriver();
}

// No setUp; tests assume DB is already populated by a previous test.
// test_driver runs tests in file order but state is shared.
group('User flow', () {
  test('user can checkout', () async {
    // Assumes "add product to cart" was run earlier in same run.
    await tap(find.byKey(Key('checkout')));
    expect(find.text('Order complete'), findsOneWidget);
  });
});
```

```dart
// Relies on test order: "login" must run before "profile".
testWidgets('profile shows user name', (tester) async {
  await tester.pumpWidget(MyApp());
  // No login step; assumes global auth state from previous test.
  expect(find.text('Hello, Jane'), findsOneWidget);
});
```

### Good (should not trigger)

```dart
group('User flow', () {
  setUp(() async {
    await resetTestDatabase();
    await clearSharedPreferences();
    await seedUserAndCart();
  });

  test('user can checkout', () async {
    await tap(find.byKey(Key('checkout')));
    expect(find.text('Order complete'), findsOneWidget);
  });
});
```

```dart
// Documented: "Requires login_test to run first" in group description or README.
// Or use test order API if available and document it.
```

## Detection: True Positives

- **Scope**: Restrict to integration-test code (e.g. under `integration_test/`, or files that use `integration_test` / `flutter_driver` / `patrol`). Exclude unit tests (`test/` only with no integration driver).
- **Signals**: (1) Presence of shared state access (DB, SharedPreferences, global singletons) in test body without corresponding `setUp`/`setUpAll` that resets or seeds that state. (2) Test group with no `setUp` and multiple tests that touch the same backend. (3) Comments or names implying order (e.g. "test_02_after_login") without documented ordering.
- **AST**: Look for `setUp`, `setUpAll`, `group`, and test invocations; consider `MethodDeclaration` and `FunctionDeclaration` for test bodies. Use type/element checks for integration-test entry points rather than path substring (e.g. `integration_test` package usage).
- **True positive**: Integration test file with at least one test that reads from DB/prefs/global state and no `setUp` that resets or documents ordering.

## False Positives

- **Unit tests**: Pure unit tests (no DB, no shared state) should not be flagged even if they have no `setUp`.
- **Single-test files**: One test with no shared state — no ordering concern.
- **Already reset**: Group has `setUp` that clears DB/prefs or seeds known state — do not flag.
- **Documented order**: Explicit comment or doc that states "Tests run in order X; see README" — consider not flagging if heuristic can detect documentation.
- **Risk**: Flagging unit tests or well-isolated integration tests leads to noise; prefer high precision (only flag when shared state + no reset is detectable).

## External References

- [Flutter integration_test](https://docs.flutter.dev/testing/integration-tests) — official integration test docs.
- [integration_test package](https://pub.dev/packages/integration_test) — API and test lifecycle.
- [Test isolation best practices](https://docs.flutter.dev/testing#test-isolation) — avoid shared state.
- [Dart custom_lint](https://pub.dev/packages/custom_lint) — plugin API.
- [Project: string_contains false positive audit](../../history/false_positives/string_contains_false_positive_audit.md) — avoid substring matching on names.

## Quality & Performance

- **Scope**: Use `ProjectContext.isTestFile(path)` and package detection (e.g. `usesPackage('integration_test')`) to run only in integration-test code; skip unit-only projects.
- **Cost**: Avoid full AST traversal; use `addMethodDeclaration` / `addFunctionDeclaration` in test files and inspect for `setUp`/`setUpAll` and state access. Cache "has integration_test" per analysis run.
- **Heuristic limits**: Inferring "reads shared state" requires recognizing DB/prefs/global API calls; may have false negatives if state is accessed via abstractions. Prefer INFO severity.
- **Test requirement**: Add fixture with integration_test-style group without setUp + DB access (true positive) and unit test without setUp (false positive).

## Notes & Issues

- Overlap: Check [CODE_INDEX.md](../../CODE_INDEX.md) for existing test-lifecycle or integration-test rules.
- Checklist: exact-match or type checks for test APIs; do not use `path.contains('integration')` alone; consider all AST shapes for setUp/setUpAll.
