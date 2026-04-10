# Task: `avoid_void_async`

## Summary
- **Rule Name**: `avoid_void_async`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §2 Miscellaneous Rules

## Problem Statement

`async` functions that return `void` (`Future<void>`) have a subtle issue: exceptions thrown inside them are silently swallowed if the caller doesn't `await` the returned future. This is particularly dangerous for event handlers and fire-and-forget calls.

```dart
void onPressed() async {  // ← Future<void> returned but ignored
  await risky();  // exception here is lost!
}
```

The return type should be either:
1. `Future<void>` explicitly — then callers know they SHOULD await it
2. Changed to not be async — if it doesn't actually need to be async

**Note**: Dart's built-in `unawaited_futures` and `discarded_futures` lints partially address this. Check overlap before implementing.

## Description (from ROADMAP)

> Avoid async functions that return void.

## Trigger Conditions

1. A function/method declared with `void` return type AND `async` keyword
2. Not an override of a `void` interface method that requires `async`
3. Not a Flutter lifecycle method (`initState` cannot return a Future)

## Implementation Approach

```dart
context.registry.addFunctionDeclaration((node) {
  if (!_isVoidAsync(node.functionExpression)) return;
  if (_isEventCallback(node)) return;  // legitimate use case
  reporter.atNode(node.name, code);
});

context.registry.addMethodDeclaration((node) {
  if (!_isVoidAsync(node)) return;
  if (_isFlutterLifecycleMethod(node)) return;
  reporter.atNode(node.name, code);
});
```

`_isVoidAsync`: check return type annotation is `void` AND body has `async` keyword.

## Code Examples

### Bad (Should trigger)
```dart
// Exception from riskyOperation is silently dropped
void processData() async {  // ← trigger
  await riskyOperation();
  updateUI();
}
```

### Good (Should NOT trigger)
```dart
// Explicit Future<void> — callers know to await ✓
Future<void> processData() async {
  await riskyOperation();
}

// Properly handled event callback ✓
void onButtonPressed() {
  unawaited(processData());  // explicitly fire-and-forget
}

// Flutter lifecycle — must be void ✓
@override
void initState() {
  super.initState();
  // Cannot be async; use setState(() async {}) pattern instead
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Event handlers (button callbacks) | **Trigger** — but this is a very common pattern | High false positive risk |
| `@override` on `void` interface method | **Trigger** — but the interface forces the signature | Consider suppressing overrides |
| Flutter lifecycle methods | **Suppress** — `initState`, `dispose` etc. cannot return Future | Whitelist lifecycle methods |
| `void Function() callback` in widget param | **Trigger** — even callbacks should be `Future<void>` if async | |
| Already using `unawaited(...)` wrapper | **Suppress** | Check for explicit `unawaited` call |

## Unit Tests

1. `void processData() async { ... }` → 1 lint
2. `Future<void> processData() async { ... }` → no lint
3. `@override void dispose() { ... }` (no async) → no lint
4. `void initState()` (lifecycle) → no lint

## Quick Fix

Offer "Change return type to `Future<void>`":
```dart
// Before: void processData() async {
// After:  Future<void> processData() async {
```

## Notes & Issues

1. **Common pattern in Flutter**: `onPressed: () async { ... }` is everywhere. This rule will have VERY high false positive rate if it fires on all void async callbacks. Must have strong exemptions.
2. **Dart built-in**: `discarded_futures` lint covers the case where the caller doesn't await. This rule focuses on the declaration side.
3. **The real fix for event callbacks**: The truly safe pattern is `onPressed: () { processData(); }` (sync wrapper) combined with `Future<void> processData() async { ... }`. The rule should guide toward this.
