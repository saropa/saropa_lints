# BUG: `require_error_logging` — Flags Any `catch` Without a Captured Exception Variable Before Checking Whether the Body Logs

**Status: Fixed**

Created: 2026-08-15
Rule: `require_error_logging`
File: `lib/src/rules/flow/error_handling_rules.dart` (line ~2394)
Severity: False positive
Rule version: v2 | Since: v2.5.0 | Updated: v4.13.0

---

## Summary

The rule's shared body-logging detector (`catchBodyHasLoggingCall`) already
recognizes the project's `debug()`/`debugException()` wrappers by name — that
part works. The actual bug is upstream: when a `catch` clause has no captured
exception parameter (`on TimeoutException { ... }` with no `catch (e)`), the
rule reports immediately and returns, without ever calling
`catchBodyHasLoggingCall` to check whether the body logs something anyway.
This fires even when the body plainly logs a static, informative message via
`debug(...)` — the caught exception's value simply isn't needed in the log
text. Confirmed 2 false positives in `lib/main.dart`, both `on
TimeoutException { debug(...); }` blocks with no captured parameter.

---

## Attribution Evidence

```bash
grep -rn "'require_error_logging'" lib/src/rules/
# lib/src/rules/flow/error_handling_rules.dart:2413:    'require_error_logging',
```

**Emitter registration:** `lib/src/rules/flow/error_handling_rules.dart:2413`
**Rule class:** `RequireErrorLoggingRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Verified directly against `lib/main.dart:236-249` and `lib/main.dart:546-559`
(`_initFirebaseAppCheck`), both `on TimeoutException` blocks with no captured
exception variable and a body that logs via the project's `debug()` wrapper:

```dart
Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
  } on TimeoutException {
    // LINT — but should NOT lint: the body clearly logs, via the project's
    // debug() wrapper (which require_error_logging's own shared helper,
    // catchBodyHasLoggingCall, recognizes by name). The static message
    // doesn't need the TimeoutException's value, so no `catch (e)` was
    // written — but the rule reports before it ever inspects the body,
    // solely because exceptionParameter is null.
    debug(
      'Firebase initialization timed out - continuing without it',
      level: DebugLevels.Warning,
    );
  } on Object catch (error, stack) {
    // Contrast: this sibling clause, one line below, is NOT flagged — it
    // captures (error, stack) and logs them, so it reaches the
    // catchBodyHasLoggingCall check and passes.
    debug(() => 'Firebase initialization failed: $error', stackTrace: stack);
  }
}
```

**Frequency:** Always — any `catch`/`on Type` clause with no captured
exception parameter is reported unconditionally, regardless of body content.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the body forwards a message to the project's recognized logging call (`debug(...)`), satisfying the rule's own stated purpose ("caught errors should be logged"), even without a captured exception variable |
| **Actual** | `[require_error_logging] Caught error is not logged to any logging framework or crash reporting service.` reported at the `CatchClause` node, identical to the message for a genuinely silent `catch (e) {}` |

---

## AST Context

```
TryStatement
  └─ CatchClause (on TimeoutException)             ← context.addCatchClause
      ├─ exceptionType: NamedType (TimeoutException)
      ├─ exceptionParameter: null                  ← node.exceptionParameter == null
      │                                                -> reporter.atNode(node); return;  (line ~2436)
      │                                                catchBodyHasLoggingCall(body) is NEVER CALLED
      └─ body: Block
          └─ ExpressionStatement (debug('Firebase initialization timed out...', level: ...))
                                                     ← IS recognized by catchBodyHasLoggingCall
                                                        ('debug' is in catchBodyLoggingMethodNames),
                                                        but the early return above means this
                                                        recognition is never reached
```

---

## Root Cause

`RequireErrorLoggingRule.runWithReporter`
(`lib/src/rules/flow/error_handling_rules.dart:2421-2445`):

```dart
context.addCatchClause((CatchClause node) {
  final Block body = node.body;

  // Skip empty catch blocks - handled by AvoidSwallowingExceptionsRule
  if (body.statements.isEmpty) return;

  // Check if the exception variable exists and is used in logging
  final CatchClauseParameter? exceptionParam = node.exceptionParameter;
  if (exceptionParam == null) {
    // No exception variable captured - can't log it
    reporter.atNode(node);
    return;
  }

  // Check if any logging method is called in the catch body
  if (!catchBodyHasLoggingCall(body)) {
    reporter.atNode(node);
  }
});
```

The comment `// No exception variable captured - can't log it` is the bug
premise, and it's false: logging the *fact* that an exception of a known,
statically-named type occurred (`on TimeoutException { debug('...timed
out...'); }`) is a complete, useful log entry without ever touching the
exception object itself — Dart doesn't require capturing `e` to log
something meaningful about the catch. The early `return` on line ~2437 means
`catchBodyHasLoggingCall(body)` — the shared helper in
`lib/src/catch_body_logging_utils.dart` that already recognizes `debug`,
`debugException`, `print`, `debugPrint`, `rethrow`, `throw`, and a dozen
crash-reporting method/receiver names — is structurally unreachable for any
catch clause without a captured parameter, no matter what the body contains.

