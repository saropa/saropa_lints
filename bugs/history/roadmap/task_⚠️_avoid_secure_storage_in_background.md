> **========================================================**
> **DUPLICATE -- DO NOT IMPLEMENT**
> **========================================================**
>
> Already implemented as `RequireSecureStorageErrorHandlingRule`
> in `lib/src/rules/security_rules.dart` (line 5644).
> Flags FlutterSecureStorage read/write/delete calls without
> try-catch -- exactly Phase 1 of this proposal.
>
> **========================================================**

# Task: `avoid_secure_storage_in_background`

## Summary
- **Rule Name**: `avoid_secure_storage_in_background`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.49 Secure Storage Rules

## Problem Statement

`flutter_secure_storage` uses platform keychain APIs:
- **iOS**: Keychain — requires the app to be in the foreground (or at least not fully backgrounded in some configurations)
- **Android**: Android Keystore — generally accessible in background, but biometric-protected keys require the device to be unlocked

When your app reads from secure storage in a background isolate, a WorkManager task, or an app lifecycle callback while the device is locked, the operation may:

1. **Fail silently** — return `null` without an error
2. **Throw a platform exception** — `PlatformException: Keychain item not found` on iOS
3. **Fail for biometric-protected keys** — on Android, keys with `isBiometricProtectionRequired: true` require the screen to be on and unlocked

Common problematic patterns:
```dart
// BUG: Background fetch that accesses secure storage while app is backgrounded
Future<void> backgroundSync() async {
  final token = await _storage.read(key: 'auth_token'); // ← may fail in background!
  await apiClient.sync(token);
}
```

## Description (from ROADMAP)

> Secure storage may fail in background. Detect background access without handling.

## Trigger Conditions

1. `FlutterSecureStorage.read()` or `.write()` inside:
   - A `WorkManager`/`BGTask` background task
   - A `ReceivePort` handler (isolate)
   - An `AppLifecycleState.paused` or `.detached` handler
   - A function that runs after `WidgetsBinding.didChangeAppLifecycleState` is backgrounded
2. No error handling (`try/catch PlatformException`) around the secure storage call in these contexts

**Phase 1 (Heuristic)**: Flag `FlutterSecureStorage.read/write` calls that are not inside a `try/catch` block.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isSecureStorageCall(node)) return; // read/write/delete
  // Check if wrapped in try/catch
  if (_isInsideTryCatch(node)) return;
  reporter.atNode(node, code);
});
```

`_isSecureStorageCall`: check method name is `read`, `write`, `delete`, `readAll`, `deleteAll` on a `FlutterSecureStorage` instance.
`_isInsideTryCatch`: walk parents for a `TryStatement`.

## Code Examples

### Bad (Should trigger)
```dart
// No error handling around secure storage
Future<void> getToken() async {
  final token = await _secureStorage.read(key: 'token'); // ← trigger: no try/catch
  return token;
}
```

### Good (Should NOT trigger)
```dart
// With error handling
Future<String?> getToken() async {
  try {
    return await _secureStorage.read(key: 'token');
  } on PlatformException catch (e) {
    // Handle keychain unavailability
    if (e.code == 'SecureStorageUnavailable') {
      return null; // Graceful degradation
    }
    rethrow;
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `try { await _storage.read() } catch...` | **Suppress** — has error handling | |
| Secure storage access in test | **Suppress** | |
| `_storage.read()` result used with `?.` (null-aware) | **Partial suppression** — null check but no exception handling | |
| `flutter_secure_storage` with `iOptions: IOSOptions.defaultOptions` (less restrictive) | **Complex** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `_secureStorage.read(key: 'token')` without `try/catch` → 1 lint
2. `_secureStorage.write(key: 'token', value: 'abc')` without `try/catch` → 1 lint

### Non-Violations
1. Same calls wrapped in `try/catch` → no lint
2. Test files → no lint

## Quick Fix

Offer "Wrap in try/catch":
```dart
// Before
final token = await _secureStorage.read(key: 'token');

// After
String? token;
try {
  token = await _secureStorage.read(key: 'token');
} on PlatformException {
  // Handle secure storage unavailability
  token = null;
}
```

## Notes & Issues

1. **flutter_secure_storage-only**: Only fire if `ProjectContext.usesPackage('flutter_secure_storage')`.
2. **Phase 1 is over-broad**: Requiring `try/catch` around ALL secure storage calls (not just background ones) will generate many false positives. The rule should ideally focus on background contexts. Phase 1's "no try/catch" detection is a practical starting point.
3. **iOS-specific concern**: The background access issue is more severe on iOS. On Android, most Keystore operations succeed in the background. Consider platform-specific detection.
4. **Biometric-protected keys**: On Android, keys with biometric protection require the device to be unlocked. This is a more specific scenario. The `isBiometricProtectionRequired` parameter in `AndroidOptions` is the relevant setting.
5. **WorkManager detection**: If the secure storage access is inside a `Workmanager.executeTask` callback, it's definitely in a background context. This is a specific, high-confidence trigger.
6. **Alternative patterns**: For background sync, consider:
   - Caching the token in a regular field when the app is foregrounded
   - Using a separate non-secure cache for background-accessible tokens (accepting reduced security)
   - Re-authenticating when app comes to foreground
