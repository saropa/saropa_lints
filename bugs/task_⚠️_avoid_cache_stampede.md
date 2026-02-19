# Task: `avoid_cache_stampede`

## Summary
- **Rule Name**: `avoid_cache_stampede`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.39 Caching Strategy Rules

## Problem Statement

A **cache stampede** (also called thundering herd) occurs when a cache miss is detected by multiple concurrent callers simultaneously, each triggering a separate expensive computation or network request:

```dart
// BUG: No locking — 100 concurrent callers all miss cache simultaneously
Future<Data> getData(String key) async {
  final cached = _cache[key];
  if (cached != null) return cached;

  // 100 concurrent calls all reach here simultaneously when cache is empty!
  final data = await _expensiveFetch(key); // ← 100 concurrent fetches!
  _cache[key] = data;
  return data;
}
```

This causes:
1. **Performance degradation**: N identical requests hit the server simultaneously
2. **Cost explosion**: Each request may incur cost (API calls, compute)
3. **Server overload**: The stampede can overwhelm the backend
4. **Race conditions**: Multiple responses arriving concurrently may cause data corruption

The solution is a **cache lock** or **deduplication** pattern:
```dart
final Map<String, Future<Data>> _inFlight = {};

Future<Data> getData(String key) async {
  final cached = _cache[key];
  if (cached != null) return cached;

  // Use a lock: if a request is in-flight, wait for it
  return _inFlight[key] ??= _fetch(key).then((data) {
    _cache[key] = data;
    _inFlight.remove(key);
    return data;
  });
}
```

## Description (from ROADMAP)

> Prevent thundering herd on cache miss. Detect cache without locking.

## Trigger Conditions

1. A `Map` field used as a cache where the miss path calls an `async` function (returns `Future`)
2. The cache miss path does NOT use `??=` with a Future (deduplication pattern)
3. No `Mutex` or `package:synchronized` locking present

**Phase 1 (Conservative)**: Flag `Map` used as cache where the miss path has a `Future`-returning method call, and no in-flight tracking (`Map<String, Future<T>>`) is present.

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  // Look for: if (cache[key] == null) ... return await fetch()
  final cacheCheck = _findCacheMissPattern(node.body);
  if (cacheCheck == null) return;

  // Check if there's a deduplication mechanism
  if (_hasInFlightTracking(node.parent, cacheCheck.cacheField)) return;
  if (_hasSynchronizationLock(node.body)) return;

  reporter.atNode(cacheCheck.missPath, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
final Map<String, UserData> _cache = {};

Future<UserData> getUser(String id) async {
  if (_cache.containsKey(id)) return _cache[id]!;

  // ← trigger: concurrent calls will all reach here and call fetchUser multiple times
  final data = await _api.fetchUser(id);
  _cache[id] = data;
  return data;
}
```

### Good (Should NOT trigger)
```dart
// Option 1: In-flight deduplication
final Map<String, UserData> _cache = {};
final Map<String, Future<UserData>> _inFlight = {};

Future<UserData> getUser(String id) async {
  return _cache[id] ??
      (_inFlight[id] ??= _api.fetchUser(id).then((data) {
        _cache[id] = data;
        _inFlight.remove(id);
        return data;
      }));
}

// Option 2: package:synchronized
final _lock = Lock();

Future<UserData> getUser(String id) async {
  return _lock.synchronized(() async {
    if (_cache.containsKey(id)) return _cache[id]!;
    final data = await _api.fetchUser(id);
    _cache[id] = data;
    return data;
  });
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Single-threaded dart (no concurrency) | **Suppress** — Dart is single-threaded (but async interleaving is real) | |
| Cache with size limit but no dedup | **Trigger** — stampede still possible | |
| `compute()` or isolates | **Complex** — different concurrency model | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Map` cache miss calling `async` function without in-flight tracking → 1 lint

### Non-Violations
1. `Map<String, Future<T>>` in-flight tracking present → no lint
2. `Lock().synchronized(...)` wrapping cache → no lint
3. Synchronous (non-async) cache miss → no lint

## Quick Fix

Offer "Add in-flight deduplication":
```dart
// Before
Future<T> getValue(String key) async {
  if (_cache.containsKey(key)) return _cache[key]!;
  final data = await _fetch(key);
  _cache[key] = data;
  return data;
}

// After
final Map<String, Future<T>> _inFlight = {};

Future<T> getValue(String key) async {
  return _cache[key] ??
      (_inFlight[key] ??= _fetch(key).then((data) {
        _cache[key] = data;
        _inFlight.remove(key);
        return data;
      }));
}
```

## Notes & Issues

1. **DETECTION IS HARD**: The cache stampede pattern requires recognizing:
   - A `Map` used as a cache (field, not a local)
   - A cache miss check (`containsKey`, `null` check)
   - An async fill operation
   - Absence of deduplication/locking
   This is a multi-step pattern recognition that is beyond simple AST analysis.
2. **Dart is single-threaded but async**: Dart's event loop means concurrent `async` functions CAN reach the same cache miss code before any of them completes. This is real concurrency in the async sense.
3. **`package:synchronized`**: The `Lock` class from `package:synchronized` provides true async mutual exclusion. Detect its usage as a valid suppression.
4. **`??=` pattern**: The `_inFlight[key] ??= fetch()` pattern is the most idiomatic Dart deduplication approach. Detect this as a suppression.
5. **Consider INFO tier**: Cache stampedes are a performance issue, not a functional bug per se. INFO may be more appropriate, especially given the high implementation complexity and potential for false positives.
