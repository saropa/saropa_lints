# PROPOSAL: Avoid Remember Me Insecure

**Status: Open**

Created: 2026-09-02

## Summary

Flags "remember me" / persistent-login tokens that are written to storage without encryption (e.g. via `shared_preferences` or a raw file) and without any expiry field, rather than through encrypted, expiring storage.

## Motivation

A "remember me" flow persists a long-lived credential across app restarts, so it is a higher-value target than a short-lived session token — anyone who reads the device's storage (backup extraction, rooted/jailbroken device, another app on a misconfigured Android version) gets standing access to the account. Storing that token in plaintext `shared_preferences`, and without an expiry, compounds the risk: the token never rotates and is trivially readable by any code or tool that can read the app's data directory.

## Detection / Behavior

Flags writes of a value whose key/variable name matches `remember*token`, `persistent*token`, `auto*login*token`, etc. (or is passed alongside a `rememberMe: true` flag) into `SharedPreferences`/`Hive` (non-encrypted stores) instead of `flutter_secure_storage`, and flags such writes that store only the raw token with no accompanying expiry timestamp/field.

```dart
// Bad:
if (rememberMe) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('remember_me_token', loginToken); // LINT: persistent token in unencrypted storage, no expiry
}

// Good:
if (rememberMe) {
  final storage = FlutterSecureStorage();
  await storage.write(
    key: 'remember_me_token',
    value: jsonEncode({'token': loginToken, 'expiresAt': expiry.toIso8601String()}),
  );
}
```

## Security Mapping

OWASP Mobile M9: Insecure Data Storage.

## Quick Fix

None — manual refactor required. Migrating storage backend and adding an expiry field changes the data schema and requires a deliberate decision on TTL, so it cannot be safely automated.

## Alternatives Considered

Folding this into the existing generic `AvoidStoringSensitiveUnencryptedRule` / `RequireSecureStorageForAuthRule` (`lib/src/rules/security/security_auth_storage_rules.dart`) was considered, since both address unencrypted sensitive storage. Kept separate because "remember me" tokens have a second, independent failure mode those rules do not check — missing expiry — and a distinct name gives clearer guidance for this specific, high-risk pattern.
