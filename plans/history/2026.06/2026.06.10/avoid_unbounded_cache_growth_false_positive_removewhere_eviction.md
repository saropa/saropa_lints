# BUG: `avoid_unbounded_cache_growth` — `removeWhere` eviction not recognized as a size limit

**Status: Open**

Created: 2026-06-10
Rule: `avoid_unbounded_cache_growth`
File: `lib/src/rules/resources/memory_management_rules.dart` (line ~876)
Severity: False positive
Rule version: v4

---

## Summary

The rule treats a cache as unbounded unless its class source contains one of a fixed set of substrings: `maxsize`, `max_size`, `capacity`, a word-boundary `limit`, `.remove(`, `evict`, or `lru`. A cache that evicts via `Map.removeWhere(...)` (the idiomatic Dart way to prune stale entries) is not matched — `.remove(` is not a substring of `.removeWhere(` — so a bounded, self-pruning cache is flagged.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_unbounded_cache_growth'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:843:    'avoid_unbounded_cache_growth',

# Negative — NOT in sibling repo
grep -rn "'avoid_unbounded_cache_growth'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:843`
**Rule class:** `AvoidUnboundedCacheGrowthRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
// LINT (false positive): this cache IS bounded. _pruneStaleDays() runs on every
// read and removeWhere()s every entry not from "today", so the map holds only
// the handful of keys touched in the current day. The rule misses the
// removeWhere eviction because it only scans for the substring ".remove(".
abstract final class DailyAstronomicalCache {
  static final Map<String, Data> _entries = <String, Data>{};

  static Data getOrCompute(String key, DateTime now) {
    _pruneStaleDays(now);
    return _entries[key] ??= compute(key);
  }

  static void _pruneStaleDays(DateTime now) {
    final String today = dayKey(now);
    _entries.removeWhere((String key, _) => !key.startsWith('$today|'));
  }
}
```

Real site: `D:\src\contacts\lib\utils\event\astronomical\astronomical_cache.dart:90`
(class `DailyAstronomicalCache`; eviction at line 128 via `_entries.removeWhere(...)`).

**Frequency:** Always, for any cache class that prunes with `removeWhere`/`removeRange`/`clear` rather than a literal `.remove(`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the cache is bounded by day-rollover `removeWhere` eviction. |
| **Actual** | `[avoid_unbounded_cache_growth] Map or collection used as a cache has no maximum size constraint...` reported at the class declaration. |

---

## AST Context

```
ClassDeclaration (DailyAstronomicalCache)   ← node reported here
  ├─ FieldDeclaration: static final Map<String, Data> _entries
  └─ MethodDeclaration (_pruneStaleDays)
      └─ ... MethodInvocation (_entries.removeWhere)   ← eviction the rule misses
```

---

## Root Cause

`memory_management_rules.dart:876-883`:

```dart
final bool hasSizeLimit =
    classSource.contains('maxsize') ||
    classSource.contains('max_size') ||
    classSource.contains('capacity') ||
    _hasLimitPattern(classSource) ||
    classSource.contains('.remove(') ||   // <-- does NOT match ".removeWhere("
    classSource.contains('evict') ||
    classSource.contains('lru');
```

`classSource` is the lowercased `toSource()`. The eviction call is `_entries.removewhere(...)`. The substring `.remove(` requires `remove` immediately followed by `(`; in `removewhere(` the `remove` is followed by `where(`, so the substring is absent. `removeWhere`, `removeRange`, and `clear()` are all standard `Map`/`List` pruning operations that the substring whitelist does not cover, so `hasSizeLimit` is false. The class has a `Map<String, Data>` field (non-enum key) and a mutation site (`_entries[key] ??=` / `[key] =`), so the rule reports.

---

## Suggested Fix

Broaden the eviction-detection substrings (or, better, AST-detect a `removeWhere`/`removeRange`/`clear` invocation on the cache field). Minimal substring fix in `memory_management_rules.dart:881`:

```dart
classSource.contains('.remove(') ||
classSource.contains('.removewhere(') ||
classSource.contains('.removerange(') ||
classSource.contains('.clear(') ||
```

A robust fix walks the class members for a `MethodInvocation` whose `methodName` is one of `{remove, removeWhere, removeRange, clear, evict}` with the cache field as target — that also avoids matching `.clear(` in unrelated contexts.

---

## Fixture Gap

`example*/lib/resources/avoid_unbounded_cache_growth_fixture.dart` should include:

1. Cache class with a `Map` field and a mutation method but **no** eviction — expect LINT.
2. Cache class that prunes with `field.removeWhere(...)` — expect **NO** lint.
3. Cache class that calls `field.clear()` on rollover — expect **NO** lint.
4. Cache class with `.remove(key)` — expect **NO** lint (already handled; regression guard).

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `D:\src\contacts\lib\utils\event\astronomical\astronomical_cache.dart:90`
