# Task: `avoid_collection_mutating_methods`

## Summary
- **Rule Name**: `avoid_collection_mutating_methods`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Widget/Flutter Rules

## Problem Statement

Flutter's `setState()` and state management solutions (Riverpod, Bloc, Provider) rely on detecting state changes. When you mutate a collection in-place (e.g., `list.add(item)`, `list.sort()`, `map.remove(key)`) and then call `setState()`, Flutter sees the same object reference and may not detect the change correctly in some edge cases. Additionally, mutating shared collections can cause subtle bugs in immutable-first architectures.

The immutable pattern (`[...list, newItem]`) is clearer, safer, and compatible with all state management solutions.

## Description (from ROADMAP)

> Avoid methods that mutate collections in place.

## Trigger Conditions

Detect calls to mutating collection methods inside `setState()` callbacks, Bloc event handlers, Riverpod notifiers, or Provider's `notifyListeners()` context:

**Mutating methods to detect:**
- `List`: `add()`, `addAll()`, `insert()`, `insertAll()`, `remove()`, `removeAt()`, `removeWhere()`, `clear()`, `sort()`, `shuffle()`, `setRange()`, `replaceRange()`, `fillRange()`
- `Map`: `remove()`, `clear()`, `addAll()`, `addEntries()`, `update()`, `updateAll()`, `putIfAbsent()`, `[]= operator`
- `Set`: `add()`, `addAll()`, `remove()`, `removeAll()`, `removeWhere()`, `clear()`

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addMethodInvocation((node) {
  if (!_isMutatingCollectionMethod(node)) return;
  if (!_isInsideStateContext(node)) return;
  reporter.atNode(node, code);
});
```

`_isMutatingCollectionMethod`: check receiver's static type is `List<T>`, `Map<K,V>`, or `Set<T>`, and method name is in the mutating set.
`_isInsideStateContext`: walk parents for `setState(...)`, BloC `emit(...)`, Riverpod `state = ...`.

## Code Examples

### Bad (Should trigger)
```dart
void _addItem(Item item) {
  setState(() {
    _items.add(item);  // ← trigger: mutating list in setState
  });
}

void _sortList() {
  setState(() {
    _items.sort();  // ← trigger: sort is mutating
  });
}
```

### Good (Should NOT trigger)
```dart
// Immutable pattern ✓
void _addItem(Item item) {
  setState(() {
    _items = [..._items, item];  // creates new list
  });
}

// Using List.from for sort ✓
void _sortList() {
  setState(() {
    _items = [..._items]..sort();  // new copy, then sort
  });
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Mutation outside `setState` | **Suppress** in Phase 1 — only flag inside setState | Broader detection in Phase 2 |
| `Map` mutation on private state map | **Trigger** — same concern | |
| `Set.add()` call on a local temporary collection | **Suppress** — local temps are fine | Check if the collection is a field |
| Mutation in test setup | **Suppress** | |
| `ChangeNotifier` field being mutated | **Trigger if followed by notifyListeners()** | |

## Unit Tests

### Violations
1. `_items.add(item)` inside `setState(...)` → 1 lint
2. `_map.remove(key)` inside `setState(...)` → 1 lint

### Non-Violations
1. `_items = [..._items, item]` inside `setState` → no lint
2. `localList.add(item)` outside `setState` → no lint (Phase 1)
3. Test file → no lint

## Quick Fix

Offer "Use spread operator to create a new collection":
```dart
// Before:
setState(() { _items.add(item); });
// After:
setState(() { _items = [..._items, item]; });
```

## Notes & Issues

1. **Context detection is key** — the `_isInsideStateContext` check is important. Mutating collections outside setState is often fine (e.g., building a list in initState).
2. **Performance**: Spread operator creates a new list on every mutation — for large lists, this has real cost. The rule should note this trade-off.
3. **Riverpod immutability**: Riverpod's `StateNotifier` and code-gen providers inherently discourage mutation. If the project uses Riverpod, suppress or lower priority.
