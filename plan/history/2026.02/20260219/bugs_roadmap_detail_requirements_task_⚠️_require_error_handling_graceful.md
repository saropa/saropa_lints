# Task: `require_error_handling_graceful`

## Summary
- **Rule Name**: `require_error_handling_graceful`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.19 http Package Security Rules

## Problem Statement

Showing raw technical error messages to users is poor UX and potentially a security issue:

```dart
// BAD: raw exception message shown to user
catch (e) {
  _showError(e.message);        // ← "Connection refused to 192.168.1.1:8080"
  _showError(e.toString());     // ← "SocketException: Failed to connect..."
  Text(error.toString());       // ← technical error in UI
}
```

Problems:
1. **UX**: Users don't understand technical error messages
2. **Security**: Internal server addresses, service names, internal error codes revealed
3. **Trust**: Apps that show stack traces or exception messages look unprofessional
4. **Accessibility**: Errors must be in the user's language, not English tech-speak

The correct approach: catch exceptions, log them appropriately, show a friendly localized message.

## Description (from ROADMAP)

> Show friendly errors, not technical ones. Detect raw exception messages in UI.

## Trigger Conditions

1. `e.toString()` or `error.toString()` used in a UI widget constructor (Text, etc.)
2. `e.message` (from exception) displayed directly in a dialog, snackbar, or Text widget
3. `exception.runtimeType.toString()` shown to user

**Note**: This rule overlaps significantly with `avoid_stack_trace_in_production`. Consider whether they should be merged.

## Implementation Approach

```dart
context.registry.addCatchClause((node) {
  final errorParam = node.exceptionParameter?.name?.lexeme;
  if (errorParam == null) return;

  node.body.accept(UiErrorDisplayVisitor(errorParam, reporter));
});
```

`UiErrorDisplayVisitor`: walks the catch body looking for:
- `Text(e.toString())` or `Text(e.message)`
- `SnackBar(content: Text(e.toString()))`
- `AlertDialog(content: Text(e.toString()))`
- Constructor argument containing `e.toString()`

## Code Examples

### Bad (Should trigger)
```dart
try {
  await loadData();
} catch (e) {
  // Technical message shown to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.toString())),  // ← trigger
  );

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      content: Text('Error: ${e.message}'),  // ← trigger
    ),
  );
}
```

### Good (Should NOT trigger)
```dart
try {
  await loadData();
} on NetworkException catch (e) {
  // Log for developers
  logger.error('Network error', error: e, stackTrace: s);
  // Show friendly message to users
  _showFriendlyError(context, 'Unable to load data. Please try again.');
} on AuthException {
  // User-friendly auth error
  _showFriendlyError(context, 'Your session has expired. Please sign in again.');
} catch (e, s) {
  // Unknown error — log, but show generic message
  logger.error('Unexpected error', error: e, stackTrace: s);
  _showFriendlyError(context, 'Something went wrong. Please try again later.');
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `if (kDebugMode) Text(e.toString())` | **Suppress** — debug only | |
| Custom exception with user-facing `message` | **Complex** — `e.message` may be user-friendly | Can't know if `message` is user-friendly |
| Crash reporters (`Crashlytics.recordError(e, s)`) | **Suppress** — not showing to user | |
| Error logging to non-UI destination | **Suppress** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Text(e.toString())` inside catch clause → 1 lint
2. `SnackBar(content: Text(error.toString()))` in catch → 1 lint

### Non-Violations
1. `Text('An error occurred')` (hardcoded friendly message) → no lint
2. `logger.error(e.toString())` (logging, not UI) → no lint
3. `if (kDebugMode) print(e)` → no lint

## Quick Fix

Offer "Replace with generic error message":
```dart
// Before
Text(e.toString())

// After
Text('An error occurred. Please try again.')
```

## Notes & Issues

1. **Overlap with `avoid_stack_trace_in_production`**: Both rules target showing technical information to users. Consider merging into one rule: `avoid_technical_errors_in_ui`. The merged rule would cover both raw exception messages and stack traces.
2. **`e.message` ambiguity**: Many exception classes have a `message` property. Some are technical (`SocketException.message = "Connection refused to 127.0.0.1:8080"`), some are user-friendly (custom exceptions with localized messages). The lint can't distinguish these statically.
3. **String interpolation**: `'Error: $e'` is equivalent to `'Error: ${e.toString()}'` — both should be detected.
4. **Localization context**: The "friendly" message should ideally be translated. A companion rule could check that error messages go through the l10n system.
5. **Log-then-rethrow**: Some patterns rethrow exceptions after logging. If the rethrower's caller handles it correctly, the intermediate rethrow is OK. Don't flag rethrowing.
6. **Severity**: Essential tier is appropriate — showing raw exceptions to users is a fundamental UX and security issue that affects all apps.
