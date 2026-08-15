# BUG: `require_firebase_app_check_production` — Only Scans the Immediate Enclosing `FunctionBody`, Misses `activate()` in a Separate Function in the Same File

**Status: Fixed**

Created: 2026-08-15
Rule: `require_firebase_app_check_production`
File: `lib/src/rules/packages/firebase_rules.dart` (line ~2983)
Severity: False positive
Rule version: v1 | Since: v5.1.0

---

## Summary

The rule reports on `Firebase.initializeApp()` unless
`FirebaseAppCheck`/`AppCheck` text appears somewhere in the same enclosing
`FunctionBody` as the call. It never looks beyond that one function — not at
the rest of the file, not at other startup-task functions the app defers
App Check activation to. In `lib/main.dart`,
`Firebase.initializeApp()` is called inside `main()`, and
`FirebaseAppCheck.instance.activate()` is correctly called ~350 lines later
inside a separate function, `_initFirebaseAppCheck()`, deferred through a
`StartupTaskRunner` task queue — a deliberate pattern so a slow/flaky Play
Integrity check can't block first frame. The rule cannot see across that
function boundary and reports a false positive.

The sibling rule `require_firebase_app_check`
(`lib/src/rules/packages/firebase_rules.dart:2035`) shares the exact same
root cause — it also scopes its App Check search to
`node.parent`-walk-to-enclosing-`MethodDeclaration`/`FunctionDeclaration`
(lines 2078-2098) rather than the whole file — and fires on the same call
site for the same reason. It is not filed separately; fixing the shared
"search scope" defect in one rule's mechanism should inform the fix for both.

---

## Attribution Evidence

```bash
grep -rn "'require_firebase_app_check_production'" lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:3005:    'require_firebase_app_check_production',
grep -rn "'require_firebase_app_check'" lib/src/rules/
# lib/src/rules/packages/firebase_rules.dart:2055:    'require_firebase_app_check',
```

**Emitter registration:** `lib/src/rules/packages/firebase_rules.dart:3005` (production variant), `:2055` (paired/duplicate `require_firebase_app_check`)
**Rule class:** `RequireFirebaseAppCheckProductionRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Verified against `lib/main.dart`: `Firebase.initializeApp()` at line 235
inside `main()` (`main.dart:169`); `FirebaseAppCheck.instance.activate()` at
line 540 inside the separate function `_initFirebaseAppCheck()`
(`main.dart:523-560`), invoked via `StartupTaskRunner.run(task:
_initFirebaseAppCheck, ...)` later in the same file.

```dart
Future<void> main() async {
  try {
    // LINT — but should NOT lint: App Check IS activated in this file,
    // just inside a different function, deliberately deferred so a slow
    // Play Integrity check on emulators can't block first frame.
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
  } on Object catch (error, stack) {
    debug(() => 'Firebase initialization failed: $error', stackTrace: stack);
  }

  runApp(const MainInitializerScreen(initFactory: _initializeCoreServices));
}

/// Runs ~350 lines later, queued as a deferred startup task — NOT called
/// from main(), NOT textually near Firebase.initializeApp(), but it IS the
/// project's App Check activation, in the same file.
Future<void> _initFirebaseAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    providerApple: const AppleDeviceCheckProvider(),
    providerAndroid: const AndroidPlayIntegrityProvider(),
  );
}

