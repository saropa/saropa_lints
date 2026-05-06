# Task: `require_firebase_token_refresh`

## Summary
- **Rule Name**: `require_firebase_token_refresh`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase Auth tokens expire every **1 hour**. The Flutter Firebase SDK auto-refreshes tokens when making Firebase calls (Firestore, Storage, RTDB), but when your app sends the token to a **custom backend server**, you must handle token refresh manually.

Common mistake: storing the token once at login and never refreshing it:
```dart
// At login:
final token = await user.getIdToken(); // ← gets token valid for 1 hour
SharedPreferences.instance.then((prefs) => prefs.setString('auth_token', token));

// Later (after 1 hour):
final token = prefs.getString('auth_token'); // ← stale token!
await myBackend.authenticatedRequest(token); // ← 401 Unauthorized
```

The `idTokenChanges()` stream is the correct mechanism — it fires when the token is refreshed:
```dart
FirebaseAuth.instance.idTokenChanges().listen((user) {
  if (user != null) {
    user.getIdToken().then((token) {
      // Update stored token
      _currentToken = token;
    });
  }
});
```

## Description (from ROADMAP)

> Handle token refresh on idTokenChanges. Detect missing refresh handler.

## Trigger Conditions

1. `user.getIdToken()` called outside of an `idTokenChanges().listen()` callback to get a token for storage/caching
2. `user.getIdToken()` result stored in `SharedPreferences`, a variable, or a service without a corresponding `idTokenChanges` subscription

**Phase 1**: Flag `user.getIdToken()` (without `forceRefresh: true`) when the result is assigned to a field or stored in `SharedPreferences` — this suggests caching a potentially stale token.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isGetIdToken(node)) return; // user.getIdToken()
  // Check if this is inside an idTokenChanges listener
  if (_isInsideIdTokenChangesCallback(node)) return;
  // Check if result is being stored (assigned to a field or SharedPrefs)
  if (_resultIsBeingStored(node)) {
    reporter.atNode(node, code);
  }
});
```

`_isGetIdToken`: check method name `getIdToken` on a `User` receiver.
`_isInsideIdTokenChangesCallback`: walk parents for a `MethodInvocation` where the method is `listen` and the receiver is `idTokenChanges()`.
`_resultIsBeingStored`: check if parent is an assignment to a field or `SharedPreferences.setString(...)`.

## Code Examples

### Bad (Should trigger)
```dart
// Storing token once without refresh handling
Future<void> login() async {
  final user = FirebaseAuth.instance.currentUser!;
  final token = await user.getIdToken();  // ← trigger: token cached without refresh listener
  _apiClient.setAuthToken(token);
  await prefs.setString('cached_token', token);
}
```

### Good (Should NOT trigger)
```dart
// Using idTokenChanges for auto-refresh
@override
void initState() {
  super.initState();
  FirebaseAuth.instance.idTokenChanges().listen((user) {
    if (user != null) {
      user.getIdToken().then((token) {  // ← OK: inside idTokenChanges listener
        _apiClient.setAuthToken(token);
      });
    }
  });
}

// Force refresh before sending to backend
Future<String> _getFreshToken() async {
  return await FirebaseAuth.instance.currentUser!.getIdToken(true);
  // ← OK: forceRefresh: true always gets a fresh token
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `getIdToken(true)` (forceRefresh) | **Suppress** — always fresh | |
| `getIdToken()` used immediately without storage | **Suppress** — no caching issue | |
| `getIdToken()` inside `idTokenChanges().listen()` | **Suppress** — correct pattern | |
| Token used directly in a one-time API call (not stored) | **Suppress** — ephemeral use | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `user.getIdToken()` result stored in `SharedPreferences` without `idTokenChanges` listener → 1 lint
2. `user.getIdToken()` assigned to a class field without refresh handling → 1 lint

### Non-Violations
1. `user.getIdToken(true)` (force refresh) → no lint
2. `user.getIdToken()` inside `idTokenChanges().listen()` callback → no lint
3. `user.getIdToken()` used immediately in same expression → no lint

## Quick Fix

Offer "Add `idTokenChanges` listener":
```dart
// Before
final token = await user.getIdToken();
_apiClient.setAuthToken(token);

// After
FirebaseAuth.instance.idTokenChanges().listen((user) {
  if (user != null) {
    user.getIdToken().then((token) {
      _apiClient.setAuthToken(token);
    });
  }
});
```

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')`.
2. **The token lifetime**: Firebase tokens expire in 1 hour. `idTokenChanges` fires ~5 minutes before expiry for refresh. This is the correct mechanism for custom backends.
3. **`forceRefresh: true`**: Passing `true` to `getIdToken(true)` forces a new token regardless of expiry. This is expensive (network call) but guarantees freshness. Not a great solution to call on every request — `idTokenChanges` is better.
4. **Dio interceptor pattern**: A common, correct pattern is a Dio interceptor that calls `user.getIdToken(true)` on 401 responses. This is a valid approach and should be suppressed.
5. **Firebase SDK auto-refresh**: For calls directly to Firebase services (Firestore, Storage), the SDK auto-refreshes tokens. This rule only applies to custom backend calls where you pass the token manually.
