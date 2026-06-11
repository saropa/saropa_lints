# BUG: `require_cache_expiration` — fires on bounded LRU/LFU cache that needs no TTL

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-11
Rule: `require_cache_expiration`
File: `lib/src/rules/resources/memory_management_rules.dart` (class line ~704, code line 719, logic lines 732-757)
Severity: False positive
Rule version: v2 | Since: v4.1.8 | Updated: v4.13.0

---

## Summary

The rule fires on a capacity-bounded LRU/LFU cache that evicts on every
over-capacity insert. Memory is already capped by `capacity` + eviction, so the
rule's stated harm ("unreleased memory grows over time… out-of-memory crashes")
does not apply. A TTL-less but size-bounded cache is a standard, correct design
(e.g. Guava `CacheBuilder.maximumSize` without `expireAfter`); the rule should
not require expiration when the class already bounds itself by eviction.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_cache_expiration'" lib/src/rules/
# lib/src/rules/resources/memory_management_rules.dart:720:    'require_cache_expiration',
```

**Emitter registration:** `lib/src/rules/resources/memory_management_rules.dart:720`
**Rule class:** `RequireCacheExpirationRule` — registered in `lib/saropa_lints.dart:2485`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (custom_lint plugin)

---

## Reproducer

Minimal Dart code that triggers the bug. This is a trimmed form of
`LruLfuCacheUtils` from the `saropa_dart_utils` package.

```dart
class _CacheEntry<V> {
  _CacheEntry(this.value, this.recency);
  V value;
  int frequency = 1;
  int recency;
}

// LINT — but should NOT lint: this cache is bounded by [capacity] and evicts
// the lowest-scoring entry on every over-capacity put, so memory cannot grow
// without bound. It deliberately has no TTL; freshness is the caller's concern.
class LruLfuCacheUtils<K, V> {
  LruLfuCacheUtils(this.capacity);

  final int capacity;
  final Map<K, _CacheEntry<V>> _entries = <K, _CacheEntry<V>>{};
  int _tick = 0;

  void put(K key, V value) {
    if (capacity == 0) return;
    final existing = _entries[key];
    if (existing != null) {
      existing.value = value;
      existing.frequency++;
      existing.recency = ++_tick;
      return;
    }
    if (_entries.length >= capacity) _evict(); // bounded eviction
    _entries[key] = _CacheEntry<V>(value, ++_tick);
  }

  void _evict() {/* removes lowest frequency, then LRU tiebreak */}
}
```

<!-- cspell:ignore isvalid isstale -->

**Frequency:** Always — any class whose name contains `cache`/`memo`, whose
source contains the substring `map<`, and which lacks the keywords
`expire`/`ttl`/`duration`/`timestamp`/`isvalid`/`isstale`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the cache is bounded by `capacity` + eviction; absence of TTL is a deliberate, valid design choice |
| **Actual** | `[require_cache_expiration] Cache implementation lacks expiration logic…` reported on the whole class declaration |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (LruLfuCacheUtils)   ← reporter.atNode(node) reports here
       ├─ FieldDeclaration (_entries : Map<K, _CacheEntry<V>>)   ← matches "map<"
       └─ MethodDeclaration (put / _evict / get)                 ← eviction logic ignored
```

The rule registers `context.addClassDeclaration` and reasons purely over
`node.toSource().toLowerCase()`; it never inspects the eviction methods.

---

## Root Cause

`runWithReporter` (lines 732-757):

```dart
context.addClassDeclaration((ClassDeclaration node) {
  final String className = node.nameToken.lexeme.toLowerCase();
  if (!className.contains('cache') && !className.contains('memo')) return;

  final String classSource = node.toSource().toLowerCase();
  final bool hasExpiration =
      classSource.contains('expire') ||
      classSource.contains('ttl') ||
      classSource.contains('duration') ||
      classSource.contains('timestamp') ||
      classSource.contains('isvalid') ||
      classSource.contains('isstale');
  final bool hasMapCache = classSource.contains('map<');

  if (hasMapCache && !hasExpiration) reporter.atNode(node);
});
```

### Hypothesis A (primary): no bounded-eviction exclusion

The rule has **no exclusion for size-bounded caches**. Its own diagnostic
message justifies the rule with a memory/OOM argument ("Unreleased memory grows
over time… risking out-of-memory crashes"), but a cache that evicts at
`capacity` cannot grow without bound — the OOM premise is false for it.

The sibling rule `AvoidUnboundedCacheGrowthRule` (same file, line ~810) already
recognizes the bounded case: it detects size-limiting markers (`maxSize`,
`capacity`, `limit`, `evict`, `lru`) and does not fire when present.
`require_cache_expiration` should share that exclusion. The two rules overlap on
the memory concern; unbounded growth is the sibling's job, so this rule firing
on a bounded cache is redundant and wrong.

### Hypothesis B (secondary): brittle source-substring detection

Detection is a lowercased full-source substring scan, which is fragile in both
directions:
- `classSource.contains('map<')` matches `toMap()` return types, locals, and
  parameter types — not just storage fields.
- Any incidental `duration`/`timestamp` substring (e.g. an unrelated field)
  silently suppresses the rule (false negative).

This is a heuristic-quality issue separate from the bounded-cache FP, but the
same string-only approach is what misses the eviction signal.

---

## Suggested Fix

In `RequireCacheExpirationRule.runWithReporter`, add a bounded-eviction
exclusion mirroring `AvoidUnboundedCacheGrowthRule`. Before reporting, skip when
the class source shows it bounds itself:

```dart
// A bounded cache caps memory by eviction, so the OOM premise of this rule does
// not apply. Unbounded growth is AvoidUnboundedCacheGrowthRule's concern; here
// we only flag genuinely unbounded, TTL-less caches.
final bool isBounded =
    classSource.contains('evict') ||
    classSource.contains('capacity') ||
    classSource.contains('maxsize') ||
    classSource.contains('max_size') ||
    classSource.contains('lru') ||
    classSource.contains('lfu') ||
    RegExp(r'(?:^|[^a-z])limit(?:[^a-z]|$)').hasMatch(classSource);

if (hasMapCache && !hasExpiration && !isBounded) reporter.atNode(node);
```

Reuse the existing `_limitPattern` / size-marker logic from
`AvoidUnboundedCacheGrowthRule` rather than duplicating the literals — extract a
shared helper so the two rules cannot drift apart.

Optionally, narrow the diagnostic message to drop the memory/OOM language, since
freshness (staleness) — not memory — is this rule's actual concern once the
bounded case is excluded.

---

## Fixture Gap

The fixture for `require_cache_expiration` should include:

1. **Bounded LRU cache, no TTL** — expect NO lint (class with `capacity` +
   `_evict()`, Map storage, no expiration keyword).
2. **Bounded cache named `*Cache` using `maxSize`** — expect NO lint.
3. **Unbounded Map cache, no eviction, no TTL** — expect LINT (true positive
   preserved).
4. **Cache with `Duration ttl` field** — expect NO lint (existing pass case).
5. **Class with `toMap()` but no Map storage field** — expect NO lint (guards
   against the `map<` substring matching a return type).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: ^13.12.3 (resolved in consuming project `saropa_dart_utils`)
- Dart SDK version: bundled with Flutter (consuming project is a Flutter package)
- custom_lint version: transitive via saropa_lints
- Triggering project/file: `saropa_dart_utils` → `lib/collections/lru_lfu_cache_utils.dart` (class `LruLfuCacheUtils`)
- Note: rule tag `{v2}` matches between installed plugin and this source tree, so the FP is current (not a stale-version artifact).
