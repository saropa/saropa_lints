# Bug: `avoid_ignoring_return_values` false positives on Map mutation methods

## Summary

The `avoid_ignoring_return_values` rule (v1) incorrectly flags calls to
`Map.update()`, `Map.putIfAbsent()`, and `Map.updateAll()` when they are used
for their in-place mutation side effect. These are standard Dart Map APIs
where the return value is a convenience but not the primary purpose -- the
mutation of the map is the intended effect.

This produces **11 false positives** across 6 files in the project.

## Severity

**False positive** -- Every flagged instance involves a Map method called
exclusively for its side effect of mutating the map in-place. The return
value is secondary and intentionally unused. This is idiomatic Dart.

## Reproduction

### Example 1: `Map.update()` for frequency counting (most common pattern)

**File:** `lib/double/double_iterable_extensions.dart`, line 54

```dart
final HashMap<double, int> frequencyMap = HashMap<double, int>();
for (final double item in this) {
  // FLAGGED: avoid_ignoring_return_values
  frequencyMap.update(item, (int value) => value + 1, ifAbsent: () => 1);
}
```

`Map.update()` returns the new value associated with the key, but the purpose
here is to mutate `frequencyMap` in-place. The return value (the updated
count integer) is not needed -- the map itself is queried later via
`frequencyMap.entries`.

### Example 2: `Map.putIfAbsent()` for building index maps

**File:** `lib/list/unique_list_extensions.dart`, line 42

```dart
final Map<E, int> lastIndices = <E, int>{};
for (int i = length - 1; i >= 0; i--) {
  final E key = keyExtractor(this[i]);
  // FLAGGED: avoid_ignoring_return_values
  lastIndices.putIfAbsent(key, () => i);
}
```

`Map.putIfAbsent()` returns the value (either existing or newly inserted).
The map is later queried via `lastIndices.values.toList()`. The return value
at the call site is intentionally unused.

### Example 3: `Map.update()` in static utility methods

**File:** `lib/map/map_extensions.dart`, line 205

```dart
static void mapAddValue<K, V>(Map<K, List<V>> map, K key, V value) {
  if (value == null) return;
  // FLAGGED: avoid_ignoring_return_values
  map.update(key, (List<V> list) => [...list, value], ifAbsent: () => <V>[value]);
}
```

The method is `void`-returning, explicitly signaling that the purpose is
side-effect-based. The `Map.update()` return value is the new list, which is
not needed because the map now contains it.

## Full list of false positives

| # | File | Line | Method | Purpose |
|---|------|------|--------|---------|
| 1 | `double/double_iterable_extensions.dart` | 54 | `Map.update()` | Frequency counting |
| 2 | `double/double_iterable_extensions.dart` | 90 | `Map.update()` | Frequency counting |
| 3 | `int/int_iterable_extensions.dart` | 27 | `Map.update()` | Frequency counting |
| 4 | `int/int_iterable_extensions.dart` | 60 | `Map.update()` | Frequency counting |
| 5 | `iterable/iterable_extensions.dart` | 28 | `Map.update()` | Frequency counting |
| 6 | `iterable/iterable_extensions.dart` | 64 | `Map.update()` | Frequency counting |
| 7 | `enum/enum_iterable_extensions.dart` | 42 | `Map.update()` | Frequency counting |
| 8 | `list/unique_list_extensions.dart` | 42 | `Map.putIfAbsent()` | Index building |
| 9 | `map/map_extensions.dart` | 141 | `Map.removeKeys()` inner call | In-place mutation |
| 10 | `map/map_extensions.dart` | 205 | `Map.update()` | Add value to list |
| 11 | `map/map_extensions.dart` | 222 | `Map.update()` | Remove value from list |

## Root cause

The rule does not distinguish between:

1. **Pure functions** where ignoring the return value is a genuine bug
   (e.g., `String.toUpperCase()`, `List.where()`)
2. **Mutating methods** where the return value is a convenience but the
   primary purpose is the side effect on the receiver
   (e.g., `Map.update()`, `Map.putIfAbsent()`, `List.add()`)

Dart's `Map` API is designed so that mutation methods like `update()`,
`putIfAbsent()`, and `updateAll()` return the value for convenience chaining,
but the **primary usage pattern** is calling them for their mutation side
effect.

## Suggested fix

**Option A (recommended): Maintain a whitelist of known side-effect methods**

Add these Dart SDK methods to an internal exempt list:

```
Map.update()
Map.putIfAbsent()
Map.updateAll()
Map.removeWhere()
List.add()
List.remove()
List.sort()
Set.add()
Set.remove()
```

**Option B: Check if the receiver is a local mutable variable**

If the method is called on a local `final` or `var` Map/List/Set that was
recently declared, it's likely being used for mutation. Only flag when the
receiver is a parameter or field where ignoring the return value is more
suspicious.

**Option C: Look at the return type relative to the receiver**

`Map.update()` returns `V` (the value type) -- the same type that's already
stored in the map. This is a strong signal that the return value is
redundant with the mutation. Compare with `String.toUpperCase()` which
returns a new `String` -- there, ignoring the return value is genuinely a bug.

## Resolution

**Fixed in v5.0.3.** Added `update`, `putIfAbsent`, `updateAll`, and `addEntries` to the `_safeToIgnore` whitelist. These are standard Dart Map mutation methods where the return value is a convenience but the primary purpose is the in-place mutation.

## Environment

- saropa_lints version: latest (v1 of this rule)
- Dart SDK: 3.x
- Project: saropa_dart_utils
