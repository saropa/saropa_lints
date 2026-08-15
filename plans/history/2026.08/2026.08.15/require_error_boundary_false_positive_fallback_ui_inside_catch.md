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

- `0c9b4248` — fix: require_error_boundary no longer flags MaterialApp built as logged catch-clause fallback UI
- `d3674f09` — docs: archive fixed require_error_boundary bug report

---

## Finish Report (2026-08-15)

`RequireErrorBoundaryRule.runWithReporter` reported `require_error_boundary`
on every argument-less `MaterialApp`/`CupertinoApp` construction with no
check for lexical context, so a fatal-startup-error recovery screen built
inside `main()`'s outer `catch` clause — after the real error had already
been logged — was flagged identically to the app's normal, always-built
root widget. The fix adds a `node.thisOrAncestorOfType<CatchClause>()` walk
and skips the diagnostic when the enclosing catch body already contains a
recognized logging/crash-reporting call, via the shared
`catchBodyHasLoggingCall` helper in `lib/src/catch_body_logging_utils.dart`
(the same helper already used by `require_error_logging` and
`avoid_catching_generic_exception`, so the exemption stays consistent
across all three rules).

`example/lib/error_handling/require_error_boundary_fixture.dart` gained
`_good360`: a `MaterialApp` built inside `on Object catch (error, stack) {
debugException(error, stack); ... }`, covering Fixture Gap case 1 from the
bug report. Cases 2 and 3 (plain top-level `MaterialApp`, and
`MaterialApp(builder: ...)`) were already present as `_bad359`/`_good359`
and continue to pass.

**Verification:** `dart test test/rules/flow/error_handling_rules_test.dart`
— 50/50 passed, including the `RequireErrorBoundaryRule` instantiation and
fixture-existence checks. The rule's own message/code assertions are
unaffected by this change (no wording change), so no assertion updates were
needed. The end-to-end `dart run saropa_lints scan` path against the
fixture was attempted but not completed: the scan CLI's `--files` targeting
against the `example/` package root returned `No .dart files found` in this
session regardless of invocation form tried (root with `--files`, `example`
as target root, run from inside `example/`). Root cause isolated:
`ScanRunner._isExcluded` (`lib/src/scan/scan_runner.dart:656-669`)
unconditionally rejects any path containing `/example`, applied both to
directory discovery and to explicit `--files` lists — the scan CLI cannot
scan this package's own `example/` fixtures under any invocation, by
design, independent of this change. Logic was verified by code trace and
the passing unit-test suite instead.

### Hardening pass (same day)

The initial fix exempted any `MaterialApp`/`CupertinoApp` inside a logged
`catch` clause, anywhere in the codebase — too broad: an unrelated logged
catch elsewhere (not a startup-fallback path) that happened to also
construct a `MaterialApp` would have silently lost its error-boundary
requirement. Tightened the exemption to additionally require the enclosing
`TryStatement`'s `body` to itself call `runApp(...)` (new
`_tryBodyCallsRunApp` helper, source-text `RegExp` scan matching the style
of `catchBodyHasLoggingCall`) — this ties the exemption to the actual
try-`runApp`/catch-log-and-`runApp`-fallback idiom described in the bug
report, not to any logged catch in general.

Fixture additions: `_good360` updated so its `try` body calls
`runApp(MyHomePage())` (previously called an unrelated helper, which would
now fail the tightened check); `_good362` added to exercise the
receiver-based branch of `catchBodyHasLoggingCall` (`analytics.track(error)`
rather than a recognized method name); `_bad361` added — a logged catch
whose `try` body does **not** call `runApp`, which must remain flagged.
`dart test test/rules/flow/error_handling_rules_test.dart` re-run after
each edit, 50/50 passing throughout.

### Second hardening pass (same day) — scope to `main()`

Even with the `runApp`-in-try-body condition, the exemption still applied
to any try/catch shaped like the bootstrap idiom anywhere in the codebase —
a helper function unrelated to app startup that happens to log and also
call `runApp` (e.g. a test harness spinning up a second Flutter engine)
would still have been silently exempted. Added a third, required condition:
`_isInsideMainFunction` walks up to the nearest enclosing
`FunctionDeclaration` and requires it to be a top-level function literally
named `main`. The rule deliberately does not attempt to trace calls into a
helper `main()` delegates to (e.g. `_bootstrap()`) — that needs call-graph
analysis this AST-local rule doesn't have — so a bootstrap split across
functions still requires an explicit `builder:`; this is a stricter,
false-negative-safe default over guessing at the call graph.

Fixture: `_good360`/`_good362` moved into the file's one legitimate
top-level `main()` (as two independent try/catch blocks — Dart permits only
one `main()` per file); `_bad363` added — the same logged-catch/`runApp`-in-try
shape as the exemption, but in a non-`main()` helper function, and must
still be flagged. `dart test test/rules/flow/error_handling_rules_test.dart`
re-run, 50/50 passing.



- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:262` (`MaterialApp` inside `main()`'s outer
  `on Object catch (error, stack)` block, starting at `lib/main.dart:255`)
