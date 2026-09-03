# PROPOSAL: Require Exact-Alarm Permission Check Before Scheduling Exact Notifications

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `use_local_notifications_exact_alarm_permission_api` to flag `flutter_local_notifications`' `zonedSchedule(...)` calls using `AndroidScheduleMode.exactAllowWhileIdle`/`exact` without a preceding check/request of the `SCHEDULE_EXACT_ALARM` permission via the plugin's Android-specific permission API — Android 12+ (API 31+) requires this permission explicitly, and a missing check causes exact alarms to silently degrade to inexact scheduling.

**Closes gap:** `flutter_skill_lints` `use_local_notifications_exact_alarm_permission_api`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` `flutter_skill_lints` gap list.

---

## Motivation

This is a real, well-documented Android 12+ platform trap: apps scheduling exact-time notifications (reminders, alarms) without requesting `SCHEDULE_EXACT_ALARM` get their notifications silently rescheduled to an inexact window by the OS, with no exception thrown — the bug only surfaces as "my reminder fired 20 minutes late" in production, long after the developer tested on an older device or emulator. saropa has no `flutter_local_notifications`-specific rules today.

---

## Detection / Behavior

Flag a `zonedSchedule(...)` call (from `FlutterLocalNotificationsPlugin`) whose `androidScheduleMode` argument is `AndroidScheduleMode.exactAllowWhileIdle` or `.exact`, when the enclosing function/class has no call to `AndroidFlutterLocalNotificationsPlugin.canScheduleExactNotifications()`/`requestExactAlarmsPermission()` reachable before it.

### Should flag (bad code)

```dart
await plugin.zonedSchedule(
  0,
  'Reminder',
  'Time!',
  scheduledDate,
  details,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // LINT — no exact-alarm permission check
);
```

### Should pass (good code)

```dart
final androidPlugin = plugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
final canSchedule = await androidPlugin?.canScheduleExactNotifications() ?? false;
if (canSchedule) {
  await plugin.zonedSchedule(
    0,
    'Reminder',
    'Time!',
    scheduledDate,
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // OK — guarded
  );
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Package-specific rule (`flutter_local_notifications` dependency required), Android-only concern — appropriate for Comprehensive per the package-specific-rule convention.

---

## Edge Cases

1. **`androidScheduleMode: .inexactAllowWhileIdle`** — should pass; inexact modes don't require the special permission.
2. **Permission check performed in a different function, called before the scheduling function at a higher level (e.g. app startup)** — should discuss; single-function reachability analysis is the v1 scope and will under-detect cross-function guards, a known limitation to document rather than chase with full call-graph analysis.
3. **iOS-only notification scheduling path (no `androidScheduleMode` argument branch reached on iOS)** — should pass; the flagged API is Android-specific by construction.
4. **Permission checked but result ignored (`await ...canScheduleExactNotifications();` with no branching on it)** — should still flag; checking without acting on the result doesn't prevent the degrade-to-inexact behavior.

---

## Alternatives Considered

---

## Decision

---

## Implementation Notes

---

## Commits
