// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_unbounded_cache_growth` lint rule.

// NOTE: avoid_unbounded_cache_growth fires on cache/map mutations
// without maxSize limits — requires heuristic pattern matching.
//
// BAD:
// _cache[key] = value; // grows without bound
//
// GOOD:
// if (_cache.length >= maxSize) _cache.remove(_cache.keys.first);
// _cache[key] = value;

void main() {}

// BAD: Map cache with a mutation site and NO eviction. Should trigger.
abstract final class UnboundedNameCache {
  static final Map<String, int> _entries = <String, int>{};
  static int getOrCompute(String key) => _entries[key] ??= key.length;
}

// GOOD: pruned via removeWhere on every read — bounded by day rollover.
// `.remove(` does not match `.removeWhere(`, so this was wrongly flagged.
// Should NOT trigger.
abstract final class DailyAstronomicalCache {
  static final Map<String, int> _entries = <String, int>{};
  static int getOrCompute(String key, String today) {
    _pruneStaleDays(today);
    return _entries[key] ??= key.length;
  }

  static void _pruneStaleDays(String today) {
    _entries.removeWhere((String key, int _) => !key.startsWith('$today|'));
  }
}

// GOOD: cleared on rollover via .clear(). Should NOT trigger.
abstract final class ClearOnRolloverCache {
  static final Map<String, int> _entries = <String, int>{};
  static void reset() => _entries.clear();
  static int put(String k, int v) => _entries[k] = v;
}
