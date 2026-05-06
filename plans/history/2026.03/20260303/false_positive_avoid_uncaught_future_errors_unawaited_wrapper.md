# False positive: `avoid_uncaught_future_errors` should never report when Future is wrapped in `unawaited()`

**Rule:** `avoid_uncaught_future_errors`  
**Rule implementation:** `lib/src/rules/flow/error_handling_rules.dart` — `AvoidUncaughtFutureErrorsRule`  
**Status:** Open  
**Date:** 2026-03-03

---

## Summary

The rule flags fire-and-forget `Future` calls that have no error handling (no `.catchError()`, try-catch, or `.ignore()`), so that async failures are not invisible in production. The rule’s documentation and `_hasErrorHandling` already treat `unawaited()` as explicit acknowledgment of fire-and-forget: when the expression is a call to `unawaited(...)`, `_hasErrorHandling` returns true and the rule does not report. This bug report asks to **guarantee** that behavior in all code paths and to **document** it clearly, so that consumers never need to disable the rule solely because they use `unawaited()`.

If in any analyzer or resolution edge case the rule still reports on `unawaited(someFuture());`, that should be fixed so that any top-level expression that is an invocation of `unawaited(...)` is never reported.

---

## What the rule is supposed to do

- Detect expression statements where the expression is a method invocation whose return type is `Future` (or `Future<T>`), and which is not awaited.
- Require that the call has some form of error handling: `.catchError()`, `.then(onError: ...)`, `.ignore()`, or wrapping in `unawaited()` (explicit acknowledgment that errors are not handled).
- Skip: dispose context, try blocks, safe fire-and-forget method names, and calls that have error handling (including `unawaited()`).

From the rule’s DartDoc: *"Futures wrapped in `unawaited()` - explicit acknowledgment"* and *"Use unawaited() from dart:async"* for intentional fire-and-forget.

---

## Current implementation

In `AvoidUncaughtFutureErrorsRule.runWithReporter`, the callback uses `addExpressionStatement`. For each statement, it checks `expression` (the expression of the statement). When the statement is:

```dart
unawaited(_checkWhatsNew());
```

`expression` is the `MethodInvocation` for `unawaited(_checkWhatsNew())`. The code then calls `_hasErrorHandling(expression)`. In `_hasErrorHandling`:

```dart
if (methodName == 'unawaited') {
  return true;
}
```

So when the **top-level** expression is `unawaited(...)`, the rule should already skip. That is correct.

---

## What can go wrong

1. **Different AST or visitor order:** If in some cases the rule visits or evaluates an **inner** Future-returning call (e.g. the argument to `unawaited`) as a separate expression, or if the “expression” seen for the statement is not the full `unawaited(...)` node, the rule might still report. This bug report asks that all code paths ensure: if the expression statement’s expression is a single `MethodInvocation` with method name `'unawaited'`, do not report.

2. **Documentation and tests:** Consumers disabling the rule “because we use unawaited()” suggests either (a) there is an edge case where the rule still fires, or (b) the rule’s behavior is not obvious and they disable it preemptively. Making the “we never report on `unawaited(...);`” guarantee explicit in the rule’s DartDoc and in tests (and in the correction message if needed) will reduce unnecessary global disables.

---

## Expected behavior

- For an expression statement whose expression is a `MethodInvocation` with method name `'unawaited'` (i.e. the statement is `unawaited(...);`), the rule must **never** report, in all analyzer and resolution scenarios.
- This should be clearly documented in the rule and covered by tests.

---

## Suggested fix

1. **Guarantee skip at statement level**  
   In `runWithReporter`, at the start of the `addExpressionStatement` callback, after obtaining the expression:
   - If the expression is a `MethodInvocation` and `expression.methodName.name == 'unawaited'`, return immediately (do not report). This makes the “top-level unawaited” case explicit and independent of type resolution or chaining.

2. **Keep `_hasErrorHandling` for chained calls**  
   When the expression is a chain like `foo().then(...)`, the rule already uses `_hasErrorHandling` and it correctly treats `unawaited` as having error handling. No change needed there except to ensure that when the **entire** statement expression is `unawaited(something())`, we never rely solely on type or chain walking; we skip by name first.

3. **Documentation**  
   In the rule’s DartDoc, state explicitly: “Expression statements that are exactly a call to `unawaited(...)` are never reported, as they explicitly acknowledge fire-and-forget.”

4. **Tests**  
   In `test/error_handling_rules_test.dart`, add or extend a test that verifies `unawaited(someFutureReturningCall());` never triggers `avoid_uncaught_future_errors`, and that the fixture in `example_async/lib/error_handling/` (or equivalent) includes this pattern with no expected lint.

---

## Reproduction

### Consumer code (representative)

Same as in the `avoid_unawaited_future` report: launch tasks, share, logging, animations wrapped in `unawaited()`.

```dart
unawaited(_checkWhatsNew());
unawaited(SharePlus.instance.share(...));
unawaited(_flush());
```

### Steps

1. Enable `avoid_uncaught_future_errors`.
2. Analyze the project.
3. **Expected:** No report on any line where the statement is `unawaited(...);`.
4. If any such line is ever reported, that is a bug and should be fixed by the explicit “skip when expression is unawaited(...)” check above.

---

## Environment

- **Rule:** `avoid_uncaught_future_errors` (AvoidUncaughtFutureErrorsRule)
- **File:** `lib/src/rules/flow/error_handling_rules.dart`
- **Tests:** `test/error_handling_rules_test.dart`
- **Fixture:** `example_async/lib/error_handling/avoid_uncaught_future_errors_fixture.dart`

---

## References

- Related bug report (resolved): `bugs/history/false_positive_avoid_unawaited_future_unawaited_wrapper.md` (sibling rule; same pattern).
- Rule DartDoc in error_handling_rules.dart (lines 667–735): documents unawaited() as acceptable.
- Consumer workaround: rule disabled in `analysis_options_custom.yaml` until behavior is guaranteed and documented.
