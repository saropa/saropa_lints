# Task: `avoid_stack_trace_in_production`

## Summary
- **Rule Name**: `avoid_stack_trace_in_production`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.40 Debugging & Logging Rules

## Problem Statement

Exposing stack traces to users is both a security vulnerability and a bad user experience:

1. **Security**: Stack traces reveal internal class names, method names, file paths, and package versions. This information helps attackers understand the app's architecture for targeted attacks.
2. **UX**: Raw stack traces are incomprehensible to end users ("java.lang.NullPointerException at com.example...")
3. **Compliance**: Medical, financial, and government apps may have regulations against exposing technical error details

**OWASP M10: Extraneous Functionality** — leaving debug information accessible in production.

Common patterns that leak stack traces:
```dart
// Showing raw exception to user
_showErrorDialog(e.toString()); // ← includes stack trace in some cases

// Printing to UI
Text(error.toString()); // ← may show "Instance of 'SocketException': ..."

// Logging to a location visible to users
print(stackTrace); // ← on Android, logcat can be read by other apps
```

## Description (from ROADMAP)

> Don't show stack traces to users. Detect printStackTrace in error handlers.

## Trigger Conditions

1. A `StackTrace` object converted to string (`.toString()`) in a context that displays it to users
2. `print(stackTrace)` or `print(e)` where `e` is from a `catch` clause (on Android, logcat is accessible)
3. Error dialog/snackbar content derived directly from an exception's `toString()` or `stackTrace.toString()`

**Key distinction**: Logging stack traces to crash reporters (Crashlytics, Sentry) is GOOD. Displaying them to users or printing to logcat in production code is BAD.

## Implementation Approach

```dart
context.registry.addCatchClause((node) {
  final body = node.body;
  // Check if body calls print with the error or stack trace
  _checkForPrintCalls(body, node, reporter);
  // Check if body creates text/dialog/snackbar with error.toString()
  _checkForUiErrorDisplay(body, node, reporter);
});
```

### Detecting `print(e)` in catch:
```dart
void _checkForPrintCalls(Block body, CatchClause catchClause, reporter) {
  body.accept(PrintCallVisitor(
    errorVarName: catchClause.exceptionParameter?.name?.lexeme,
    stackTraceVarName: catchClause.stackTraceParameter?.name?.lexeme,
    reporter: reporter,
  ));
}
```

### Detecting UI display:
Look for `Text(e.toString())`, `showDialog(content: e.toString())`, `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())))`.

## Code Examples

### Bad (Should trigger)
```dart
try {
  await apiCall();
} catch (e, stackTrace) {
  print(stackTrace);  // ← trigger: stack trace to logcat (readable on Android)
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(e.toString()), // ← trigger: raw error to user
    ),
  );
}
```

### Good (Should NOT trigger)
```dart
try {
  await apiCall();
} catch (e, stackTrace) {
  // Log to crash reporter (not to user)
  FirebaseCrashlytics.instance.recordError(e, stackTrace);
  // Show friendly message to user
  _showErrorMessage(context, 'Something went wrong. Please try again.');
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `print(e)` in debug mode (`kDebugMode`) | **Suppress** — debug only | `if (kDebugMode) print(e)` |
| `debugPrint(e.toString())` | **Trigger** — still goes to logcat | |
| Crash reporters (`FirebaseCrashlytics.instance.recordError(e, s)`) | **Suppress** | |
| Sentry `captureException(e, stackTrace: s)` | **Suppress** | |
| `log(e.toString(), level: Level.SEVERE)` | **Trigger** — unless properly guarded | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |
| `e.toString()` used to derive a sanitized message | **Complex** — may still be OK | |

## Unit Tests

### Violations
1. `print(stackTrace)` in catch clause → 1 lint
2. `Text(e.toString())` in catch clause body → 1 lint
3. `showDialog(content: Text(e.toString()))` → 1 lint

### Non-Violations
1. `FirebaseCrashlytics.instance.recordError(e, s)` → no lint
2. `if (kDebugMode) print(e)` → no lint
3. `Text('An error occurred')` (hardcoded, not from exception) → no lint

## Quick Fix

Offer "Replace with user-friendly message":
```dart
// Before
Text(e.toString())

// After
Text('An error occurred. Please try again.')
```

Or "Wrap in kDebugMode guard":
```dart
// Before
print(stackTrace);

// After
if (kDebugMode) {
  print(stackTrace);
}
```

## Notes & Issues

1. **OWASP**: Maps to **M10: Extraneous Functionality** and **M1: Improper Platform Usage**.
2. **`print()` vs `debugPrint()` vs `log()`**: All write to logcat on Android. On rooted devices or via ADB, other apps can read logcat. In production, none of these should expose user data or stack traces.
3. **The `kDebugMode` suppression**: Code inside `if (kDebugMode)` is tree-shaken in release builds, so `print()` calls there are safe.
4. **FlutterError.onError**: A common pattern is setting `FlutterError.onError = (details) => print(details)` — this is a WARNING target.
5. **Crash reporter vs logcat**: The lint must distinguish between logging to a crash reporter (good) and logging to logcat/console (bad in production). Check for known crash reporter method names: `recordError`, `captureException`, `addBreadcrumb`.
6. **Scope**: This rule is in the "http Package Security Rules" section but it's really a general security rule. Consider moving to a "Security / Logging" category during implementation.
