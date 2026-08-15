# BUG: `require_error_boundary` — Flags a `MaterialApp` That IS the Last-Resort Fallback UI, Built Inside the Catch Clause That Caught the Fatal Startup Error

**Status: Fixed**

Created: 2026-08-15
Rule: `require_error_boundary`
File: `lib/src/rules/flow/error_handling_rules.dart` (line ~705)
Severity: False positive
Rule version: v2 | Since: v1.7.2 | Updated: v4.13.0

---

## Summary

The rule demands a `builder:` argument (wrapping the child tree in an error
boundary) on every top-level `MaterialApp`/`CupertinoApp` construction. It
never checks whether the flagged constructor call is itself lexically inside
a `catch` clause of the app's own startup try/catch — i.e., IS the recovery
UI shown after a fatal initialization error was already caught and logged.
Demanding this `MaterialApp` also carry an error-boundary `builder:` is
recursive: it asks the fallback screen to be wrapped in another fallback
mechanism for errors that can only occur after the one real failure path
already terminated. Confirmed false positive in `lib/main.dart`, where the
flagged `MaterialApp` is constructed inside `main()`'s outer `on Object catch
(error, stack) { ... }` block, immediately after `debugException(error,
stack, ...)` has already logged the root cause.

---

## Attribution Evidence

```bash
grep -rn "'require_error_boundary'" lib/src/rules/
# lib/src/rules/flow/error_handling_rules.dart:724:    'require_error_boundary',
```

**Emitter registration:** `lib/src/rules/flow/error_handling_rules.dart:724`
**Rule class:** `RequireErrorBoundaryRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Verified against `lib/main.dart:255-278` (`main()`'s outer catch):

```dart
Future<void> main() async {
  try {
    // ... all pre-runApp initialization ...
    runApp(const MainInitializerScreen(initFactory: _initializeCoreServices));
  } on Object catch (error, stack) {
    // Fatal startup failure already logged here — this catch clause is the
    // app's own top-level error boundary for initialization failures.
    debugException(error, stack, doSaveToDb: false);

    // CRITICAL: Always show something to the user, even if initialization
    // fails. This prevents the app from appearing to hang on a blank screen.
    FlutterNativeSplash.remove();
    runApp(
      // LINT — but should NOT lint: this MaterialApp IS the last-resort
      // fallback UI, constructed ONLY after a fatal error was already
      // caught and reported one statement above. Demanding a `builder:`
      // error boundary here asks the fallback screen to be wrapped in a
      // boundary for errors that, by construction, can only happen after
      // the one real failure already terminated startup.
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('Something went wrong. Please restart the app.'),
          ),
        ),
      ),
    );
  }
}
```

**Frequency:** Always — any `MaterialApp`/`CupertinoApp` construction with no
`builder:` argument is flagged, with no exception for the node being
lexically inside a `CatchClause`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — this `MaterialApp` is the deliberate crash-recovery screen, not the app's normal entry point, and wrapping it in another error boundary adds no protection (the errors it could throw are a strict subset of "rendering a `Text` widget," already caught by Flutter's own framework-level error widget) |
| **Actual** | `[require_error_boundary] Top-level MaterialApp or CupertinoApp is missing an error boundary in its build tree...` reported at the constructor name, identical to the message for the app's real, primary `MaterialApp` |

---

## AST Context

```
FunctionDeclaration (main)
  └─ body: BlockFunctionBody
      └─ TryStatement
          ├─ body: Block
          │   └─ ExpressionStatement (runApp(const MainInitializerScreen(...)))
          │                                    ← the REAL entry point; MainInitializerScreen
          │                                       presumably builds the real MaterialApp elsewhere
          └─ catchClauses: [CatchClause (on Object catch (error, stack))]
              └─ body: Block
                  ├─ ExpressionStatement (debugException(error, stack, ...))
                  ├─ ExpressionStatement (FlutterNativeSplash.remove())
                  └─ ExpressionStatement (runApp(...))
                      └─ InstanceCreationExpression (MaterialApp)   ← context.addInstanceCreationExpression;
                                                                        flagged here; node.thisOrAncestorOfType
                                                                        <CatchClause>() would resolve to the
                                                                        CatchClause immediately above, but is
                                                                        never checked
```

