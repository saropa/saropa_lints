> **IMPLEMENTED — v6.0.7**
>
> `RequireFirebaseTokenRefreshRule` in `lib/src/rules/packages/firebase_rules.dart`. Essential tier. getIdToken() stored (variable/prefs/set) without idTokenChanges or forceRefresh. requiredPatterns and firebase_auth dependency check.

# Task: `require_firebase_token_refresh`

## Summary
- **Rule Name**: `require_firebase_token_refresh`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Implemented
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase Auth tokens expire every **1 hour**. When your app sends the token to a **custom backend server**, you must handle token refresh manually.

Common mistake: storing the token once at login and never refreshing it:
```dart
final token = await user.getIdToken();
SharedPreferences.instance.then((prefs) => prefs.setString('auth_token', token));
```

The `idTokenChanges()` stream is the correct mechanism — it fires when the token is refreshed:
```dart
FirebaseAuth.instance.idTokenChanges().listen((user) {
  if (user != null) {
    user.getIdToken().then((token) { _currentToken = token; });
  }
});
```

## Description (from ROADMAP)

> Handle token refresh on idTokenChanges. Detect missing refresh handler.

## Trigger Conditions

1. `user.getIdToken()` called outside of an `idTokenChanges().listen()` callback to get a token for storage/caching
2. `user.getIdToken()` result stored in `SharedPreferences`, a variable, or a service without a corresponding `idTokenChanges` subscription

**Phase 1**: Flag `user.getIdToken()` (without `forceRefresh: true`) when the result is assigned to a field or stored in `SharedPreferences`.

## Implementation Approach

- `_isGetIdToken`: check method name `getIdToken` on a `User` receiver.
- `_isInsideIdTokenChangesCallback`: walk parents for `listen` on `idTokenChanges()`.
- `_resultIsBeingStored`: check if parent is assignment, VariableDeclaration, or SharedPreferences setString.

## Code Examples

### Bad (Should trigger)
```dart
Future<void> login() async {
  final user = FirebaseAuth.instance.currentUser!;
  final token = await user.getIdToken();  // <- trigger
  _apiClient.setAuthToken(token);
  await prefs.setString('cached_token', token);
}
```

### Good (Should NOT trigger)
```dart
FirebaseAuth.instance.idTokenChanges().listen((user) {
  if (user != null) {
    user.getIdToken().then((token) { _apiClient.setAuthToken(token); });
  }
});

return await user.getIdToken(true);  // OK: forceRefresh
```

## Edge Cases & False Positives

| Scenario | Expected Behavior |
|---|---|
| `getIdToken(true)` (forceRefresh) | **Suppress** |
| `getIdToken()` inside `idTokenChanges().listen()` | **Suppress** |
| Token used directly in a one-time API call (not stored) | **Suppress** |
| Test files | **Suppress** |

## Unit Tests

### Violations
1. `user.getIdToken()` result stored without `idTokenChanges` listener -> 1 lint

### Non-Violations
1. `user.getIdToken(true)` -> no lint
2. `user.getIdToken()` inside `idTokenChanges().listen()` callback -> no lint

## Quick Fix

Offer "Add `idTokenChanges` listener" (suggested in task; not implemented).

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')`.
2. **forceRefresh: true**: Suppressed; guarantees freshness.
3. **Firebase SDK auto-refresh**: This rule only applies to custom backend calls where you pass the token manually.
