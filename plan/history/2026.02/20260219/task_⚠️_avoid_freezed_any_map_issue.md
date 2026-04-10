# Task: `avoid_freezed_any_map_issue`

## Summary
- **Rule Name**: `avoid_freezed_any_map_issue`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §5.17 freezed/json_serializable Rules

## Problem Statement

When using `freezed` + `json_serializable`, you can configure `any_map: true` in `build.yaml` to allow `Map<String, dynamic>` in `fromJson`. However, there is a known issue where:

1. `any_map: true` set in `build.yaml` (or `pubspec.yaml` under `json_serializable`) is **not respected** in the generated `.freezed.dart` file
2. The generated code may use `Map<String, Object?>` or the type that was set in the `@freezed` annotation, ignoring the global build config
3. This causes type mismatches when the serialized data contains values that don't match the expected type

The workaround is to set `any_map: true` **directly on the `@JsonSerializable` annotation** on the Freezed class rather than relying on global config.

```dart
// BUG: global any_map in build.yaml may be ignored in .freezed.dart
@freezed
class User with _$User {
  const factory User({required String name}) = _User;
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

## Description (from ROADMAP)

> any_map in build.yaml not respected in .freezed.dart. Document workaround.

## Trigger Conditions

1. A `@freezed` class has `fromJson` factory constructor
2. The project has `build.yaml` or `pubspec.yaml` with `json_serializable: any_map: true`
3. But the `@freezed` class does NOT have `@JsonSerializable(anyMap: true)` explicit annotation

**Phase 1 (Awareness lint)**: Detect `@freezed` with `fromJson` and no explicit `@JsonSerializable(anyMap: true)`. This is a documentation/awareness lint more than a bug detector — always remind developers about this potential issue.

## Implementation Approach

```dart
context.registry.addClassDeclaration((node) {
  if (!_hasFreezedAnnotation(node)) return;
  if (!_hasFromJsonFactory(node)) return;
  if (_hasJsonSerializableAnyMap(node)) return; // already explicitly set
  reporter.atNode(node, code);
});
```

`_hasFreezedAnnotation`: check for `@freezed` annotation.
`_hasFromJsonFactory`: check for a factory constructor named `fromJson`.
`_hasJsonSerializableAnyMap`: check for `@JsonSerializable(anyMap: true)` annotation on the class.

**Alternative approach**: Check `build.yaml` content (requires YAML parsing, not available in standard lint).

## Code Examples

### Bad (Should trigger)
```dart
@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String name,
    Map<String, dynamic>? metadata,
  }) = _UserProfile;

  // ← trigger: fromJson present but no @JsonSerializable(anyMap: true)
  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
```

### Good (Should NOT trigger)
```dart
@Freezed()
@JsonSerializable(anyMap: true) // ← explicitly set
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String name,
    Map<String, dynamic>? metadata,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `@freezed` without `fromJson` | **Suppress** — no JSON serialization | |
| `@JsonSerializable(anyMap: true)` explicitly set | **Suppress** | |
| `@JsonSerializable()` without anyMap | **Trigger** — developer should consider adding it | |
| Project doesn't use `json_serializable` | **Suppress** | |
| Generated code | **Suppress** | |
| Test classes | **Suppress** | |

## Unit Tests

### Violations
1. `@freezed` class with `fromJson` and no `@JsonSerializable(anyMap: true)` → 1 lint

### Non-Violations
1. `@freezed` without `fromJson` → no lint
2. `@freezed` with `@JsonSerializable(anyMap: true)` → no lint

## Quick Fix

Offer "Add `@JsonSerializable(anyMap: true)`":
```dart
// Before
@freezed
class MyModel with _$MyModel { ... }

// After
@Freezed()
@JsonSerializable(anyMap: true)
class MyModel with _$MyModel { ... }
```

## Notes & Issues

1. **freezed-only**: Only fire if `ProjectContext.usesPackage('freezed')` or `ProjectContext.usesPackage('freezed_annotation')`.
2. **This is a documentation/awareness lint**: The bug only manifests in specific cases where the global `build.yaml` configuration is expected to apply but doesn't. Most developers won't encounter this until they hit a runtime type error.
3. **Severity question**: Should this be INFO (awareness) or WARNING (potential bug)? Given that it causes runtime crashes, WARNING is appropriate but the false positive rate may be high (many Freezed classes don't need `anyMap: true`).
4. **Workaround specifics**: The correct fix is to either:
   - Add `@JsonSerializable(anyMap: true)` on each class
   - OR rely on the `build.yaml` global setting and accept the risk (until the bug is fixed)
5. **Track bug status**: This is a known issue in the `freezed` package. If it's fixed in a newer version, this rule becomes obsolete. Check the freezed changelog.
6. **`@Freezed()` vs `@freezed`**: Both are valid but have different configurations. `@Freezed()` is the class annotation; `@freezed` is a convenience const. Both should be detected.
