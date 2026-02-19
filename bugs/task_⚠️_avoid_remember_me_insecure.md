# Task: `avoid_remember_me_insecure`

## Summary
- **Rule Name**: `avoid_remember_me_insecure`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.5 Security Rules — Authentication & Authorization
- **OWASP**: M1: Improper Credential Usage

## Problem Statement

"Remember Me" functionality that stores plaintext credentials (username/password) in `SharedPreferences`, a local file, or any non-encrypted storage is a critical security vulnerability. If a device is lost, rooted, or accessed via ADB, the plaintext credentials can be extracted and used to compromise the account permanently.

The correct approach is to use refresh tokens (OAuth 2.0 pattern) with rotation and revocation:
- Issue a short-lived access token (15 min) and long-lived refresh token
- Store the refresh token in platform secure storage (Keychain/Keystore)
- Rotate the refresh token on each use
- Allow server-side revocation without changing passwords

## Description (from ROADMAP)

> "Remember me" storing unencrypted credentials is a security risk. Use refresh tokens with proper rotation and revocation.

## Trigger Conditions

1. `SharedPreferences.setString(key, value)` where the key contains `password`, `passwd`, `credentials`, `credential`, `secret`, `pwd`
2. `SharedPreferences.setString(key, value)` where the KEY suggests auth but value is a string (not a token-shaped string)
3. Any write to `SharedPreferences` / `Hive` / `sqflite` of fields named `password`, `credentials`, `rememberMe: true` with a password field

### Phase 2 — Credential pattern in any storage
Detect any storage call where the key or field name resembles a credential:
- `prefs.setString('password', value)`
- `box.put('credentials', value)`
- `db.insert('users', {'password': value})`

## Implementation Approach

### Storage API Detection

```dart
context.registry.addMethodInvocation((node) {
  if (!_isStorageWrite(node)) return;
  final keyArg = _getFirstStringArg(node);
  if (keyArg == null) return;
  if (!_isCredentialKey(keyArg)) return;
  reporter.atNode(node, code);
});
```

`_isStorageWrite`: detect `SharedPreferences.setString`, `SharedPreferences.setString`, `box.put`, `prefs.set*`.
`_isCredentialKey`: check if key string contains `password`, `passwd`, `credentials`, `credential`, `secret`, `pwd`, `pin` (case-insensitive).

### Exclusions for Token-like Keys
Keys containing `token`, `refresh_token`, `access_token` should NOT trigger because tokens are not passwords (they can be rotated and revoked).

## Code Examples

### Bad (Should trigger)
```dart
// Storing password in SharedPreferences
final prefs = await SharedPreferences.getInstance();
await prefs.setString('password', userPassword);  // ← trigger

// "Remember me" storing credentials
if (rememberMe) {
  await prefs.setString('saved_credentials', '$username:$password');  // ← trigger
}

// Hive storage
await box.put('user_password', password);  // ← trigger
```

### Good (Should NOT trigger)
```dart
// Storing refresh token in secure storage ✓
await secureStorage.write(key: 'refresh_token', value: token);

// No password storage — using biometric auth ✓
final authenticated = await biometricAuth.authenticate();

// Storing token (not password) ✓
await prefs.setString('auth_token', accessToken);  // 'token' key — ok

// flutter_secure_storage for anything credential-related ✓
await const FlutterSecureStorage().write(key: 'password', value: password);
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Key is `password_strength` (not a credential) | **False positive** — strength is not a password | Key matching must be careful: exact word match, not just substring |
| Key is `passwordHash` | **Trigger** — even hashed passwords shouldn't be in SharedPreferences | Store in secure storage |
| Key is `token` or `refresh_token` | **Suppress** — tokens are appropriate in secure storage | Whitelist `token`, `refresh_token`, `jwt` |
| `flutter_secure_storage` write | **Suppress** — secure storage IS the correct approach | Detect `FlutterSecureStorage().write(...)` and suppress |
| Test file with mock credentials | **Suppress** | `ProjectContext.isTestFile` |
| `SharedPreferences.setString('last_password_change', dateString)` | **False positive** — date is not a credential | Better key matching needed |
| In-memory storage (not persisted) | **Suppress** — only flag persisted storage | |
| `prefs.setString('show_password', 'true')` (UI setting) | **False positive** — 'show_password' is a UI toggle | |
| Encrypted SharedPreferences (`EncryptedSharedPreferences`) | **Suppress** — encrypted is acceptable | Detect usage of encryption wrapper |

## Unit Tests

### Violations
1. `prefs.setString('password', value)` → 1 lint
2. `prefs.setString('user_passwd', value)` → 1 lint
3. `box.put('credentials', value)` → 1 lint
4. `prefs.setString('remember_me_pwd', value)` → 1 lint

### Non-Violations
1. `prefs.setString('auth_token', value)` → no lint (token key)
2. `secureStorage.write(key: 'password', value: pw)` → no lint (secure storage)
3. `prefs.setString('show_password', 'true')` → no lint (UI setting, not a credential)
4. Test file → no lint
5. `prefs.setString('password_strength', '3')` → no lint (not a credential value)

## Quick Fix

Offer "Use `flutter_secure_storage` instead":
```dart
// Before:
await prefs.setString('password', value);

// After:
await const FlutterSecureStorage().write(key: 'password', value: value);
```

Only applicable when `flutter_secure_storage` is already a dependency.

## Notes & Issues

1. **OWASP M1** — this is a security-critical rule. WARNING is appropriate; ERROR might be too aggressive but consider it for Essential tier.
2. **Key matching precision**: Simple substring matching on `password` will produce false positives for `password_changed_date`, `show_password`, `password_strength`. Use word-boundary matching or exact match against a curated set.
3. **`flutter_secure_storage` is the canonical solution** for Android (Keystore) and iOS (Keychain). The rule should mention it prominently.
4. **Encrypted shared preferences** (Android Jetpack `EncryptedSharedPreferences`) is also acceptable. Detecting it from Dart code is hard — note as a known false positive.
5. **The "remember me" checkbox pattern** is hard to detect without understanding the flow. The simpler credential-key-in-storage detection is more tractable for Phase 1.
