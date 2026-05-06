# `require_notification_for_long_tasks` — false positive: fires on foreground operations with their own UI status feedback

**Status: Closed**

**Resolved:** Implemented camelCase-aligned pattern matching (`longOperationMethodNameMatchesPattern` in `lib/src/long_operation_method_name_match.dart`), `dbProcessAll…` exclusion, expanded file-level skip literals (`onStatusUpdate`, progress widgets, `awesome_notifications`, etc.), split example fixtures (BAD-only vs false-positive guards). Fix 3 (background-entrypoint-only scope) intentionally deferred as larger work. See `CHANGELOG.md` Unreleased section and unit tests `test/long_operation_method_name_match_test.dart`, `test/require_notification_for_long_tasks_fixture_test.dart`.

---

Filed: 2026-04-26
Rule: `require_notification_for_long_tasks`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line 2269, code at 2285–2334)
Severity: False positive (detection too eager + short-circuit too narrow)
Rule version: v2 | Severity in code: WARNING | Impact: medium

---

## Summary

The rule's stated intent is to catch *background* long-running tasks that the OS can kill silently — uploads, downloads, sync operations — that should show a system **notification** so the OS keeps them alive and the user knows the app is working.

In practice the rule fires on **foreground** database operations and import flows that are awaited from a screen with full UI feedback (snackbars, progress bars, status text via `_updateLoadingStatus(...)`). The OS cannot kill these tasks because the app is in the foreground, holding the screen, and the user is staring at progress UI. Adding `flutter_local_notifications` for these is wrong — it would post a system notification *while the user is watching the in-app spinner*, which is noise.

Two specific detection flaws:

1. **Pattern matching is substring-based and case-insensitive.** Method names like `dbProcessAllContactListGroupMemberships` match `processAll`, and `internetImport` matches `importAll`. The rule has no way to tell a database transaction (sub-second to a few seconds, foreground) apart from a multi-minute background upload.
2. **The short-circuit is narrow.** The rule skips a file only if it contains the literal strings `showNotification`, `showProgressNotification`, or `FlutterLocalNotifications`. Files using foreground status patterns — calling `_updateLoadingStatus(l10n.statusFetching(...))`, showing `CommonProgressIndicator`, or driving snackbars via `PopupToastUtils` — are not recognized as "this is a foreground task, the OS won't kill it" and the rule fires anyway.

---

## Attribution Evidence