Future<void> _runBackgroundStartupTasks() async {
  await StartupTaskRunner.run(task: _initFirebaseAppCheck, taskName: 'App Check');
}
```

**Frequency:** Always, whenever App Check activation is deferred to a
separate function from the one calling `Firebase.initializeApp()` — a common
pattern for apps that don't want a slow/flaky App Check provider blocking
Firebase Core availability or first frame.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `FirebaseAppCheck.instance.activate()` is present and reachable from app startup in the same file, just in a different function |
| **Actual** | `[require_firebase_app_check_production] Calling Firebase.initializeApp() without activating Firebase App Check leaves your backend unprotected...` reported at the `Firebase.initializeApp()` call inside `main()` |

---

## AST Context

```
CompilationUnit (main.dart)
  ├─ FunctionDeclaration (main)
  │   └─ body: BlockFunctionBody               ← context.addMethodInvocation node's
  │       └─ TryStatement                          thisOrAncestorOfType<FunctionBody>()
  │           └─ MethodInvocation                  resolves HERE — search source = this body only
  │               (Firebase.initializeApp())   ← flagged node; body.toSource() does NOT
  │                                                contain 'FirebaseAppCheck' or 'AppCheck'
  │
  └─ FunctionDeclaration (_initFirebaseAppCheck)   ← a SIBLING top-level declaration;
      └─ body: BlockFunctionBody                      never visited by this rule's search
          └─ MethodInvocation
              (FirebaseAppCheck.instance.activate(...))   ← the activation call the rule needs
                                                              to find, but never looks here
```

---

## Root Cause

`RequireFirebaseAppCheckProductionRule.runWithReporter`
(`lib/src/rules/packages/firebase_rules.dart:3018-3043`):

```dart
context.addMethodInvocation((MethodInvocation node) {
  if (node.methodName.name != 'initializeApp') return;

  final Expression? target = node.realTarget;
  if (target == null) return;
  if (target is! SimpleIdentifier || target.name != 'Firebase') return;

  // Check if the same function body contains AppCheck activation
  final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
  if (body == null) return;

  final String source = body.toSource();
  if (RegExp(r'\bFirebaseAppCheck\b').hasMatch(source) ||
      RegExp(r'\bAppCheck\b').hasMatch(source)) {
    return;
  }

  reporter.atNode(node);
});
```

The search scope is `node.thisOrAncestorOfType<FunctionBody>()` — the single
nearest enclosing function/method body of the `initializeApp()` call, full
stop. There is no fallback to `context.fileContent` (used by other rules in
this same file, e.g. `RequireFirebaseAppCheckRule`'s sibling check at line
2090-2093 for the `FunctionDeclaration` branch, and by
`RequireIosDeploymentTargetConsistencyRule` for its file-level escape hatch)
and no walk to sibling top-level declarations. Any project that defers App
Check activation — for startup-latency reasons, retry logic, or simply
code organization — to a function textually and structurally separate from
the `Firebase.initializeApp()` call site cannot satisfy this rule no matter
where in the file the activation call lives.

The sibling `RequireFirebaseAppCheckRule.runWithReporter`
(`lib/src/rules/packages/firebase_rules.dart:2062-2112`) has the identical
defect: for a `MethodDeclaration` enclosing context, it checks
`enclosingMethod.toSource()`; for a `FunctionDeclaration` enclosing context,
it checks that function's own source — never the rest of the file, never
sibling declarations.

---

## Suggested Fix

Fall back to `context.fileContent` (the whole-file source, already used
elsewhere in this file and consistent with the class doc's own note: "App
Check activation typically happens once at app startup, not necessarily in
the same file" — an intent the code doesn't implement) when the immediate
`FunctionBody` doesn't contain the activation call:

```dart
final String? bodySource = node.thisOrAncestorOfType<FunctionBody>()?.toSource();
final String haystack = bodySource ?? '';
final bool activatedNearby = RegExp(r'\bFirebaseAppCheck\b').hasMatch(haystack) ||
    RegExp(r'\bAppCheck\b').hasMatch(haystack);
final bool activatedInFile = RegExp(r'\bFirebaseAppCheck\b').hasMatch(context.fileContent) ||
    RegExp(r'\bAppCheck\b').hasMatch(context.fileContent);

