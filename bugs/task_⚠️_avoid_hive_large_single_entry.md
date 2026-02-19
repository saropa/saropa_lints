# Task: `avoid_hive_large_single_entry`

## Summary
- **Rule Name**: `avoid_hive_large_single_entry`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.52 Hive Advanced Rules

## Problem Statement

Hive stores data as key-value pairs in a binary format. When a **single entry** contains very large data (Hive recommends < 1MB per entry), it degrades performance significantly:

1. **Read performance**: The entire value must be deserialized even for partial reads
2. **Write performance**: Updating a single field requires rewriting the entire entry
3. **Memory**: The entire object is held in memory during deserialization
4. **Box compaction**: Large entries make box files grow faster and require more frequent compaction

Problematic patterns:
```dart
// BUG: Storing a large list of items as a single Hive entry
final box = Hive.box('data');
box.put('all_users', users); // ← users might be a List<User> with 10,000 items!

// BUG: Storing binary content (images, documents) as a single entry
box.put('profile_image', imageBytes); // ← Uint8List could be MB
```

The correct approach: split large data across multiple keys or use chunking.

## Description (from ROADMAP)

> Entries >1MB degrade performance. Split large data across multiple keys or use chunking.

## Trigger Conditions

1. `box.put(key, value)` where value is:
   - `Uint8List` — raw bytes, potentially large
   - `List<T>` where T is a complex type (not primitive) — list of objects could be large
   - A class name suggesting large content: `Document`, `Image`, `Video`, `Bytes`, `Data`, `Cache`
2. `box.putAll(map)` where any value matches the above

**Phase 1 (Conservative)**: Flag `box.put(key, value)` where value is a `Uint8List` or `List<T>` for a complex type T.

## Implementation Approach

```dart
context.registry.addMethodInvocation((node) {
  if (!_isHivePut(node)) return; // box.put or box.putAll
  final valueArg = _getValueArgument(node);
  if (valueArg == null) return;

  final valueType = valueArg.staticType;
  if (valueType == null) return;

  if (_isLargeDataType(valueType)) {
    reporter.atNode(valueArg, code);
  }
});
```

`_isHivePut`: check if method name is `put` or `putAll` and receiver is a Hive `Box` type.
`_isLargeDataType`: check if type is `Uint8List`, `List<Uint8List>`, or `List<T>` where T is a non-primitive.

## Code Examples

### Bad (Should trigger)
```dart
final box = Hive.box('data');

// Storing raw bytes
box.put('avatar', imageBytes);  // ← trigger: Uint8List in single entry

// Storing large list as single entry
box.put('all_products', productList); // ← trigger: List<Product> could be huge
```

### Good (Should NOT trigger)
```dart
// Chunked storage
for (int i = 0; i < users.length; i++) {
  box.put('user_$i', users[i]); // ← each user is a separate entry
}

// Using key per item
for (final user in users) {
  box.put(user.id, user); // ← one entry per user
}

// Small primitive data is fine
box.put('last_sync', DateTime.now().toIso8601String()); // ← tiny
box.put('user_count', users.length); // ← tiny
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| `List<int>` or `List<String>` (primitive lists) | **Suppress** — small per element | |
| `List<bool>` | **Suppress** | |
| Small `Uint8List` (e.g., a hash) | **Trigger** — can't know size | False positive |
| Test files | **Suppress** | |
| Generated code | **Suppress** | |
| `box.put('settings', userSettings)` (single object) | **Suppress** — single object usually small | |

## Unit Tests

### Violations
1. `box.put('key', imageBytes)` where `imageBytes: Uint8List` → 1 lint
2. `box.put('key', productList)` where `productList: List<Product>` → 1 lint

### Non-Violations
1. `box.put('key', 'simple string')` → no lint
2. `box.put('key', 42)` → no lint
3. `box.put('user_id', user)` (single object) → no lint

## Quick Fix

No automated fix — chunking requires architectural changes. Suggest:
```dart
// Before
box.put('all_users', users);

// After: store each user separately
for (final user in users) {
  box.put('user_${user.id}', user);
}
```

## Notes & Issues

1. **hive-only**: Only fire if `ProjectContext.usesPackage('hive')` or `ProjectContext.usesPackage('hive_flutter')`.
2. **The 1MB threshold**: Can't measure statically. The rule uses type heuristics (Uint8List, complex List) as a proxy for "potentially large."
3. **HIGH FALSE POSITIVE**: `Uint8List` for a small icon (32 bytes), a fingerprint hash (32 bytes), or a small thumbnail is perfectly fine in Hive. The lint will false-positive on these.
4. **Consider making INFO tier**: Given the high false positive rate and inability to measure actual size, INFO may be more appropriate. ROADMAP says Professional/WARNING.
5. **ObjectBox / Isar alternative**: Both ObjectBox and Isar are better suited for large collections. For large data, consider migrating away from Hive entirely.
6. **`LazyBox`**: Hive's `LazyBox` reads values on demand (not all at once). For large boxes, `LazyBox` is already the performance optimization. Detect `Hive.box()` vs `Hive.lazyBox()` usage as a related concern.