---

## Root Cause

`RequireErrorBoundaryRule.runWithReporter`
(`lib/src/rules/flow/error_handling_rules.dart:733-758`):

```dart
context.addInstanceCreationExpression((InstanceCreationExpression node) {
  final String? constructorName = node.constructorName.type.element?.name;
  if (constructorName != 'MaterialApp' && constructorName != 'CupertinoApp') {
    return;
  }

  bool hasBuilder = false;
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == 'builder') {
      hasBuilder = true;
      break;
    }
  }

  if (!hasBuilder) {
    reporter.atNode(node.constructorName, code);
  }
});
```

The check is purely local to the `InstanceCreationExpression` itself: is the
type name `MaterialApp`/`CupertinoApp`, does its argument list contain a
`builder:` named argument. There is no ancestor walk at all — no call to
`node.thisOrAncestorOfType<CatchClause>()` or any equivalent — so the rule
cannot distinguish "the app's normal, always-constructed root widget" from
"a `MaterialApp` built exclusively as the recovery path inside a `catch`
block that already logged the real error." Both shapes produce an identical
diagnostic.

---

## Suggested Fix

Skip the diagnostic when the flagged `InstanceCreationExpression` is lexically
inside a `CatchClause` whose body already contains a recognized
logging/crash-reporting call (reusing the shared
`catchBodyHasLoggingCall`/`catchBodyLoggingMethodNames` helper from
`lib/src/catch_body_logging_utils.dart`, already used by
`require_error_logging` and `avoid_catching_generic_exception`):

```dart
final CatchClause? enclosingCatch = node.thisOrAncestorOfType<CatchClause>();
if (enclosingCatch != null && catchBodyHasLoggingCall(enclosingCatch.body)) {
  return; // Fallback UI built after the real error was already reported.
}
```

This reuses existing, already-tested detection logic rather than inventing a
new heuristic, and keeps the rule's true-positive case (a normal `MaterialApp`
built with no error handling anywhere) fully intact.

---

## Fixture Gap

The fixture at `example*/lib/flow/require_error_boundary_fixture.dart`
should include:

1. `MaterialApp(...)` (no `builder:`) constructed inside a `catch` clause
   whose body logs the caught error first — expect NO lint (current: LINT)
2. `MaterialApp(...)` (no `builder:`) as the app's normal top-level widget,
   outside any `catch` — expect LINT (current behavior, must keep working,
   the actual target case)
3. `MaterialApp(builder: ...)` anywhere — expect NO lint (current behavior,
   must keep working)

---

## Changes Made

Implemented the suggested fix exactly: `RequireErrorBoundaryRule.runWithReporter`
(`lib/src/rules/flow/error_handling_rules.dart`) now walks up to the
enclosing `CatchClause` via `node.thisOrAncestorOfType<CatchClause>()` and
skips the diagnostic when `catchBodyHasLoggingCall(enclosingCatch.body)` is
true (shared helper from `lib/src/catch_body_logging_utils.dart`, already
used by `require_error_logging` / `avoid_catching_generic_exception`).

**Not verified against the built plugin/scan CLI** — the working tree has
other in-progress, unrelated fixes (e.g. `lifecycle_rules.dart` references
an undefined `_isCleanedUpInDispose` method) that currently break the
package build, so `dart run saropa_lints scan` cannot run. The change
mirrors the report's suggested fix and reuses an already-tested helper;
re-run the scan CLI against the fixture once the build is unblocked.

---

## Tests Added

Added case 1 from the Fixture Gap section to
`example/lib/error_handling/require_error_boundary_fixture.dart`: a
`MaterialApp(...)` (no `builder:`) constructed inside a `catch` clause whose
body calls `debugException(...)` first — expected NO lint. Cases 2 and 3
(plain top-level `MaterialApp`, and `MaterialApp(builder: ...)`) already
existed in the fixture as `_bad359`/`_good359`.

---

## Commits

_None yet._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:262` (`MaterialApp` inside `main()`'s outer
  `on Object catch (error, stack)` block, starting at `lib/main.dart:255`)
