# Task: `avoid_closure_capture_leaks`

## Summary
- **Rule Name**: `avoid_closure_capture_leaks`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.33 Memory Optimization Rules

## Problem Statement

Dart closures capture **references** to objects in their enclosing scope. If a closure is stored in a long-lived object (static variable, cached list, global callback registry), any objects captured by the closure will be retained for the lifetime of that closure, even if the original scope has long gone out of use.

Common leak patterns:
```dart
// BUG: Closure captures 'this' (the State object) and is stored globally
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // This closure captures 'this' (the entire State object)
    GlobalCallbackRegistry.register(() {
      setState(() { /* ... */ }); // ← 'this' captured!
    });
    // The State object won't be GC'd until GlobalCallbackRegistry is cleared
  }
  // If dispose() doesn't unregister, this is a memory leak!
}
```

Other patterns:
- Large objects captured by a `Timer` callback
- State captured by a `StreamSubscription` that isn't canceled
- Widgets captured by animation callbacks

## Description (from ROADMAP)

> Closures can capture and retain objects. Detect closures capturing large objects.

## Trigger Conditions

1. A closure (anonymous function) that references `this` or large local variables stored in a field that may outlive the current object
2. Closures registered with static/global registries (`addListener`, `register`, etc.) without corresponding unregistration in `dispose()`
3. `setState(() {...})` captured in a `Timer` without mounted check

**Phase 1 (Feasible)**: Flag `setState` inside a `Timer` callback without a `mounted` check.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'setState') return;
  if (!_isInsideTimerCallback(node)) return;
  if (_hasMountedCheck(node)) return;
  reporter.atNode(node, code);
});
```

`_isInsideTimerCallback`: check if the nearest enclosing function expression is passed to `Timer`, `Timer.periodic`, `Future.delayed`, etc.
`_hasMountedCheck`: check if there's a guard `if (mounted)` or `if (!mounted) return` before the `setState` call.

## Code Examples

### Bad (Should trigger)
```dart
// Timer captures 'this' + calls setState without mounted check
@override
void initState() {
  super.initState();
  Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() { // ← trigger: setState in Timer without mounted check
      _counter++;
    });
  });
  // If widget is disposed before Timer fires, this is a bug
}
```

### Good (Should NOT trigger)
```dart
@override
void initState() {
  super.initState();
  Timer.periodic(const Duration(seconds: 1), (_) {
    if (!mounted) return; // ← mounted check prevents crash/leak
    setState(() {
      _counter++;
    });
  });
}

// Better: store and cancel the timer
Timer? _timer;

@override
void initState() {
  super.initState();
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (!mounted) return;
    setState(() { _counter++; });
  });
}

@override
void dispose() {
  _timer?.cancel(); // ← properly cleaned up
  super.dispose();
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `Future.delayed` with `mounted` check | **Suppress** | |
| `setState` in `Stream.listen` callback | **Similar rule** — stream should be canceled in dispose | |
| `setState` in `AnimationController.addListener` | **Similar** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Timer.periodic` callback containing `setState` without `mounted` check → 1 lint
2. `Future.delayed` callback with `setState` without `mounted` check → 1 lint

### Non-Violations
1. `Timer.periodic` callback with `if (!mounted) return` before `setState` → no lint
2. `setState` directly in `build` or `initState` (not in callback) → no lint

## Quick Fix

Offer "Add `mounted` check":
```dart
// Before
Timer.periodic(const Duration(seconds: 1), (_) {
  setState(() { _counter++; });
});

// After
Timer.periodic(const Duration(seconds: 1), (_) {
  if (!mounted) return;
  setState(() { _counter++; });
});
```

## Notes & Issues

1. **Flutter-only**: Only fire if `ProjectContext.isFlutterProject`.
2. **Phase 1 is a subset**: The general "closure capture leak" problem is complex. Phase 1 focuses on the most common and easiest to detect case: `setState` in async callbacks without `mounted` check.
3. **`mounted` deprecation**: With the new `StatefulWidget` guidance, `mounted` checks are still valid in `State` classes. In widgets using Riverpod or other state management, the equivalent check is `ref.context.mounted`.
4. **True leak detection**: Full closure capture analysis requires data flow analysis (tracking where closures are stored, how long-lived the container is). This is beyond standard lint capabilities.
5. **Common related rule**: `avoid_async_callbacks_without_cancel` — closures in `StreamSubscription.listen`, `addListener`, etc. should have corresponding cancellation in `dispose()`. This is a broader version of the same concern.
