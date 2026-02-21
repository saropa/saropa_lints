# Task: `require_init_state_idempotent`

## Summary
- **Rule Name**: `require_init_state_idempotent`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.46 Hot Reload Compatibility Rules

## Problem Statement

`initState()` is called:
1. When the widget is **first inserted** into the widget tree
2. When the widget is **hot-reloaded** (during development) — in some cases

More importantly, `StatefulWidget` can be rebuilt and remounted when its parent rebuilds. If the parent widget re-creates the widget (instead of reusing it), `initState()` is called again on the new `State` instance.

If `initState()` is **not idempotent** — i.e., calling it twice has different effects than calling it once — then:
1. Hot reload may cause duplicate initialization
2. Widget remounting causes duplicate side effects (multiple listeners, multiple API calls, multiple timers)
3. Global state may be corrupted

Common non-idempotent patterns:
```dart
@override
void initState() {
  super.initState();
  GlobalEventBus.subscribe(_onEvent); // ← registers a new listener every call!
  // On second init, this widget is now listening twice!
  _timer = Timer.periodic(...);       // ← creates a new timer every call, old one leaked
}
```

## Description (from ROADMAP)

> initState may run multiple times. Detect non-idempotent initialization.

## Trigger Conditions

1. `initState()` that calls `addListener`, `subscribe`, `register` without a corresponding check for already-registered state
2. `initState()` that creates a `Timer` without canceling any existing timer first
3. `initState()` that calls static methods that accumulate state (e.g., adding to a static list)

**Phase 1 (Conservative)**: Flag `addListener` calls in `initState()` when the enclosing `dispose()` doesn't have a corresponding `removeListener`.

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  if (node.name.lexeme != 'initState') return;
  if (!_isStateMember(node)) return;

  // Check for addListener without removeListener in dispose
  final addListenerCalls = _findMethodCalls(node.body, 'addListener');
  if (addListenerCalls.isNotEmpty) {
    final disposeMethod = _findDisposeMethod(node.parent);
    final removeListenerCalls = _findMethodCalls(disposeMethod?.body, 'removeListener');
    if (removeListenerCalls.isEmpty) {
      for (final call in addListenerCalls) {
        reporter.atNode(call, code);
      }
    }
  }
});
```

## Code Examples

### Bad (Should trigger)
```dart
class _EventWidgetState extends State<EventWidget> {
  @override
  void initState() {
    super.initState();
    eventBus.addListener('auth', _onAuthChange);  // ← trigger: listener added, may not be removed
    _fetchData(); // ← trigger: API call on every init
  }

  @override
  void dispose() {
    // Missing: eventBus.removeListener('auth', _onAuthChange);
    super.dispose();
  }
}
```

### Good (Should NOT trigger)
```dart
class _EventWidgetState extends State<EventWidget> {
  late final StreamSubscription _sub; // ← store subscription for cancellation

  @override
  void initState() {
    super.initState();
    _sub = eventStream.listen(_onEvent); // ← stored for disposal
    if (!_initialized) { // ← guard for repeated calls
      _initialized = true;
      _fetchData();
    }
  }

  @override
  void dispose() {
    _sub.cancel(); // ← properly cleaned up
    super.dispose();
  }
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `addListener` with matching `removeListener` in `dispose` | **Suppress** — properly managed | |
| `StreamSubscription` stored and canceled in `dispose` | **Suppress** | |
| `_initialized` guard in `initState` | **Suppress** — developer is aware | |
| Simple `initState` with only variable initialization | **Suppress** | |
| `ChangeNotifier.addListener` vs stream listener | **Same treatment** | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `initState` with `addListener` and no matching `removeListener` in `dispose` → 1 lint
2. `initState` with `Timer.periodic` and no timer cancellation in `dispose` → 1 lint

### Non-Violations
1. `initState` that only initializes local fields → no lint
2. `addListener` in `initState` matched by `removeListener` in `dispose` → no lint
3. Stream subscription stored and canceled in `dispose` → no lint

## Quick Fix

Offer "Add matching `removeListener` in `dispose`":
```dart
// In dispose():
// Before
@override
void dispose() {
  super.dispose();
}

// After
@override
void dispose() {
  eventBus.removeListener('auth', _onAuthChange);
  super.dispose();
}
```

## Notes & Issues

1. **Flutter-only**: Only fire if `ProjectContext.isFlutterProject`.
2. **Hot reload context**: The rule title says "hot reload" but the real concern is remounting and multiple instantiation. Hot reload itself doesn't usually call `initState` again on existing instances.
3. **Cross-method analysis**: Checking that `dispose()` has a matching `removeListener` requires finding the `dispose()` method in the same class — cross-method within a single class. This is feasible.
4. **The `_initialized` flag pattern**: This is the idiomatic guard for one-time initialization in `initState`. Detecting it as a suppression is important to avoid false positives.
5. **`WidgetsBinding.instance.addObserver`**: A common pattern that needs matching `removeObserver` in `dispose`. Include in detection.
6. **Timer non-idempotency**: Creating a `Timer` in `initState` is only a problem if the old one isn't canceled. Store the timer in a field and cancel in `dispose`.
