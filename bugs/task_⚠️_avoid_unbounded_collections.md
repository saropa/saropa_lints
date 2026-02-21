# Task: `avoid_unbounded_collections`

## Summary
- **Rule Name**: `avoid_unbounded_collections`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.33 Memory Optimization Rules

## Problem Statement

Collections (`List`, `Map`, `Set`, `Queue`) that grow without a size limit will eventually exhaust available memory, causing `OutOfMemoryError` crashes. This is especially dangerous for:

1. **Event logs**: Lists that accumulate events without capping
2. **Caches**: Maps used as caches without eviction
3. **Error collectors**: Lists that accumulate all errors ever seen
4. **Undo history**: Lists without max depth

```dart
// BUG: Unbounded cache
final Map<String, Widget> _widgetCache = {};

void buildWidget(String key) {
  _widgetCache[key] = _createWidget(key); // ← grows forever, no eviction
}
```

```dart
// BUG: Unbounded event log
List<LogEvent> _eventLog = [];

void logEvent(LogEvent event) {
  _eventLog.add(event); // ← grows until OOM
}
```

## Description (from ROADMAP)

> Collections without size limits cause OOM. Detect growing collections without limits.

## Trigger Conditions

1. A mutable collection (`List`, `Map`, `Set`) field in a long-lived class that:
   - Is added to (`.add()`, `.addAll()`, `[key] = value`) in one or more methods
   - Has NO size check (`if (length >= MAX) return`) before adding
   - Has NO clear/prune/evict logic anywhere in the class
2. Named patterns that suggest unbounded growth: `log`, `history`, `cache`, `events`, `queue`, `buffer`

**Phase 1 (Conservative)**: Flag `List` fields in `State` or `ChangeNotifier` classes where `.add()` is called without a size guard.

## Implementation Approach

```dart
context.registry.addClassDeclaration((node) {
  if (!_isLongLivedClass(node)) return; // State, ChangeNotifier, Service

  final addCalls = _findAddCallsOnFields(node);
  for (final call in addCalls) {
    final field = _getTargetField(call);
    if (field != null && !_hasSizeGuard(call) && !_hasEvictionLogic(node, field)) {
      reporter.atNode(call, code);
    }
  }
});
```

`_isLongLivedClass`: check if class extends `State`, `ChangeNotifier`, or contains `static` before the field.
`_hasSizeGuard`: check if there's an `if (collection.length >= maxSize)` or similar before the `.add()` call.
`_hasEvictionLogic`: check if the class contains `removeAt`, `remove`, `clear`, `removeWhere` calls that could be eviction.

## Code Examples

### Bad (Should trigger)
```dart
class _TrackingState extends State<TrackingWidget> {
  final List<TrackingEvent> _events = []; // ← unbounded list

  void onEvent(TrackingEvent event) {
    _events.add(event); // ← trigger: adds to list without size check
    setState(() {});
  }
}
```

### Good (Should NOT trigger)
```dart
// With max size
class _TrackingState extends State<TrackingWidget> {
  static const _maxEvents = 1000;
  final List<TrackingEvent> _events = [];

  void onEvent(TrackingEvent event) {
    if (_events.length >= _maxEvents) {
      _events.removeAt(0); // ← evict oldest
    }
    _events.add(event); // ← bounded
    setState(() {});
  }
}

// Or use a fixed-size ring buffer
final List<LogEntry> _log = List.filled(100, LogEntry.empty, growable: false);
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| List that is always cleared after use | **Suppress** — `_list.clear()` in dispose or after use | |
| `StreamController` fed list (stream handles backpressure) | **Suppress** | |
| Test code | **Suppress** | |
| `List.add` inside a conditional that limits size | **Suppress** | |
| `List<Widget>` in builder method (not a field) | **Suppress** — local, not field | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `State` class with `List.add()` in a method, no size check → 1 lint
2. `ChangeNotifier` with unbounded `Map` cache → 1 lint

### Non-Violations
1. `List.add()` with preceding `if (list.length >= MAX) ...` → no lint
2. `List.add()` followed by `list.removeAt(0)` → no lint
3. Local variable list (not a field) → no lint

## Quick Fix

Offer "Add size limit with eviction":
```dart
// Before
void logEvent(Event event) {
  _eventLog.add(event);
}

// After
static const _maxLogSize = 500;

void logEvent(Event event) {
  if (_eventLog.length >= _maxLogSize) {
    _eventLog.removeAt(0); // FIFO eviction
  }
  _eventLog.add(event);
}
```

## Notes & Issues

1. **Essential tier is appropriate**: Unbounded collections are a real OOM crash risk on mobile.
2. **HIGH FALSE POSITIVE RISK**: Most `List.add()` calls in production code are bounded by the underlying data source (e.g., adding API results that have a pagination limit). The lint must be conservative.
3. **The `clear()` check**: If the class has a `dispose()` method that calls `_collection.clear()`, it's bounded by the widget's lifecycle — still a memory concern if the widget is long-lived, but not a true "unbounded" leak. Consider suppressing.
4. **`_growable` flag**: `List.filled(N, e, growable: false)` is truly bounded. Detect this as a suppression.
5. **Cache-specific detection**: A `Map` used as a cache is the most common problematic pattern. A specialized `avoid_unbounded_cache` rule might be more precise than a general collection rule.
6. **OOM on mobile**: Android and iOS have different memory limits (~256MB to ~2GB depending on device). Low-end devices are most affected. This rule is important for apps targeting emerging markets.
