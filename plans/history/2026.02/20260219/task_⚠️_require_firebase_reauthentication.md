# Task: `require_firebase_reauthentication`

## Summary
- **Rule Name**: `require_firebase_reauthentication`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.29 Firebase Advanced Rules

## Problem Statement

Firebase requires **recent authentication** for sensitive operations:
- Deleting the account (`user.delete()`)
- Changing email (`user.updateEmail()`)
- Changing password (`user.updatePassword()`)
- Updating security-critical profile data

If a user signed in more than a few minutes ago (Firebase's threshold), attempting these operations without reauthentication throws `FirebaseAuthException` with code `requires-recent-login`.

The common mistake is calling these sensitive methods without first reauthenticating:

```dart
// BUG: No reauthentication check
Future<void> deleteAccount() async {
  await FirebaseAuth.instance.currentUser?.delete(); // ← may fail with FirebaseAuthException
  // User sees a crash instead of a proper "Please sign in again" dialog
}
```

The correct approach:
```dart
Future<void> deleteAccount() async {
  // First reauthenticate
  await user.reauthenticateWithCredential(credential);
  // Then perform sensitive operation
  await user.delete();
}
```

## Description (from ROADMAP)

> Sensitive operations need recent auth. Detect sensitive ops without reauthenticateWithCredential.

## Trigger Conditions

1. Calls to sensitive Firebase operations without `reauthenticateWithCredential` or `reauthenticateWithProvider` in the same function:
   - `user.delete()`
   - `user.updateEmail()`
   - `user.updatePassword()`
   - `user.verifyBeforeUpdateEmail()`

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  // Check if method contains a sensitive Firebase operation
  final sensitiveOps = _findSensitiveFirebaseOps(node.body);
  if (sensitiveOps.isEmpty) return;

  // Check if reauthenticate is also called in the same scope
  if (_hasReauthentication(node.body)) return;

  for (final op in sensitiveOps) {
    reporter.atNode(op, code);
  }
});
```

`_findSensitiveFirebaseOps`: search for method invocations where name is `delete`, `updateEmail`, `updatePassword`, `verifyBeforeUpdateEmail` on a `User` receiver.
`_hasReauthentication`: search for `reauthenticateWithCredential` or `reauthenticateWithProvider` in the same function body.

## Code Examples

### Bad (Should trigger)
```dart
// Deleting account without reauthentication
Future<void> onDeleteAccountTapped() async {
  final user = FirebaseAuth.instance.currentUser;
  await user?.delete(); // ← trigger: no reauthentication
}

// Updating password without reauthentication
Future<void> changePassword(String newPassword) async {
  final user = FirebaseAuth.instance.currentUser!;
  await user.updatePassword(newPassword); // ← trigger
}
```

### Good (Should NOT trigger)
```dart
Future<void> onDeleteAccountTapped() async {
  final user = FirebaseAuth.instance.currentUser!;

  // Step 1: Reauthenticate
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: _passwordController.text,
  );
  await user.reauthenticateWithCredential(credential);

  // Step 2: Delete account (now recent auth confirmed)
  await user.delete(); // ← OK: preceded by reauthentication
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Reauthentication in a separate method called before | **Suppress** — if `_reauthenticate()` is called before sensitive op | Cross-method analysis needed for accuracy |
| `try/catch` handling the `requires-recent-login` error | **Suppress** — developer is handling it | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |
| `user.delete()` in a function that is explicitly named `_afterReauthentication` | **Suppress** | |

## Unit Tests

### Violations
1. `user.delete()` without preceding `reauthenticateWithCredential` → 1 lint
2. `user.updateEmail()` without reauthentication → 1 lint
3. `user.updatePassword()` without reauthentication → 1 lint

### Non-Violations
1. `user.reauthenticateWithCredential(...)` followed by `user.delete()` in same function → no lint
2. Test files → no lint

## Quick Fix

No automated fix — reauthentication requires collecting credentials from the user (email/password dialog or OAuth flow). Suggest adding a reauthentication dialog before the sensitive operation.

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')`.
2. **OWASP**: Maps to **M4: Insufficient Authentication/Authorization**.
3. **Cross-method analysis challenge**: If `_reauthenticate()` is called in a separate method that runs before the sensitive operation, the lint can't detect this without control flow analysis. Phase 1 only checks within the same function body.
4. **`catch` suppression**: If the code catches `FirebaseAuthException` with code `requires-recent-login` and handles it (by triggering reauthentication), the pattern is correct. This is complex to detect statically.
5. **Google Sign-In reauthentication**: For federated auth (Google, Apple), reauthentication uses `reauthenticateWithProvider`. Ensure this is also recognized as valid reauthentication.
6. **User.reload()**: Some developers call `user.reload()` before sensitive operations thinking it refreshes auth state. It doesn't — only `reauthenticateWithCredential` confirms recent login.
