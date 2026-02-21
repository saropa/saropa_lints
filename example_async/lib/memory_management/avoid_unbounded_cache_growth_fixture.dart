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