---

## Suggested Fix

Reorder the checks so `catchBodyHasLoggingCall(body)` always runs, and only
apply the "no captured variable" reasoning as an additional signal when the
body ALSO fails the logging check:

```dart
final bool bodyLogs = catchBodyHasLoggingCall(body);
if (!bodyLogs) {
  reporter.atNode(node);
}
```

This collapses to one check: report only when the body neither captures nor
logs. A catch clause with no captured exception parameter but a body that
calls a recognized logging function is exactly as compliant as one that
captures and logs — the parameter capture was never actually required by the
rule's stated goal ("caught errors should be logged for debugging").

---

## Fixture Gap

The fixture at
`example*/lib/flow/require_error_logging_fixture.dart` should include:

1. `on TimeoutException { debug('message', level: DebugLevels.Warning); }`
   (no captured parameter, body logs a static message) — expect NO lint
2. `on TimeoutException {}` (no captured parameter, empty body) — expect NO
   lint via the existing `body.statements.isEmpty` early return (unchanged)
3. `on TimeoutException { doSomethingUnrelated(); }` (no captured parameter,
   body does NOT log) — expect LINT (must keep working)
4. `on Object catch (e, s) { debugException(e, s); }` — expect NO lint
   (current behavior, must keep working)

---

## Changes Made

`lib/src/rules/flow/error_handling_rules.dart` (`RequireErrorLoggingRule.runWithReporter`, ~line 2438): removed the early `if (exceptionParam == null) { reporter.atNode(node); return; }` branch. The rule now calls `catchBodyHasLoggingCall(body)` unconditionally and reports only when the body neither captures nor logs, exactly as suggested in this report.

---

## Tests Added

Added three cases to `example/lib/error_handling/require_error_logging_fixture.dart`:
1. `on TimeoutException { debug('...'); }` (no captured parameter, body logs) — no `expect_lint` marker, must NOT fire
2. `on TimeoutException { doSomethingUnrelated(); }` (no captured parameter, body does not log) — `expect_lint: require_error_logging`, must still fire
3. Existing `catch (e, s) { debugException(...) }`-style captured-and-logged cases in the fixture are unaffected

Verified `dart test test/rules/flow/error_handling_rules_test.dart` passes (50/50) confirming the edited file compiles. Full end-to-end fixture-firing verification via the scan CLI was blocked by a pre-existing, unrelated compile error in `lib/src/rules/architecture/lifecycle_rules.dart` (uncommitted work in progress on `require_app_lifecycle_handling`, not touched by this fix) — manual review confirms `catchBodyHasLoggingCall` takes only `Block body` and has no dependency on `exceptionParam`, so the reordering is safe.

---

## Commits

- `0c9b4248` — code fix (landed as part of the `require_error_boundary` commit, which independently reused the same `catchBodyHasLoggingCall` reordering pattern for this rule; diff content is identical to the fix proposed above)
- `a0c7a6c1` — CHANGELOG `[Unreleased]` entry (landed as part of an unrelated `no_magic_string` commit due to a shared working tree)
- Fixture additions and this report: pending in the archival commit for this bug

---

## Finish Report (2026-08-15)

`RequireErrorLoggingRule` reported every `catch`/`on Type` clause lacking a captured exception parameter, without ever inspecting whether the clause body logged the error through another means — an early-return bypassed the shared `catchBodyHasLoggingCall` check entirely for that case, producing false positives on clauses like `on TimeoutException { debug('timed out'); }`.

The fix removes the early return in `RequireErrorLoggingRule.runWithReporter` (`lib/src/rules/flow/error_handling_rules.dart`) so `catchBodyHasLoggingCall(body)` always runs; a clause is now flagged only when its body neither captures nor logs. `example/lib/error_handling/require_error_logging_fixture.dart` gained a not-flagged case (uncaptured parameter, body logs via `debug()`) and a still-flagged case (uncaptured parameter, body does not log), with a supporting `TimeoutException`/`debug` stub. `dart test test/rules/flow/error_handling_rules_test.dart` passes (50/50), confirming the edited rule file compiles cleanly; the changed helper (`catchBodyHasLoggingCall`) takes only a `Block` and has no dependency on the exception parameter, so the reorder is behavior-preserving for all other call sites (`avoid_catching_generic_exception`, `require_error_boundary`).

End-to-end fixture-firing verification via the scan CLI (`dart run saropa_lints scan ... --resolve`) was not performed — the full package failed to build due to a pre-existing, unrelated compile error in `lib/src/rules/architecture/lifecycle_rules.dart` (uncommitted in-progress work on a separate bug, `require_app_lifecycle_handling`), which is outside this fix's scope and was left untouched.

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:236` and `lib/main.dart:546` (both `on TimeoutException`
  blocks inside `main()` / `_initFirebaseAppCheck()`), 2 occurrences