```bash
$ grep -rn "'require_notification_for_long_tasks'" lib/src/rules/
lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:2286:    'require_notification_for_long_tasks',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:2269` (`RequireNotificationForLongTasksRule`)
**Rule class:** `RequireNotificationForLongTasksRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Six sites currently flagged:

### Site 1 — `lib/views/main_startup_utils.dart:499`

```dart
// Foreground startup task. App is opening, splash visible, user is waiting
// on the screen. Method name "ProcessAll" triggers the substring match.
await DatabaseContactMembershipIO.dbProcessAllContactListGroupMemberships();
// LINT — but should NOT lint (foreground startup, user is watching splash)
```

### Site 2 — `lib/views/main_startup_utils.dart:692`

```dart
// Foreground cooldown check, returns in milliseconds. Method name
// "_isFacebookFriendsImportAllowedNow" matches "ImportAll" substring.
final bool isAllowed = await _isFacebookFriendsImportAllowedNow();
// LINT — but should NOT lint (cooldown check, not an import)
```

### Site 3 — `lib/views/main_startup_utils.dart:1029`

```dart
// Foreground astronomical-events cooldown check, returns boolean from a
// SharedPreferences/Drift read. Substring match: "ImportAll".
final bool isAllowed = await _isAstronomicalCalendarImportAllowedNow();
// LINT — but should NOT lint
```

### Site 4 — `lib/views/event/calendar_events_screen.dart:396`

```dart
// Full-screen calendar import dialog with progress UI driven by
// onStatusUpdate callback. The method literally takes a status callback —
// proof of foreground feedback — and the rule still fires.
final CalendarImportResult? importResult =
    await CalendarImportUtils.importAllEventsWithStats(
  startDate: _dateRange.start,
  endDate: _dateRange.end,
  onStatusUpdate: _updateLoadingStatus, // ← foreground UI status driver
  createContactsForAttendees: true,
);
// LINT — but should NOT lint
```

### Site 5 — `lib/database/drift_middleware/user_data/contact_drift_io.dart:3312`

```dart
// Database transaction — sub-second on typical contact lists. Substring
// match: "ProcessAll".
await DatabaseContactMembershipIO.dbProcessAllContactListGroupMemberships();
// LINT — but should NOT lint (DB write, not a long task)
```

### Site 6 — `lib/utils/native_phone_import/native_import_utils.dart:669`

```dart
// Same DB call inside a fire-and-forget after-import cleanup. Substring
// match: "ProcessAll". Not a long task; not background; not killable.
unawaited(DatabaseContactMembershipIO.dbProcessAllContactListGroupMemberships());
// LINT — but should NOT lint
```

**Frequency:** Always, on any awaited method whose name's lowercase form contains a pattern in `_longOperationPatterns` (see line 2296). Substring-only matching with no semantic awareness.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on foreground operations driving in-app UI status (snackbars, progress dialogs, status callbacks). Diagnostic limited to genuinely background long-running work — isolate tasks, `WorkManager`/`BackgroundService`/`flutter_background_service` registrations, BGTaskScheduler/BGAppRefreshTask handlers. |
| **Actual** | Fires on every awaited call whose name substring-matches `processAll`, `importAll`, etc., regardless of foreground/background context, regardless of whether the surrounding code is showing UI feedback. |

---

## AST Context

The reported node is the `MethodInvocation` itself:

```
ExpressionStatement / VariableDeclarationStatement
  └─ AwaitExpression
      └─ MethodInvocation (foo.dbProcessAllX())  ← node reported here
          └─ MethodName ("dbProcessAllContactListGroupMemberships")
```

Detection logic (lines 2310–2333):

```dart
final String fileSource = context.fileContent;

// Short-circuit: literal-substring check for three exact names
if (fileSource.contains('showNotification') ||
    fileSource.contains('showProgressNotification') ||
    fileSource.contains('FlutterLocalNotifications')) {
  return;
}

