# PROPOSAL: Avoid Unbounded Collections

**Status: Open**

Created: 2026-09-02

## Summary

Flags a class field holding a `List`/`Map`/`Set` that is only ever appended to (via `add`/`addAll`/`[]=`/`insert`) with no corresponding removal, size cap, or eviction logic anywhere in the class.

## Existing Coverage

`AvoidUnboundedCacheGrowthRule` (`avoid_unbounded_cache_growth`, `lib/src/rules/resources/memory_management_rules.dart:1206`) covers a narrower case: it only fires on classes whose *name* contains `cache` or `memo` and matches a regex over method signatures (`void add/put/set/cache/store/save/insert(`). This proposal is a genuine, broader extension — it targets any class field with unbounded growth regardless of the class's naming convention (e.g. an event log, a listener list, a history buffer named without "cache" in it), which the name-gated existing rule misses entirely.

## Motivation

A collection field that only grows is a classic long-running-process memory leak: in a mobile app that stays open for hours or days (or a server process), each unbounded append moves the app closer to an out-of-memory crash. Because the effect is gradual, it rarely shows up in short-lived test runs or manual QA sessions, only in production telemetry or user reports of the app "getting slow over time."

## Detection / Behavior

Triggers on an instance field of type `List<T>`/`Set<T>`/`Map<K, V>` where the class contains at least one mutation call that only grows the collection (`add`, `addAll`, `[]=`, `insert`, `putIfAbsent`) and no call anywhere in the class that shrinks it (`remove`, `removeAt`, `removeWhere`, `clear`, `takeLast`/subscript-trimming) and no size-check guard (`if (list.length > n)`) near a mutation site.

```dart
// BAD
class AnalyticsBuffer {
  final List<Event> _events = [];

  void record(Event event) => _events.add(event); // never trimmed or cleared anywhere
}

// GOOD
class AnalyticsBuffer {
  final List<Event> _events = [];
  static const int _maxEvents = 500;

  void record(Event event) {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
  }
}
```

## Quick Fix

None — manual refactor required. The correct bound (max size, TTL, LRU) is an application-specific decision.

## Alternatives Considered

Reusing `avoid_unbounded_cache_growth`'s name-based heuristic was considered but rejected — gating on class name misses the common case of a plainly-named list/buffer field that grows without bound, which is the larger share of real-world leaks this proposal targets.
