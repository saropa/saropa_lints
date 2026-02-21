# Task: `avoid_getx_rx_nested_obs`

## Summary
- **Rule Name**: `avoid_getx_rx_nested_obs`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.6 GetX Anti-Pattern Rules

## Problem Statement

In GetX, `.obs` makes a value reactive. Nesting reactive types creates complex dependency trees:

```dart
Rx<List<Rx<Item>>> items = <Rx<Item>>[].obs;  // ← deeply nested .obs
```

This causes:
1. Overly complex change detection — every inner item change triggers outer re-renders
2. Difficult debugging — which reactive layer triggered the update?
3. Memory overhead — each `Rx` wrapper adds overhead
4. Poor testability — nested reactive types are hard to mock

The correct approach: `RxList<Item>` instead of `Rx<List<Rx<Item>>>`.

## Description (from ROADMAP)

> Nested .obs creates complex reactive trees. Detect Rx<List<Rx<Type>>>.

## Trigger Conditions

1. `Rx<List<Rx<T>>>` — reactive list of reactive items
2. `Rx<Map<String, Rx<T>>>` — reactive map of reactive values
3. Any type `Rx<X>` where `X` itself contains `Rx<...>`

## Implementation Approach

### Package Detection
Only fire if `ProjectContext.usesPackage('get')`.

```dart
context.registry.addVariableDeclaration((node) {
  final type = node.declaredElement?.type;
  if (type == null) return;
  if (!_isRxType(type)) return;
  if (!_hasNestedRx(type)) return;
  reporter.atNode(node, code);
});
```

`_isRxType`: check if type is `Rx<T>` from GetX.
`_hasNestedRx`: check if the type parameter `T` itself contains `Rx<...>`.

## Code Examples

### Bad (Should trigger)
```dart
// Nested .obs
final items = <Rx<Item>>[].obs;  // ← trigger: RxList<Rx<Item>>
final RxMap<String, Rx<int>> counts = <String, Rx<int>>{}.obs;  // ← trigger
```

### Good (Should NOT trigger)
```dart
// Simple reactive ✓
final items = <Item>[].obs;  // RxList<Item>
final count = 0.obs;  // Rx<int>

// RxList instead of List<Rx> ✓
final RxList<Item> items = <Item>[].obs;
```

## Unit Tests

1. `RxList<Rx<Item>>` → 1 lint
2. `Rx<List<Rx<T>>>` → 1 lint
3. `RxList<Item>` (no nesting) → no lint
4. Project without GetX → no lint

## Notes & Issues

1. **GetX-only rule** — only relevant for GetX projects.
2. **`RxList`, `RxMap`, `RxSet`** are the correct alternatives to `List<Rx<T>>`.
