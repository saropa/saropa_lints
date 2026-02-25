> **========================================================**
> **IMPLEMENTED -- v5.1.0**
> **========================================================**
>
> `AvoidSharedPrefsSyncRaceRule` in
> `lib/src/rules/packages/shared_preferences_rules.dart`.
> Recommended tier.
>
> **========================================================**

# Task: `avoid_shared_prefs_sync_race`

## Summary
- **Rule Name**: `avoid_shared_prefs_sync_race`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.8 SharedPreferences Security Rules

## Problem Statement

`SharedPreferences` writes are asynchronous (`setString`, `setInt`, etc. return `Future<bool>`). When multiple writes are performed concurrently without awaiting each one, the order of writes is non-deterministic:

```dart
// BUG: both writes fire concurrently — last one to finish wins
prefs.setString('user', 'Alice');    // ← not awaited
prefs.setString('user', 'Bob');      // ← not awaited
// Final value of 'user' is unpredictable
```

Additionally, on Android, SharedPreferences uses a background thread. Rapid concurrent writes to the same key from multiple isolates or from multiple `await` chains that run interleaved can cause data loss.

This causes:
1. Non-deterministic final state
2. Data loss when the second write overwrites the first
3. Hard-to-reproduce bugs (race depends on timing, device speed, OS scheduler)

## Description (from ROADMAP)

> Multiple writers can race. Detect concurrent SharedPreferences writes.

## Trigger Conditions

1. Multiple `prefs.setX(key, ...)` calls to the **same key** without `await` between them
2. Multiple un-awaited `setX` calls in the same method/block (same key or different keys)
3. `setX` called without `await` inside an async function (fire-and-forget SharedPreferences write)

### Priority Trigger (Most Impactful)
Detect `setX` without `await` in an `async` function:
```dart
void updateUser() async {
  prefs.setString('name', 'Alice');  // ← WARNING: write not awaited
  prefs.setString('age', '30');      // ← WARNING: write not awaited
  await doSomethingElse();
}
```

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isSharedPrefsSetMethod(node)) return;
  // Check if the call is awaited
  if (node.parent is AwaitExpression) return;
  // Check if we're inside an async function
  if (!_isInsideAsyncFunction(node)) return;
  reporter.atNode(node, code);
});
```

`_isSharedPrefsSetMethod`: check if the method name is `setString`, `setInt`, `setBool`, `setDouble`, `setStringList`, and the receiver type is `SharedPreferences` or `SharedPreferencesAsync`.

`_isInsideAsyncFunction`: walk the parent tree to find the nearest `FunctionBody` and check if it has `isAsynchronous == true`.

## Code Examples

### Bad (Should trigger)
```dart
Future<void> saveSettings() async {
  prefs.setString('theme', 'dark');   // ← trigger: not awaited
  prefs.setInt('version', 2);          // ← trigger: not awaited
  await prefs.setString('user', name); // ← OK: awaited
}

// Also bad: inside a Timer or callback without await chain
void onLogin(String name) async {
  prefs.setString('lastUser', name);   // ← trigger: not awaited
  Navigator.pushReplacementNamed(context, '/home');
}
```

### Good (Should NOT trigger)
```dart
Future<void> saveSettings() async {
  await prefs.setString('theme', 'dark');
  await prefs.setInt('version', 2);
  await prefs.setString('user', name);
}

// Also OK: using unawaited() explicitly as a conscious choice
unawaited(prefs.setString('analytics_event', event));
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `setX` in non-async function that returns Future | **Trigger** — caller may not await | |
| `unawaited(prefs.setX(...))` | **Suppress** — explicit fire-and-forget | Developer acknowledged the race |
| `prefs.setX(...)` in `initState` (sync context) | **Trigger** — can't await in `initState` | Suggest using `_init()` async helper |
| `prefs.setX(...)` in `.then()` callback | **Trigger** — .then callbacks are fire-and-forget unless returned | |
| `prefs.remove(key)` | **Trigger** — same race concern | Include `remove` and `clear` methods |
| `prefs.clear()` | **Trigger** | |
| `SharedPreferencesWithCache` | **Check**: newer API may have different semantics | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `async` function with `prefs.setString` not awaited → 1 lint
2. `async` function with multiple un-awaited `setX` calls → multiple lints
3. `prefs.remove()` not awaited in async function → 1 lint

### Non-Violations
1. `await prefs.setString(...)` → no lint
2. `unawaited(prefs.setString(...))` → no lint
3. Non-async context → no lint (can't await anyway; separate issue)

## Quick Fix

Offer "Add `await` before write":
```dart
// Before
prefs.setString('key', value);

// After
await prefs.setString('key', value);
```

Note: applying this fix may require making the enclosing function `async` if it isn't already.

## Notes & Issues

1. **SharedPreferences-only**: Only fire if `ProjectContext.usesPackage('shared_preferences')`.
2. **`SharedPreferencesAsync`** (introduced in newer versions) has a different API — check if it has the same race characteristics.
3. **`unawaited()` suppression**: The `dart:async` `unawaited()` function is the idiomatic way to mark intentional fire-and-forget. Detect this as a suppression.
4. **Sync context limitation**: In synchronous callbacks (e.g., `onPressed` without `async`), calling `prefs.setX` without await is unavoidable unless restructured. Limit the lint to `async` functions where `await` is available.
5. **The real fix**: Consider suggesting `SharedPreferencesWithCache` or wrapping writes in a serialized queue (e.g., `package:synchronized`).
