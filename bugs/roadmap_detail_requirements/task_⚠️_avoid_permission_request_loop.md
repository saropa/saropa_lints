# Task: `avoid_permission_request_loop`

## Summary
- **Rule Name**: `avoid_permission_request_loop`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.12 permission_handler Rules

## Problem Statement

When a user denies a permission, most operating systems remember that denial. If an app repeatedly requests the same permission without checking the denial status, it creates a bad user experience:

1. **Android**: After two denials, the system permanently disables the permission dialog (shows "Don't ask again"). Re-requesting will silently return `denied` forever.
2. **iOS**: After one denial, re-requesting returns `denied` immediately — the system never shows the dialog again.

Detecting permission denial and then immediately re-requesting inside a loop or recursive call is a common anti-pattern that:
- Violates platform UX guidelines
- May trigger app store rejection
- Frustrates users into force-closing the app

The correct pattern: check status, if denied, show a dialog explaining WHY the permission is needed, then direct user to **Settings** via `openAppSettings()`.

## Description (from ROADMAP)

> Don't repeatedly request denied permission. Detect request in loop or retry.

## Trigger Conditions

1. `permission.request()` or `Permission.X.request()` inside a `for`/`while`/`do-while` loop
2. `permission.request()` called after checking `status.isDenied` without a `shouldShowRequestRationale` or `openAppSettings()` call in between
3. Recursive function that calls `permission.request()`

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isPermissionRequest(node)) return;

  // Check if inside a loop
  if (_isInsideLoop(node)) {
    reporter.atNode(node, code);
    return;
  }

  // Check if in an if-block that checks isDenied/isPermanentlyDenied
  // without openAppSettings() as the alternative
});
```

`_isPermissionRequest`: check if method name is `request` and receiver type is from `permission_handler`.
`_isInsideLoop`: walk parent tree for `ForStatement`, `WhileStatement`, `DoStatement`.

## Code Examples

### Bad (Should trigger)
```dart
// Requesting in a loop
Future<void> ensurePermission() async {
  while (true) {
    final status = await Permission.camera.request();  // ← trigger: request in loop
    if (status.isGranted) break;
    await Future.delayed(const Duration(seconds: 1));
  }
}

// Requesting again after denial without rationale
Future<void> requestLocation() async {
  final status = await Permission.location.request();
  if (status.isDenied) {
    // ← trigger: requesting again after denial with no explanation or settings redirect
    await Permission.location.request();
  }
}
```

### Good (Should NOT trigger)
```dart
// Single request with proper handling
Future<void> requestCamera() async {
  final status = await Permission.camera.request();
  if (status.isGranted) {
    _startCamera();
  } else if (status.isPermanentlyDenied) {
    // Guide user to settings
    await openAppSettings();
  } else {
    // status.isDenied — show rationale dialog, then give up or open settings
    _showPermissionRationaleDialog();
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `for` loop requesting permissions for different types | **Trigger** — loop over `Permission.values` is still a loop | Each permission should be handled individually |
| `request()` called once in `initState` | **Suppress** — single request | |
| `request()` inside a retry function with `openAppSettings()` in the retry path | **Complex** — may suppress | |
| Test files | **Suppress** | |
| `checkStatus()` not `request()` | **Suppress** — checking, not requesting | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Permission.camera.request()` inside `while (true)` loop → 1 lint
2. `Permission.location.request()` inside `for` loop → 1 lint
3. Two consecutive `request()` calls for the same permission → 1 lint

### Non-Violations
1. Single `Permission.camera.request()` → no lint
2. `Permission.camera.status` check (not request) → no lint
3. `openAppSettings()` called instead of re-requesting → no lint

## Quick Fix

No automated fix — the correct fix depends on UX design:
1. Show a rationale dialog before requesting (only if not permanently denied)
2. Direct to `openAppSettings()` if permanently denied
3. Never re-request in a loop

Suggest "Replace loop with single request + settings redirect" as a hint.

## Notes & Issues

1. **permission_handler-only**: Only fire if `ProjectContext.usesPackage('permission_handler')`.
2. **`shouldShowRequestRationale()`**: This `permission_handler` method (Android-only) indicates if the system would show a rationale UI before the dialog. Use it in the detection logic.
3. **iOS behavior**: On iOS, `isPermanentlyDenied` is returned after the FIRST denial. The fix (directing to Settings) is the same.
4. **The `rationale` parameter**: `permission_handler` has `Permission.X.onDeniedCallback` and `Permission.X.request()` — check if there's a built-in rationale mechanism.
5. **Real-world complexity**: Many apps have legitimate retry logic (e.g., "try again after user returns from settings"). The lint should only flag the loop case and the immediate re-request case, not smart retry patterns that include `openAppSettings()`.
