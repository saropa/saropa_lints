# Task: `prefer_local_notification_for_immediate`

## Summary
- **Rule Name**: `prefer_local_notification_for_immediate`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.15 Push Notification Rules
- **Priority**: ⭐ Next in line for implementation

## Problem Statement

Firebase Cloud Messaging (FCM) is a server-to-device messaging system. It requires a round-trip to Firebase servers, internet connectivity, and is subject to delivery delays and OS-level throttling. When the trigger for a notification is local app state (a timer firing, a local reminder, completing a task), routing the notification through FCM introduces unnecessary latency, network dependency, and battery cost. `flutter_local_notifications` sends notifications directly from within the app process, is guaranteed-delivery (OS permitting), and works offline.

Teams frequently reach for FCM because they already have it set up, even for purely local use cases. This rule nudges them toward the correct tool.

## Description (from ROADMAP)

> `flutter_local_notifications` is better for app-generated notifications. FCM is for server-triggered messages.

## Trigger Conditions

Detect calls to `FirebaseMessaging` methods used to send/schedule a notification **from within the client app** when there is no server involvement:

1. Code that constructs and "sends" an FCM message client-side (using `http` or `dio` to call FCM REST API directly from Flutter code)
2. Code that uses `flutter_local_notifications` is absent, but `firebase_messaging` is present, AND the app has timer/alarm/reminder logic that generates notifications
3. (Phase 2) `Timer` + `FirebaseMessaging.instance.sendMessage(...)` pattern

### Simpler Heuristic (Phase 1)
Look for `FirebaseMessaging.instance` usage inside `Timer` callbacks, `Future.delayed`, or `SchedulerBinding` frame callbacks — these strongly suggest the notification trigger is local, not server-side.

## Implementation Approach

### Package Detection
Only fire if:
- Project uses `firebase_messaging` — `ProjectContext.usesPackage('firebase_messaging')`
- Project does NOT use `flutter_local_notifications` — if they have it, they already know about it

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isFirebaseMessagingCall(node)) return;
  if (!_isInsideTimerOrDelayedContext(node)) return;
  reporter.atNode(node, code);
});
```

### Detecting Local Context
Walk up the parent chain from the `MethodInvocation` looking for:
- `FunctionExpression` that is the body of `Timer(duration, callback)`
- `AwaitExpression` → `Future.delayed(...)`
- Any callback that is clearly triggered by app-internal state

## Code Examples

### Bad (Should trigger)
```dart
// Using FCM to send notification triggered locally by a timer
void scheduleReminder() {
  Timer(Duration(hours: 1), () async {
    // Calling FCM REST API directly from client — wrong tool
    await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      body: jsonEncode({'notification': {'title': 'Reminder'}}),
    );
  });
}

// Sending message to self via FCM (self-messaging anti-pattern)
await FirebaseMessaging.instance.sendMessage(
  to: await FirebaseMessaging.instance.getToken(),
  data: {'type': 'local_reminder'},
);
```

### Good (Should NOT trigger)
```dart
// Using flutter_local_notifications for local reminders ✓
await _localNotifications.show(
  id,
  'Reminder',
  'Your task is due',
  details,
);

// Using FCM for server-triggered notification ✓
// (this is in a cloud function / backend, not Flutter code)
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| FCM `sendMessage` to a different device (not self) | **Suppress** — this IS a server-ish use case (device-to-device) | Hard to detect statically; may need to suppress entirely |
| Background isolate with FCM | **Suppress** — background message handling is legitimate FCM use | Check if inside `@pragma('vm:entry-point')` handler |
| Test files mocking FCM | **Suppress** — test code is irrelevant | Use `ProjectContext.isTestFile` |
| App both uses FCM (server) AND flutter_local_notifications (local) | **Suppress** — developer already knows the distinction | Presence of both packages = suppress |
| Self-messaging via FCM inside `Timer` | **Trigger** — clearest false positive risk is here; fire only on confirmed self-send | getToken() + sendMessage combo |
| Firebase Functions integration test | **Suppress** | Test file check |

## Unit Tests

### Violations
1. Project has `firebase_messaging`, no `flutter_local_notifications`, `Timer` callback contains `http.post` to FCM endpoint → 1 lint
2. `FirebaseMessaging.instance.sendMessage(to: await getToken(), ...)` inside `Timer` → 1 lint

### Non-Violations
1. Project has both `firebase_messaging` AND `flutter_local_notifications` → no lint
2. FCM message handled in `FirebaseMessaging.onMessage` handler (receiving, not sending) → no lint
3. Test file → no lint
4. Project uses only `firebase_messaging` for server-push receiving, no local timers → no lint

## Quick Fix

No automated quick fix. The correction message should be informational:

```
correctionMessage: 'Use flutter_local_notifications for app-generated notifications. FCM is designed for server-to-device messages.'
```

## Notes & Issues

1. **Detection is imprecise** — it is genuinely hard to distinguish "app is sending a message to itself" from "app is relaying a message to another user" at static analysis time. Phase 1 should be conservative and only fire on the most obvious patterns (Timer + FCM REST API call).
2. **FCM self-messaging pattern** (`sendMessage(to: await getToken())`) is a known anti-pattern that is unambiguous — this should be the Phase 1 target.
3. **Consider deferring** the Timer-based heuristic to Phase 2 or ROADMAP_DEFERRED.md — the `[TOO-COMPLEX]` tag may apply to detecting what's inside a callback without control flow analysis.
4. **Priority**: Since this is ⭐ next in line, the conservative Phase 1 (FCM self-send detection) should be implemented first. It is unambiguous and has very low false positive rate.
