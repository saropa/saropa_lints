# Task: `require_expando_cleanup`

## Summary
- **Rule Name**: `require_expando_cleanup`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §1.3 Performance Rules — Memory Optimization
- **GitHub Issue**: [#14](https://github.com/saropa/saropa_lints/issues/14)
- **Priority**: 🐙 Has active GitHub issue

## Problem Statement

`Expando<V>` in Dart is a weak-key map — it associates data with objects without modifying those objects. The key is held weakly (GC'd when no other references exist), but the VALUE is held strongly by the Expando. If you repeatedly add entries to a long-lived `Expando` and the keys are not GC'd (because they live in a List or Map elsewhere), memory grows without bound.

Additionally, explicit `expando[key] = null` (Dart 2) or `expando[key] = null` (Dart 3) is the idiom to remove an entry. Developers often forget to do this when the association is no longer needed.

## Description (from ROADMAP)

> Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done.

## Trigger Conditions

### Phase 1 — Long-lived Expando without cleanup

1. `Expando<V>` declared as an instance field or static field (not a local variable)
2. The Expando has entries added (`expando[key] = value`) inside a method
3. There is no corresponding `expando[key] = null` in a `dispose()`, `close()`, or cleanup method of the same class

### Phase 2 — Expando used in collection loops
Detect `expando[item] = data` inside a loop that iterates a growing collection, with no corresponding removal.

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addClassDeclaration((node) {
  final expandoFields = _findExpandoFields(node);
  if (expandoFields.isEmpty) return;
  for (final field in expandoFields) {
    if (_hasSetToNull(node, field)) continue;
    reporter.atNode(field, code);
  }
});
```

`_findExpandoFields`: find fields of type `Expando<*>` in the class.
`_hasSetToNull`: look for `field[...] = null` anywhere in the class body (dispose, close, clear methods).

### Checking for Cleanup
Walk the class body for:
- `expando[key] = null` pattern (removal)
- `expando.keys` iteration with removal (though Expando doesn't have a `keys` API — note this)
- Class has a `dispose()` method that does NOT set the expando entry to null → warn on the dispose method

## Code Examples

### Bad (Should trigger)
```dart
class WidgetMetrics {
  // Static Expando with no cleanup strategy
  static final _metrics = Expando<MetricData>();

  void trackWidget(Widget widget) {
    _metrics[widget] = MetricData.capture(widget);  // ← adds entry
    // No corresponding cleanup when widget is removed
  }
  // No dispose() that calls _metrics[widget] = null
}

// Instance Expando — same issue
class Cache {
  final _cache = Expando<CacheEntry>();

  void store(Object key, CacheEntry entry) {
    _cache[key] = entry;  // ← adds entry
  }

  void dispose() {
    // ← trigger: Expando has entries but no cleanup here
  }
}
```

### Good (Should NOT trigger)
```dart
class Cache {
  final _cache = Expando<CacheEntry>();

  void store(Object key, CacheEntry entry) {
    _cache[key] = entry;
  }

  void evict(Object key) {
    _cache[key] = null;  // ← explicit cleanup ✓
  }
}

// Local Expando — GC handles it when it goes out of scope ✓
void processItems(List<Object> items) {
  final expando = Expando<ProcessingState>();
  for (final item in items) {
    expando[item] = ProcessingState.pending;
    process(item, expando);
  }
  // expando goes out of scope → GC'd
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| Local `Expando` variable (not a field) | **Suppress** — GC will collect it | Only flag fields |
| `Expando` field that is `null`-cleared in `dispose()` | **Suppress** | Check for `null` assignment |
| `static` Expando — lives forever | **Always trigger** with note that static Expandos accumulate | Highest priority case |
| Expando used in a test | **Suppress** | `ProjectContext.isTestFile` |
| Expando with explicit `WeakReference`-based keys | **Note** — Dart's Expando already has weak keys; double-weak is redundant | Advanced use case |
| Class with no `dispose()` method | **Trigger** — Expando exists with no cleanup path at all | Recommend adding a cleanup method |
| `expando[key] = null` inside a conditional (only sometimes cleared) | **Suppress** — developer is aware | Count any `= null` as cleanup intent |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. Instance field `Expando<T>` with `store(key, val)` method but no `evict` or `dispose` with null-set → 1 lint
2. `static final Expando<T>` with values added but no null-set anywhere → 1 lint

### Non-Violations
1. `Expando<T>` field with matching `expando[key] = null` in `dispose()` → no lint
2. Local `Expando` in a function → no lint
3. `Expando` field with `expando[key] = null` in any method → no lint
4. Test file → no lint

## Quick Fix

Offer "Add cleanup method" / "Add `expando[key] = null` to dispose":
```dart
// Add to dispose():
expando[key] = null;
```
This is a partial fix — the developer needs to identify WHICH key to clear.

## Notes & Issues

1. **`Expando` API limitation**: Dart's `Expando` has no `keys` getter, no `forEach`, no way to enumerate or clear all entries. This is by design (weak semantics), but it means you MUST track keys externally if you want to do bulk cleanup. The rule should mention this in its correction message.
2. **ROADMAP duplicate**: This rule appears TWICE in the table (once without 🐙, once with). Both rows should be deleted.
3. **GitHub Issue #14** — check the issue for additional real-world examples.
4. **Static Expandos** are the worst case — they live for the entire app lifetime and can accumulate unbounded entries if keys remain live in other data structures. These should be the primary Phase 1 target.
5. **Dart GC semantics**: The Expando key IS weakly held — if the key object has no other live references, the entry IS collected. The warning is mainly for cases where keys ARE kept alive elsewhere (in a List, Map, etc.) and the Expando values also accumulate.