if (activatedNearby || activatedInFile) return;
reporter.atNode(node);
```

Apply the same fallback to `RequireFirebaseAppCheckRule`.

---

## Fixture Gap

The fixture at
`example*/lib/packages/require_firebase_app_check_production_fixture.dart`
should include:

1. `Firebase.initializeApp()` in one top-level function,
   `FirebaseAppCheck.instance.activate()` in a separate top-level function in
   the same file — expect NO lint (current: LINT)
2. `Firebase.initializeApp()` with `activate()` in the same function body —
   expect NO lint (current behavior, must keep working)
3. `Firebase.initializeApp()` with no `activate()` anywhere in the file —
   expect LINT (must keep working, the actual target case)

The mirrored fixture for `require_firebase_app_check` should get the same
three cases.

---

## Changes Made

- `RequireFirebaseAppCheckProductionRule.runWithReporter` (`lib/src/rules/packages/firebase_rules.dart`) now falls back to a whole-file (`context.fileContent`) search for `FirebaseAppCheck`/`AppCheck` when the immediate enclosing `FunctionBody` doesn't contain it, before reporting.
- `RequireFirebaseAppCheckRule.runWithReporter` (same file) got the identical fallback for both its `MethodDeclaration` and `FunctionDeclaration` enclosing-context branches.
- Extracted the shared `FirebaseAppCheck`/`AppCheck` regex check into a top-level `_containsAppCheckActivation` helper used by both rules.
- Added the three fixture cases from the "Fixture Gap" section above to `example_packages/lib/packages/require_firebase_app_check_fixture.dart` and `example_packages/lib/firebase/require_firebase_app_check_production_fixture.dart` (the latter previously had a placeholder only).

---

## Tests Added

- `test/rules/packages/firebase_app_check_deferred_activation_test.dart` — resolved-rule harness regression tests for both rules: no false positive when activation is deferred to a sibling top-level function, and both rules still fire when no activation exists anywhere in the file.

---

## Commits

_None yet._

---

## Environment

- saropa_lints version: (repo HEAD at filing time)
- Dart SDK version: n/a
- custom_lint version: n/a
- Triggering project/file: downstream Flutter/Dart app (contacts),
  `lib/main.dart:235` (`Firebase.initializeApp()` in `main()`) vs.
  `lib/main.dart:540` (`FirebaseAppCheck.instance.activate()` in
  `_initFirebaseAppCheck()`, ~305 lines later, called via
  `StartupTaskRunner.run(task: _initFirebaseAppCheck, ...)`)

---

## Finish Report (2026-08-15)

Both `require_firebase_app_check_production` and `require_firebase_app_check`
scoped their App Check activation search to the immediate enclosing function
body only, producing a false positive whenever an app deliberately deferred
`FirebaseAppCheck.instance.activate()` to a separate function in the same
file (e.g. a queued startup task run after first frame).

Both rules now fall back to a whole-file search (`context.fileContent`) for
`FirebaseAppCheck`/`AppCheck` when the immediate function body doesn't
contain it, before reporting a diagnostic. The duplicated regex check
previously inlined at three call sites was extracted into a shared
`_containsAppCheckActivation` helper in `lib/src/rules/packages/firebase_rules.dart`.

Fixture coverage was added for all three cases named in the original report:
activation in the same function (already covered), activation deferred to a
separate top-level function in the same file (the false-positive case, now
silent), and no activation anywhere in the file (still flagged). A new
resolved-analyzer regression test,
`test/rules/packages/firebase_app_check_deferred_activation_test.dart`,
pins both the fixed and the preserved true-positive behavior for both rules
(4 cases, all passing). The existing
`test/rules/packages/firebase_rules_test.dart` suite (69 cases) continues to
pass unmodified.

A follow-up attempt to harden the whole-file fallback with a reachability
check (requiring the function containing `activate()` to be referenced
elsewhere in the file, not just present as dead code or a comment mention)
was implemented and then reverted after a test case exposed a defect in
the reachability logic that wasn't diagnosed before a token budget cutoff
forced the session to wrap up. The plain whole-file text-match fallback —
fully verified — shipped instead. The reachability idea remains valid
future work; see the unstated-assumptions note in the handover for where to
pick it back up.
