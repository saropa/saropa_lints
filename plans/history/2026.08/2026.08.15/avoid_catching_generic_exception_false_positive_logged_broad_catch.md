# BUG: `avoid_catching_generic_exception` — Fires on `on Object catch` blocks that immediately log via a crash-reporting call

**Status: Fixed**

Created: 2026-08-15
Rule: `avoid_catching_generic_exception`
File: `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart` (line ~1035)
Severity: False positive
Rule version: v4 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

The rule flags any `catch` clause whose declared exception type is `Exception`, `Object`, `dynamic`, or untyped, based solely on the type annotation — it never inspects the catch block's body. A downstream project's mandated error-handling doctrine is `on Object catch (error, stack) { debugException(error, stack); ... }` (deliberately broad, so `Error` subtypes such as assertion failures are also caught and reported before a safe fallback), which the rule cannot distinguish from a silently-swallowing broad catch. This fired ~9 times across 5 files on the exact same compliant pattern in one review pass.

---

## Attribution Evidence

```bash
grep -rn "'avoid_catching_generic_exception'" lib/src/rules/
# lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:1057:    'avoid_catching_generic_exception',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:1057`
**Rule class:** `AvoidCatchingGenericExceptionRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
void doWork() {
  try {
    riskyOperation();
  } on Object catch (error, stack) { // LINT — but should NOT lint: body forwards to logging immediately
    debugException(error, stack);
    showFallbackUi();
  }
}

// Contrast: this IS the bad pattern the rule is meant to catch — no logging at all.
void doWorkBadly() {
  try {
    riskyOperation();
  } on Object catch (error, stack) { // LINT — correct: exception is dropped
    // nothing — swallowed silently
  }
}
```

**Frequency:** Always (any `on Object` / `on Exception` / untyped catch triggers it regardless of body content).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the catch body's first (or only) meaningful statement forwards `error`/`stack` to a logging or crash-reporting call before any fallback logic |
| **Actual** | `[avoid_catching_generic_exception] Catching Exception or Object swallows all errors...` reported at the `exceptionType`/`node` regardless of body content |

---

## AST Context

```
CatchClause                                ← node registered via context.addCatchClause
  ├─ exceptionType: NamedType ('Object')    ← only this is inspected; reported here if name matches
  ├─ exceptionParameter (error)
  ├─ stackTraceParameter (stack)
  └─ body: Block                            ← NEVER visited by this rule
      ├─ ExpressionStatement (debugException(error, stack))   ← ignored
      └─ ExpressionStatement (showFallbackUi())                ← ignored
```

---

## Root Cause

`AvoidCatchingGenericExceptionRule.runWithReporter` (lines 1064–1088) registers `context.addCatchClause` and does exactly two checks:

1. `if (exceptionType == null) { reporter.atNode(node); return; }` — untyped catch always flags.
2. `if (exceptionType is NamedType)` — checks `typeName` against `'Exception' | 'Object' | 'dynamic'` and reports on the type annotation if matched.

At no point does the method read `node.body` (a `Block`). There is no visitor over the catch block's statements, so a catch that immediately forwards the caught error/stack to `debugException(...)`, `Crashlytics.recordError(...)`, `Sentry.captureException(...)`, etc. is indistinguishable from one that discards it entirely (`catch (e) {}`). The detection logic is purely type-annotation-based with zero body inspection.

---

## Suggested Fix

When `exceptionType` resolves to `Object` (the widest, deliberately-broad type used specifically to also catch `Error` subtypes), inspect `node.body.statements` for any statement that is a `MethodInvocation`/function call passing the caught `exceptionParameter` (and/or `stackTraceParameter`) as an argument — treat this as "handled" and skip the diagnostic. Simpler, configurable alternative: a project-level allowlist of logging-function names (mirroring `RequireErrorLoggingRule._loggingMethods` in `lib/src/rules/flow/error_handling_rules.dart`) checked against the body via the same `_hasLoggingCall`-style regex/AST scan. At minimum, split `Object`/`Exception` into a lower-severity message distinct from untyped `catch (e)`, since `on Object catch` is a deliberate, documented pattern in several codebases specifically to catch `Error` subtypes for crash reporting.

---

## Fixture Gap

The fixture at `example*/lib/widget/avoid_catching_generic_exception_fixture.dart` should include:

1. `on Object catch (error, stack) { debugException(error, stack); }` — expect NO lint (body logs before continuing)
2. `on Object catch (error, stack) { Crashlytics.instance.recordError(error, stack); }` — expect NO lint
3. `on Object catch (e) { }` — expect LINT (still swallowed)
4. `catch (e) { print(e); }` (untyped) — current behavior (LINT) should be revisited once body-inspection lands, since `print` is also a form of logging

---

## Changes Made

