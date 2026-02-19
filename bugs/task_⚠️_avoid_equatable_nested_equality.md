# Task: `avoid_equatable_nested_equality`

## Summary
- **Rule Name**: `avoid_equatable_nested_equality`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.18 equatable Rules

## Notes on Source

**ISSUE**: The ROADMAP.md entry has malformed markdown — the rule name is missing a closing backtick:
```
| ⚠️ `avoid_equatable_nested_equality | Professional | WARNING | ...
```
Should be:
```
| ⚠️ `avoid_equatable_nested_equality` | Professional | WARNING | ...
```
This should be fixed in ROADMAP.md when this rule is implemented.

## Problem Statement

`Equatable` from `package:equatable` generates `==` and `hashCode` based on the `props` list. If a class extends `Equatable` but contains **mutable** nested objects in `props`, equality comparisons become unreliable:

1. The inner object's state can change after construction, breaking the `==` contract (equal now ≠ equal later)
2. This breaks collections (`Set`, `Map`) that depend on stable hash codes
3. Bloc/Cubit state classes using Equatable are particularly affected — if state contains a mutable list, state comparison fails and unnecessary rebuilds occur (or necessary rebuilds are skipped)

```dart
class CartState extends Equatable {
  final List<Item> items; // ← mutable List!

  const CartState({required this.items});

  @override
  List<Object?> get props => [items];
}

// BUG: Two states with the same list reference are equal
// But the list can be mutated without creating a new CartState
// causing UI to not rebuild when items change
```

## Description (from ROADMAP)

> Nested Equatables should also be immutable. Detect mutable nested objects.

## Trigger Conditions

1. A class extends `Equatable` (or `EquatableMixin`)
2. The `props` getter includes a field of a mutable type:
   - `List<T>` (not `const`, not `List.unmodifiable`)
   - `Map<K, V>` (not `const`)
   - `Set<T>` (not `const`)
   - A class that is NOT also `Equatable` and NOT `@immutable`
3. The field is not declared as `final` (additional risk: the field itself can be reassigned)

## Implementation Approach

```dart
context.registry.addMethodDeclaration((node) {
  if (node.name.lexeme != 'props') return;
  if (!_isEquatablePropsGetter(node)) return;

  // Get the list of returned values
  final propsValues = _getPropsValues(node);
  for (final prop in propsValues) {
    final type = prop.staticType;
    if (type == null) continue;
    if (_isMutableCollectionType(type)) {
      reporter.atNode(prop, code);
    }
  }
});
```

`_isMutableCollectionType`: check if type is `List`, `Map`, or `Set` (not `Iterable` — that's abstract and may be unmodifiable).
`_isEquatablePropsGetter`: check if the enclosing class extends `Equatable` or uses `EquatableMixin`.

## Code Examples

### Bad (Should trigger)
```dart
class CartState extends Equatable {
  final List<Item> items;   // ← mutable list
  final Map<String, int> counts; // ← mutable map

  const CartState({required this.items, required this.counts});

  @override
  List<Object?> get props => [items, counts];  // ← trigger: mutable types in props
}
```

### Good (Should NOT trigger)
```dart
// Option 1: Use built_collection (immutable by design)
class CartState extends Equatable {
  final BuiltList<Item> items;
  final BuiltMap<String, int> counts;

  const CartState({required this.items, required this.counts});

  @override
  List<Object?> get props => [items, counts]; // ← BuiltList/BuiltMap are immutable
}

// Option 2: Wrap in UnmodifiableListView
class CartState extends Equatable {
  final UnmodifiableListView<Item> items;

  CartState({required List<Item> items})
      : items = UnmodifiableListView(items);

  @override
  List<Object?> get props => [items];
}

// Option 3: Use const list
class SearchState extends Equatable {
  static const List<String> defaultFilters = ['all'];
  final List<String> filters;

  const SearchState({this.filters = defaultFilters});

  @override
  List<Object?> get props => [filters];
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `List.unmodifiable(...)` field | **Suppress** — unmodifiable at runtime | Type is still `List` though — hard to detect statically |
| `const []` literal in props | **Suppress** — const is immutable | |
| `UnmodifiableListView` | **Suppress** — known immutable wrapper | Add to whitelist |
| `BuiltList`, `BuiltMap`, `BuiltSet` | **Suppress** — built_collection is immutable | Add to whitelist |
| `IList` from fast_immutable_collections | **Suppress** | Add to whitelist |
| Nested `Equatable` object (also extends Equatable) | **Suppress** — handles its own equality | |
| `@immutable` class | **Suppress** — compiler-enforced immutable | |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |

## Unit Tests

### Violations
1. `Equatable` with `List<Item>` in `props` → 1 lint
2. `Equatable` with `Map<String, int>` in `props` → 1 lint

### Non-Violations
1. `Equatable` with `String`, `int`, `bool` in `props` → no lint
2. `Equatable` with `BuiltList` in `props` → no lint
3. `Equatable` with `UnmodifiableListView` in `props` → no lint
4. Non-Equatable class with List field → no lint

## Quick Fix

Offer "Wrap in `List.unmodifiable()`" or "Change to `UnmodifiableListView`":
```dart
// Before (in constructor)
CartState({required List<Item> items}) : items = items;

// After
CartState({required List<Item> items}) : items = List.unmodifiable(items);
```

## Notes & Issues

1. **equatable-only**: Only fire if `ProjectContext.usesPackage('equatable')`.
2. **FALSE POSITIVE RISK**: `List.unmodifiable()` returns a `List` type at the type level, so it can't be distinguished from a mutable `List` statically. The lint would fire even on `UnmodifiableListView` if the field type is declared as `List`. Need to check the actual field declaration type, not just the runtime value.
3. **Bloc-specific concern**: This pattern is most dangerous in Bloc/Cubit state classes. These classes extend `Equatable` and are compared to detect state changes. If state contains a mutable list, the same list reference being in two different state objects means they compare as equal even if the list contents differ.
4. **Collection comparison**: Even correctly implemented `Equatable` compares lists by reference (`==`), not by content. So even with a new `List` object, Equatable will see it as different from the previous one. The real issue is MUTATION of an existing list — that's what breaks equality.
5. **Recommended approach**: Use `package:collection`'s `listEquals` or `package:fast_immutable_collections` for truly immutable collections in state.
