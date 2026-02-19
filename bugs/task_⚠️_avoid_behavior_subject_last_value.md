# Task: `avoid_behavior_subject_last_value`

## Summary
- **Rule Name**: `avoid_behavior_subject_last_value`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.5 Bloc/Cubit Advanced Rules

## Problem Statement

`BehaviorSubject` (from `rxdart`) replays the last emitted value to new subscribers. After `close()` is called, `value` still returns the last emitted value even though the subject is closed. Accessing `.value` or `.stream.value` on a closed `BehaviorSubject` can:
1. Return stale data that's been superseded
2. Cause logic errors if code assumes the value is "live"
3. Prevent garbage collection of the retained value

When you don't need the replay behavior, use `PublishSubject` instead — it never retains a value.

## Description (from ROADMAP)

> BehaviorSubject retains value after close. Use PublishSubject when appropriate.

## Trigger Conditions

1. `BehaviorSubject<T>` used where replay behavior is not needed
2. Accessing `.value` on a `BehaviorSubject` after `.close()` has been called
3. `BehaviorSubject` created for a stream that only needs publish (no need for late subscribers to get last value)

Phase 1: Detect `.value` access on a `BehaviorSubject` that has been closed in a `dispose()` method.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (node.methodName.name != 'value') return;
  final targetType = node.realTarget?.staticType?.toString() ?? '';
  if (!targetType.contains('BehaviorSubject')) return;
  // Check if the subject has been closed in the same method or dispose
  reporter.atNode(node, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
class MyBloc {
  final _subject = BehaviorSubject<int>();

  @override
  void dispose() {
    _subject.close();
    // ← if something reads _subject.value after close, that's stale
  }

  int getLastValue() {
    if (_subject.isClosed) {
      return _subject.value;  // ← trigger: accessing value on closed subject
    }
    return 0;
  }
}
```

### Good (Should NOT trigger)
```dart
// Using PublishSubject when replay not needed ✓
final _subject = PublishSubject<int>();

// Checking isClosed before accessing ✓
if (!_subject.isClosed) {
  final value = _subject.value;
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Project doesn't use `rxdart` | **Suppress** | `ProjectContext.usesPackage('rxdart')` |
| `BehaviorSubject` accessed before close | **Suppress** — valid use | Only flag after-close access |
| `seedValue` BehaviorSubject (intentional init value) | **Note** — seed values are a valid BehaviorSubject use case | |
| Test file | **Suppress** | |

## Unit Tests

1. `.value` access on `BehaviorSubject` after `close()` → 1 lint
2. `.value` access before `close()` → no lint
3. Project without rxdart → no lint

## Notes & Issues

1. **`isClosed` check suppression**: Code that checks `if (!subject.isClosed)` before accessing `.value` should be suppressed.
2. **Phase 1 is conservative** — only flag the clear after-close pattern. The broader "should you use PublishSubject" question is harder to answer statically.