- `AvoidCatchingGenericExceptionRule.runWithReporter` (`lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart`) now checks `node.body` before reporting on `Exception`/`Object`/`dynamic` catches: if the body forwards the caught error to a logging/crash-reporting call (or rethrows), the diagnostic is skipped. Untyped `catch (e)` behavior is unchanged (still always flags, per the Fixture Gap note above — revisiting that is out of scope here).
- Extracted the logging-call detection into a shared utility, `lib/src/catch_body_logging_utils.dart` (`catchBodyHasLoggingCall`, `catchBodyLoggingMethodNames`, `catchBodyLoggerReceiverNames`), and refactored `RequireErrorLoggingRule` (`lib/src/rules/flow/error_handling_rules.dart`) to use it instead of its own private copy of the same method/receiver name lists — single source of truth for "does this catch body log the error". (A concurrent fix landed on top of this for `RequireErrorLoggingRule` and `RequireErrorBoundaryRule` reusing the same utility — see commit `0c9b4248`.)
- Added a marker `StatelessWidget` subclass to the fixture file: `AvoidCatchingGenericExceptionRule.applicableFileTypes` gates on content-based `FileType.widget` detection (`extends StatelessWidget`/`StatefulWidget`/`State<...>`), which the fixture previously lacked — without it none of the fixture's cases (old or new) were reachable by the rule at all.
- Updated the class-level DartDoc on `AvoidCatchingGenericExceptionRule` with a third example showing the logged-`on Object`-catch exemption.

---

## Tests Added

- `test/utils/catch_body_logging_utils_test.dart` (new): unit tests parsing real catch clauses via the analyzer to pin `catchBodyHasLoggingCall`'s true/false cases directly (bare log/print, named crash-report method, logger-receiver call, `rethrow`, bare `throw`, silently-swallowed catch, unrelated-call-only catch).
- `example/lib/widget_patterns/avoid_catching_generic_exception_fixture.dart`: added `_goodObjectCatchLogged` (no lint — logs then falls back), `_goodObjectCatchCrashlytics` (no lint — crash-reporting receiver), `_badObjectCatchSwallowed` (lint — still silently swallowed).

**Known limitation (not fixed here, pre-existing/systemic):** the fixture's `expect_lint:` markers are not exercised by any automated CI check for this rule — `test/rules/widget/widget_patterns_rules_test.dart` is an instantiation pin only, and `test/integrity/plan_c_fixture_expect_lint_contract_test.dart` does not include `avoid_catching_generic_exception`. The standalone `dart run saropa_lints scan` CLI also cannot verify `example/` fixtures directly — it hardcodes `/example` into its own file-exclusion list (`lib/src/scan/scan_runner.dart:661`) independent of the per-rule fixture-skip logic. Verification for this fix relied on (1) direct AST-level unit tests of the extracted `catchBodyHasLoggingCall` logic against the bug's exact repro cases, and (2) manual code review confirming the `return` added inside `AvoidCatchingGenericExceptionRule`'s matched-type branch is correctly scoped and does not affect the untyped-`catch (e)` path.

---

## Commits

_None yet._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts), 9 occurrences across 5 files

---

## Finish Report (2026-08-15)

`AvoidCatchingGenericExceptionRule` flagged every `on Object`/`on Exception`/`dynamic` catch by type annotation alone, without inspecting the catch body — so a deliberately broad catch that immediately forwarded the error to a logging or crash-reporting call, before falling back to safe UI, was indistinguishable from a silently swallowed one.

The rule's type-matched branch (`Exception`/`Object`/`dynamic`) now inspects `node.body` and skips reporting when the body forwards the caught error to a logging/crash-reporting call or rethrows it; untyped `catch (e)` is unchanged and still always flags. The detection logic (method-name and receiver-name matching, plus `rethrow`/`throw` detection) was extracted from `RequireErrorLoggingRule`'s existing private implementation into a new shared utility, `lib/src/catch_body_logging_utils.dart`, and `RequireErrorLoggingRule` was refactored to use it instead of its own copy — removing a duplicated method/receiver name list. A concurrent fix in the same session window (commit `0c9b4248`) built on this same shared utility to also exempt `RequireErrorBoundaryRule` from flagging a `MaterialApp`/`CupertinoApp` built as a logged catch clause's fallback UI.

The fixture file lacked any `extends StatelessWidget`/`StatefulWidget`/`State<...>` marker, so `AvoidCatchingGenericExceptionRule`'s `applicableFileTypes => {FileType.widget}` content-based gate made none of its cases — old or new — reachable by the rule at all; a marker class was added to fix that. The class-level DartDoc was extended with a third example showing the logged-catch exemption.

Direct verification used `test/utils/catch_body_logging_utils_test.dart` (new), parsing real catch clauses via the analyzer to pin the extracted function's true/false behavior against the bug's four exact repro shapes (logged-then-fallback, crash-reporting-receiver, silently-swallowed, unrelated-print). All 266 existing tests in `test/rules/widget/widget_patterns_rules_test.dart` and `test/rules/flow/error_handling_rules_test.dart` continued to pass; both rule-name pin tests were unaffected since neither the code name nor the message text changed. End-to-end fixture-level verification via `dart run saropa_lints scan` was not possible — that CLI hardcodes `/example` into its own file-exclusion list independent of the per-rule fixture-skip logic, a pre-existing tool limitation (not introduced or fixed here) already documented in project memory.
