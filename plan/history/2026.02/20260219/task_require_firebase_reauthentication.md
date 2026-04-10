> **IMPLEMENTED — v6.0.7**
>
> `RequireFirebaseReauthenticationRule` in `lib/src/rules/packages/firebase_rules.dart`. Essential tier. Sensitive Auth ops (delete, updateEmail, updatePassword) must be preceded by reauth in same method (by source offset). requiredPatterns and firebase_auth dependency check.

# Task: `require_firebase_reauthentication`

## Summary
- **Rule Name**: `require_firebase_reauthentication`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Implemented
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
  await FirebaseAuth.instance.currentUser?.delete(); // <- may fail with FirebaseAuthException
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
  final sensitiveOps = _findSensitiveFirebaseOps(node.body);
  if (sensitiveOps.isEmpty) return;
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
Future<void> onDeleteAccountTapped() async {
  final user = FirebaseAuth.instance.currentUser;
  await user?.delete(); // <- trigger: no reauthentication
}

Future<void> changePassword(String newPassword) async {
  final user = FirebaseAuth.instance.currentUser!;
  await user.updatePassword(newPassword); // <- trigger
}
```

### Good (Should NOT trigger)
```dart
Future<void> onDeleteAccountTapped() async {
  final user = FirebaseAuth.instance.currentUser!;
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: _passwordController.text,
  );
  await user.reauthenticateWithCredential(credential);
  await user.delete(); // <- OK: preceded by reauthentication
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Reauthentication in a separate method called before | **Suppress** | Cross-method analysis needed |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `user.delete()` without preceding `reauthenticateWithCredential` -> 1 lint
2. `user.updateEmail()` without reauthentication -> 1 lint
3. `user.updatePassword()` without reauthentication -> 1 lint

### Non-Violations
1. `user.reauthenticateWithCredential(...)` followed by `user.delete()` in same function -> no lint
2. Test files -> no lint

## Quick Fix

No automated fix — reauthentication requires collecting credentials from the user.

## Notes & Issues

1. **firebase_auth-only**: Only fire if `ProjectContext.usesPackage('firebase_auth')`.
2. **OWASP**: Maps to **M4: Insufficient Authentication/Authorization**.
3. **Cross-method analysis**: Phase 1 only checks within the same function body.
4. **Google Sign-In**: `reauthenticateWithProvider` is also recognized as valid reauthentication.
5. **User.reload()**: Only `reauthenticateWithCredential` confirms recent login.