context.addMethodInvocation((MethodInvocation node) {
  final String methodName = node.methodName.name;
  for (final String pattern in _longOperationPatterns) {
    if (methodName.toLowerCase().contains(pattern.toLowerCase())) {
      reporter.atNode(node);
      return;
    }
  }
});
```

`_longOperationPatterns` (line 2296):

```dart
static const Set<String> _longOperationPatterns = {
  'uploadFile', 'uploadLarge', 'downloadFile', 'downloadLarge',
  'syncAll', 'processAll', 'exportAll', 'importAll',
  'backupData', 'restoreData', 'migrateDatabase',
};
```

---

## Root Cause

Two independent flaws compound:

### Flaw A: substring matching with no boundary

`methodName.toLowerCase().contains('processall')` matches:

- `dbProcessAllContactListGroupMemberships` ✓ (intended-ish — but it's a DB call, not a long task)
- `processAllUsersInBackground` ✓
- `_isFacebookFriendsImportAllowedNow` matches `'importall'` substring (`ImportAll` in `IsImportAllowed`) ✓ — clearly unintended
- `_isAstronomicalCalendarImportAllowedNow` — same ✓ — clearly unintended

There is no word-boundary check. `_isXxxImportAllowedNow` is a guard predicate; nothing about it indicates a long task.

### Flaw B: short-circuit only matches three literal names

A foreground task is signaled by *driving in-app UI status*, not by importing `flutter_local_notifications`. Apps that use:

- `_updateLoadingStatus(...)` callbacks → not detected
- `PopupToastUtils.showCommonNotice(...)` / snackbars → not detected
- `CommonProgressIndicator` / `LinearProgressIndicator` widgets → not detected
- `onStatusUpdate:` named arguments → not detected
- `awesome_notifications` plugin (a common alternative to `flutter_local_notifications`) → not detected
- A custom in-app notification framework → not detected

…all get the diagnostic anyway. The escape hatch is too narrow to match real codebases.

---

## Suggested Fix

Three layered fixes; do them all:

### Fix 1 — Word-boundary the pattern check

Replace `methodName.toLowerCase().contains(pattern)` with a check that the method name *starts with* or has a clean camelCase boundary at the pattern. Example:

```dart
bool _matchesLongOperation(String methodName) {
  for (final String pattern in _longOperationPatterns) {
    final regex = RegExp(r'(^|[A-Z_])' + pattern + r'($|[A-Z_])',
        caseSensitive: false);
    if (regex.hasMatch(methodName)) return true;
  }
  return false;
}
```

This still matches `dbProcessAllContactListGroupMemberships` (boundary at `_` / `Process`) but rejects `_isImportAllowedNow` (no word boundary — `Allow` is part of a larger camelCase identifier `Allowed`).

### Fix 2 — Broaden the short-circuit to recognize foreground-status patterns

Add to the early-return:

```dart
// Foreground UI feedback indicates the task runs while the user is in the
// app — the OS will not kill it, and a system notification would be redundant.
final foregroundSignals = const [
  'awesome_notifications',          // common alternative plugin
  '_updateLoadingStatus',           // named status callback common pattern
  'onStatusUpdate',                 // named-arg pattern
  'CommonProgressIndicator',        // visible progress widgets
  'LinearProgressIndicator',
  'CircularProgressIndicator',
  'showSnackBar',
  'PopupToastUtils',                // snackbar/toast helpers
];
if (foregroundSignals.any(fileSource.contains)) {
  return;
}
```

Better yet, expose a project-level config option: `notification_for_long_tasks.foreground_signals: [...]` so each project can declare its own status-feedback API names.

### Fix 3 — Restrict to truly-background entry points

The rule's *real* target is background work: `BackgroundService.onStart`, `Workmanager().registerOneOffTask` callbacks, `BGTaskScheduler` handlers, isolate `compute()` callbacks. A more accurate detection would be:

> Only emit when the flagged `MethodInvocation` is reachable from a known background-task entrypoint (registered as a `WorkManager` task, declared in a foreground service, or run inside an isolate spawned by `compute()`/`Isolate.spawn`).

This is a larger architectural change to the rule. Fixes 1 + 2 are sufficient for the immediate false-positive load.

---

## Fixture Gap

The fixture at `example*/lib/platforms/require_notification_for_long_tasks_fixture.dart` should include:

1. **`processAllUsers()` in a `void main()` with no UI** — expect LINT
2. **`processAllUsers()` in a Stateful widget that shows `CircularProgressIndicator` while awaiting** — expect NO lint
3. **`isImportAllowed()` predicate (substring `importAll` but not a long task)** — expect NO lint *(currently false positive)*
4. **`dbProcessAllRecords()` inside a Drift transaction** — expect NO lint *(currently false positive — it's a sub-second DB op)*
5. **`uploadFile()` from a `Workmanager().registerOneOffTask` callback** — expect LINT
6. **`uploadFile()` from a button press handler that drives `setState` for progress** — expect NO lint
7. **File using `awesome_notifications` plugin instead of `flutter_local_notifications`** — expect NO lint *(currently false positive — only `FlutterLocalNotifications` literal escapes)*

---

## Downstream

Tracked in `contacts/`. Once this report exists, six sites get `// ignore: require_notification_for_long_tasks` with a comment pointing at this bug. Sites listed in **Reproducer** above.

---

## Environment

- saropa_lints version: 12.4.0
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
