# BUG: `require_ios_push_notification_capability` — Flags non-push permission requests (contacts, location, audio, file picker) as needing the push-notification capability

**Status: Open**

Created: 2026-10-31
Rule: `require_ios_push_notification_capability`
File: `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart` (line ~942)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags non-push permission requests (contacts, location, audio, file picker) as needing the push-notification capability. In a downstream app review, 5 of 5 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_push_notification_capability'" lib/src/rules/
# lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:942:    'require_ios_push_notification_capability',
```

**Emitter registration:** `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:942`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
Future<bool> requestContactPermission() async {
  // LINT — but should NOT lint: this is a contacts permission request, not push.
  return await Permission.contacts.request().isGranted;
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/user/native_permissions/contact_permission.dart:15 (contacts), location_permission.dart:138, audio_media_permission.dart:54, lib/utils/file_io/file_io.dart:235. The project's iOS entitlements already contain `aps-environment`.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[require_ios_push_notification_capability]` reported at each site above |

---

## Root Cause

The rule fires on any `request*Permission` call in a file, not only on notification permission APIs; it does not check the project's Runner entitlements for `aps-environment`.

---

## Suggested Fix

Fire only when the call is a notification-permission request (`requestNotificationPermission`, `FirebaseMessaging.requestPermission`, `Permission.notification`). Skip when `ios/Runner/*.entitlements` already contains `aps-environment`.

---

## Fixture Gap

The fixture for `require_ios_push_notification_capability` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed: `requestPermission()` is now flagged only when its receiver source contains messaging/notification/push/fcm (`FirebaseMessaging.instance.requestPermission()`, `messaging.requestPermission()`). `Geolocator.requestPermission()` and other non-push receivers are skipped; `Permission.x.request()` was never matched. `getToken`, `onMessage` and the push class patterns are unchanged. Fixture updated with bad/good cases; verified by `dart run saropa_lints:scan --tier comprehensive` on a scratch copy (push receiver flagged, Geolocator/Permission not). The entitlements-file check from the suggested fix is not done (rule cannot see project files).
