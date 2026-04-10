# False positive: `avoid_uncaught_future_errors` and `unawaited()` wrapper (RESOLVED)

**Rule:** `avoid_uncaught_future_errors`  
**File:** `lib/src/rules/flow/error_handling_rules.dart` — `AvoidUncaughtFutureErrorsRule`  
**Fixed:** 2026-03-03

## Summary

The rule was intended to never report when the expression statement is a call to `unawaited(...)`, but relied on `_hasErrorHandling(expression)` and type resolution. To guarantee behavior in all code paths, the rule now returns immediately when the statement's expression is a `MethodInvocation` with method name `unawaited`, before any type or chain checks. Expression statements that are exactly `unawaited(...);` are therefore never reported. DartDoc was updated with an explicit guarantee and a developer note; fixture and integration test (unawaited must not trigger) were added.

## References

- Original bug: `bugs/false_positive_avoid_uncaught_future_errors_unawaited_wrapper.md` (deleted after integration)
- Tests: `test/error_handling_rules_test.dart` (avoid_uncaught_future_errors group)
- Fixture: `example_async/lib/error_handling/avoid_uncaught_future_errors_fixture.dart`
