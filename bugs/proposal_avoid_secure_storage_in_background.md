# PROPOSAL: Avoid Secure Storage In Background

**Status: Open**

Created: 2026-09-02

## Summary

Flags `flutter_secure_storage` reads/writes performed inside a background isolate or background-invoked handler (e.g. a Firebase `onBackgroundMessage` handler, a `WorkManager`/headless callback, or an `Isolate.spawn` entry point), where the OS keychain/keystore may be locked and the call fails silently or throws.

## Existing Coverage

`lib/src/rules/security/security_auth_storage_rules.dart` has `RequireSecureStorageErrorHandlingRule`, which requires `flutter_secure_storage` calls to be wrapped in error handling generally, and `RequireKeychainAccessRule`, which recommends using Keychain-backed storage at all. Neither checks the *execution context* (background isolate vs. foreground) — this is a genuine extension targeting a context-specific failure mode, not a duplicate.

## Motivation

On iOS, Keychain items with the default accessibility class (`kSecAttrAccessibleWhenUnlocked` equivalent) are inaccessible while the device is locked, so a background isolate — a Firebase Cloud Messaging background handler, a `WorkManager` task, or any headless callback that can run while the screen is off — that calls `flutter_secure_storage` at that moment gets an empty/error result. Because such handlers commonly run detached from any UI and their errors are easy to leave unhandled or unlogged, the app silently loses access to tokens it needs (e.g. to authenticate an API call triggered by the push handler), producing hard-to-reproduce, device-lock-state-dependent bugs that look like data loss.

## Detection / Behavior

Flags `FlutterSecureStorage` read/write calls found inside functions annotated or named as background entry points — `@pragma('vm:entry-point')` top-level functions, `onBackgroundMessage` handler bodies, `Workmanager().executeTask` callbacks — that are not wrapped in a try/catch or do not check for a null/empty result before use.

```dart
// Bad:
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final storage = FlutterSecureStorage();
  final token = await storage.read(key: 'auth_token'); // LINT: secure storage read in background handler may fail if keychain is locked
  await api.reportDelivery(token!, message.messageId);
}

// Good:
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final storage = FlutterSecureStorage();
  try {
    final token = await storage.read(key: 'auth_token');
    if (token == null) return; // keychain may be locked; skip rather than crash
    await api.reportDelivery(token, message.messageId);
  } catch (_) {
    return; // storage unavailable in this background execution context
  }
}
```

## Security Mapping

OWASP Mobile M9: Insecure Data Storage (background access to keychain-backed storage without accounting for the device-lock accessibility policy).

## Quick Fix

None — manual refactor required. Whether to skip the operation, retry on next foreground launch, or use a different accessibility class for the stored item is an application-specific decision.

## Alternatives Considered

Extending `RequireSecureStorageErrorHandlingRule` to also require try/catch in background contexts was considered but rejected — that rule fires on every secure-storage call regardless of context and does not name the keychain-lock cause, so it would not communicate the platform-specific reason for the failure or scope the check to background entry points specifically.
