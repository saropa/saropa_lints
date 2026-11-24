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

- `AvoidSkippedTestsRule` (`lib/src/rules/testing/test_rules.dart`) calls `_dependsOnEnvironment`, which detects `fromEnvironment`, `hasEnvironment`, `Platform.environment` and `io.Platform.environment`, and follows identifiers to their const initializers via resolved elements (`VariableElement.constantInitializer`, works across files; cycle-guarded). Unresolved identifiers fall back to a same-file name match built once per call.
- `skip: true`, string reasons and plain consts are still reported; `config.environment` is not treated as an env source.
- Fixture `example/lib/test/avoid_skipped_tests_fixture.dart` gained const-gated, inline-gated, `Platform.environment` GOOD cases and a plain-local BAD case.
- Known limits: non-const (`final`) variables have no `constantInitializer` and are not followed when resolved; the name fallback has no scoping.
- Verified: `dart test test/rules/testing/test_rules_test.dart` passes (69 tests); scan CLI on a scratch test file (`D:	mp\skipscan`) in both default and `--resolve` modes flags exactly `skip: true`, `skip: 'reason'` and a plain const, and exempts the five env-gated forms.
