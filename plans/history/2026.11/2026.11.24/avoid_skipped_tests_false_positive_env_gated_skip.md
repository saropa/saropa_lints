# avoid_skipped_tests: false positive on opt-in (environment-gated) skip
nStatus: Fixed

## Summary
`avoid_skipped_tests` flags any `skip:` argument whose value is not the literal `false`
(`lib/src/rules/testing/test_rules.dart`, `AvoidSkippedTestsRule`). A skip driven by a
compile-time environment flag is an intentional opt-in gate, not a silently disabled test.

## Reproducer
```dart
const enabled = bool.fromEnvironment('SCREENSHOTS');

void main() {
  // Golden screenshots are review artifacts; they run only with
  // --dart-define=SCREENSHOTS=true. Without the flag they are skipped by design.
  testWidgets('renders the board to a golden screenshot', (t) async {}, skip: !enabled); // LINT (false positive)
}
```

## Expected
No diagnostic when the skip expression is not a constant-true / string-reason literal and
depends on `bool.fromEnvironment` / `String.fromEnvironment` / `Platform.environment`
(flag evaluates to false when the opt-in is supplied, so the test runs).

## Actual
Diagnostic at the `skip:` argument (reported with `reporter.atNode(arg)`), for every call site.

## Attribution Evidence
`AvoidSkippedTestsRule.runWithReporter`: `isExplicitlyFalse = value is BooleanLiteral && value.value == false`;
anything else is reported, including a non-literal conditional expression.

## Suggested fix
Treat a skip expression that references a `const bool.fromEnvironment(...)` (or an identifier
resolving to one) as acceptable, or only flag `true` literals / string-literal reasons.

## Downstream
d:\src\jupiter-tablet `test/screens/screenshots_test.dart` suppresses once, in the `shotTest`
wrapper, instead of at 12 call sites.

## Finish Report (2026-11-24)

`avoid_skipped_tests` reported every `skip:` argument that was not the literal `false`, including opt-in gates driven by `bool.fromEnvironment`. The rule now exempts skip expressions that reference an environment source.

- `AvoidSkippedTestsRule` (`lib/src/rules/testing/test_rules.dart`) calls `_dependsOnEnvironment`, which detects `fromEnvironment`, `hasEnvironment` and `Platform.environment`, and follows identifiers by name within the same file to their variable initializers (cycle-guarded).
- `skip: true` and string-reason skips are still reported.
- Fixture `example/lib/test/avoid_skipped_tests_fixture.dart` gained a const-gated and an inline-gated GOOD case.
- Known limits: name-based lookup (no scoping; a same-named unrelated variable can cause a false negative); flag constants declared in other files are not followed; the file is re-traversed per distinct identifier.
- Verified: `dart test test/rules/testing/test_rules_test.dart` passes (69 tests). The rule itself has not been run against the fixture with the scan CLI.
