# PROPOSAL: Missing copyWith for States

**Status: Open**

Created: 2026-09-02

**Closes gap:** `mad_lint` `missing_copy_with_for_states` (pub.dev). Implementing this rule closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

## Summary

Flags Bloc/Cubit state classes that have multiple fields but no `copyWith()` method, making partial state updates error-prone (callers must reconstruct the full object manually).

## Existing Coverage

Saropa has `avoid_incomplete_copy_with` (`class_constructor_rules.dart`, line ~211) which flags copyWith methods that miss fields. This proposal covers the complementary case: the copyWith method is entirely absent.

## Detection / Behavior

```dart
// Bad — no copyWith, callers must reconstruct manually
class DashboardState {
  final int count;
  final String name;
  final bool isLoading;
  DashboardState({required this.count, required this.name, required this.isLoading});
}

// Good
class DashboardState {
  // ... fields ...
  DashboardState copyWith({int? count, String? name, bool? isLoading}) =>
    DashboardState(count: count ?? this.count, name: name ?? this.name, isLoading: isLoading ?? this.isLoading);
}
```

## Quick Fix

Generate a `copyWith()` method covering all fields.

## Alternatives Considered

- Scope to Bloc/Cubit states only (classes extending `Equatable` or used with `emit()`) vs all data classes. Start with Bloc states to match source rule.
