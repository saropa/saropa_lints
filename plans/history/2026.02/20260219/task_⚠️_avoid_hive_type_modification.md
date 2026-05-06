# Task: `avoid_hive_type_modification`

## Summary
- **Rule Name**: `avoid_hive_type_modification`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.7 Hive Database Rules

## Problem Statement

Hive stores data using `TypeAdapter`s that serialize/deserialize fields by their index. If you modify the type of an existing field — even keeping the same field name — the stored binary data will be read with the new type adapter and likely corrupt or crash on read.

Example:
```dart
@HiveType(typeId: 1)
class UserSettings {
  @HiveField(0)
  String theme; // ← was String, stored as binary string

  @HiveField(1)
  int fontSize; // ← if you change this to double, old data breaks!
}
```

After changing `fontSize` from `int` to `double`, any device that has existing Hive data with the old type will fail to deserialize it at runtime.

This is particularly dangerous because:
1. The failure is **silent** during development (developer clears app data constantly)
2. The failure is **hard to reproduce** in QA (QA may not have old app data)
3. The failure **affects production users** on upgrade — a crash on app launch

## Description (from ROADMAP)

> Modifying Hive type fields breaks existing data. Detect field type changes.

## Trigger Conditions

This rule is fundamentally a **diff-based** check, not a single-file check. The trigger condition is:

A field annotated with `@HiveField(N)` has its Dart type changed between versions.

### Implementation Challenge

Static lint rules operate on the **current state** of the code. They cannot compare against a previous version. This makes this rule fundamentally different from most lint rules.

**Possible approaches:**
1. **Heuristic-only**: Detect patterns that *suggest* risk (field comments, TODOs near HiveField annotations)
2. **Convention check**: Detect if a new field reuses an old field index (the `@HiveField` index should never be reused after deletion)
3. **Git diff integration**: Not feasible in standard lint, but possible as a pre-commit hook script

### Phase 1 (Feasible): Detect Index Reuse

The most common mistake is deleting a field and reusing its index number:

```dart
// Version 1:
@HiveField(0) String name;
@HiveField(1) int age;  // deleted

// Version 2 (BUG: index 1 reused!):
@HiveField(0) String name;
@HiveField(1) double salary; // ← same index, different type = CORRUPTION
```

```dart
context.registry.addClassDeclaration((node) {
  if (!_isHiveType(node)) return;
  final fields = _getHiveFields(node);
  final indices = <int, FieldDeclaration>{};
  for (final field in fields) {
    final index = _getHiveFieldIndex(field);
    if (index != null && indices.containsKey(index)) {
      reporter.atNode(field, code); // duplicate index
    }
    indices[index] = field;
  }
});
```

### Phase 2 (Complex): Cross-Version Detection

Would require a separate tool or pre-commit hook that:
1. Reads git history for previous version of the file
2. Parses old and new TypeAdapter fields
3. Compares field types by index number
4. Flags any type change

## Code Examples

### Bad (Should trigger — Phase 1: duplicate index)
```dart
@HiveType(typeId: 1)
class UserData {
  @HiveField(0)
  String name = '';

  @HiveField(1)  // ← trigger: index 1 reused (was previously used by a deleted field)
  double salary = 0.0; // NOTE: developer documentation would show old int age field here

  // NEVER reuse old indices - mark them reserved:
  // @HiveField(1) — DELETED — was: int age (DO NOT REUSE index 1)
}
```

### Good (Should NOT trigger)
```dart
@HiveType(typeId: 1)
class UserData {
  @HiveField(0)
  String name = '';

  // Index 1 was retired — skipped intentionally
  // @HiveField(1) — RETIRED — was: int age

  @HiveField(2) // ← next available index
  double salary = 0.0;
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| New class with sequential indices | **Suppress** — no existing data | Only fire on already-published types |
| Index gaps in new code | **Suppress** — gaps are correct practice | |
| Same type, same index | **Suppress** | Safe: no change |
| `@HiveType(typeId: X)` where X is used by another class | **Separate rule** | TypeId collision is a different bug |
| Deleted field with reserved comment | **Suppress** if comment present | Consider comment detection |
| Generated code | **Suppress** | |

## Unit Tests

1. Class with two `@HiveField(1)` annotations → 1 lint (duplicate index)
2. Class with index 0, 2, 3 (gap at 1) → no lint (gap is intentional, not duplicate)
3. Class with no `@HiveField` → no lint
4. Non-Hive class → no lint (package not detected)

## Quick Fix

No automated quick fix — resolving this requires understanding the migration strategy:
- Option A: Keep old field as a migration shim, add new field with new index
- Option B: Write a migration script to convert old data
- Option C: Clear Hive box on version upgrade (lossy)

Suggest "Add a comment marking index N as retired" as a hint.

## Notes & Issues

1. **CORE LIMITATION**: This rule cannot truly detect type changes without comparing to a git history. Phase 1 (detecting duplicate/reused indices) is the best feasible static check.
2. **Hive-only**: Only fire if `ProjectContext.usesPackage('hive')`.
3. **Pre-commit alternative**: A Python/Dart script that compares `*.g.dart` files to previous git commit would be much more accurate. Consider implementing as a companion `scripts/check_hive_migrations.py` script instead.
4. **The real safeguard**: Hive's `typeAdapterRegistry.registerAdapter()` and bumping `typeId` is the migration path. This rule should encourage that pattern in documentation.
5. **HiveType typeId uniqueness** is a separate concern — a `typeId` collision between two classes means only one gets deserialized correctly. That could be a separate `avoid_hive_typeid_collision` rule.
