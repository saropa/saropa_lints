# BUG: `prefer_freezed_for_data_classes` — fires in a project that does not depend on `freezed`

**Status: Fixed** (2026-10-29: rule now requires freezed or freezed_annotation in the package pubspec)

Created: 2026-10-29
Rule: `prefer_freezed_for_data_classes`
File: `lib/src/rules/codegen/freezed_rules.dart` (rule class ~line 945, `runWithReporter` ~line 975)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

The rule tells the user to adopt `@freezed`, but never checks that the project depends on `freezed` or `build_runner`. In a project that does not use freezed, the message is not actionable, and it fires on every class with 3+ final fields and a manual `copyWith`.

---

## Attribution Evidence

```bash
grep -rn "'prefer_freezed_for_data_classes'" lib/src/rules/
# lib/src/rules/codegen/freezed_rules.dart:958:    'prefer_freezed_for_data_classes',
```

Diagnostic `source` / `owner`: `saropa_lints` / `saropaLintsLsp`. Observed on `saropa_lints` 17.0.1-beta.4.

---

## Diagnostics

```
lib/database/models/schema/user_data/connection_db_model.dart 6
lib/database/models/schema/user_data/coaching_session_db_model.dart 9
[prefer_freezed_for_data_classes] Data class with manual copyWith/equals. Consider using @freezed to eliminate ...
```

Project facts:

- `grep -n freezed pubspec.yaml` returns nothing: neither `freezed` nor `freezed_annotation` is a dependency.
- Both classes are Drift row models (`ConnectionDBModel`, `CoachingSessionDBModel`) with hand-written `copyWith`. The reported line is the class name token.

```dart
class ConnectionDBModel {
  ConnectionDBModel({
    required this.contactSaropaUUID,
    required this.contactSupabaseUUID,
    required this.emailAddress,
    required this.createdAt,
    this.sharedContactDetails,
    // ...
  });
  // final fields ...
  ConnectionDBModel copyWith({ String? contactSaropaUUID, /* ... */ }) { /* ?? this.x */ }
}
```

---

## Reproducer

Any project whose `pubspec.yaml` has no `freezed` / `freezed_annotation`:

```dart
class Point3 { // LINT — but should NOT lint: no freezed in this project
  const Point3(this.x, this.y, this.z);
  final int x;
  final int y;
  final int z;
  Point3 copyWith({int? x, int? y, int? z}) => Point3(x ?? this.x, y ?? this.y, z ?? this.z);
}
```

**Frequency:** Always, for every class with 3+ final fields and a `copyWith`, in every project without freezed.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when `freezed` / `freezed_annotation` is not a dependency of the analyzed package |
| **Actual** | `[prefer_freezed_for_data_classes]` on the class name |

---

## AST Context

```
CompilationUnit
  └─ ClassDeclaration (ConnectionDBModel)   ← reported at node.nameToken
      ├─ FieldDeclaration (final ...) x 3+
      └─ MethodDeclaration (copyWith)
```

---

## Root Cause

`runWithReporter` registers `addClassDeclaration` and decides only from the class itself:

```dart
context.addClassDeclaration((ClassDeclaration node) {
  // skips: @freezed / @Freezed / @immutable / @JsonSerializable, extends Equatable
  ...
  if (finalFieldCount >= 3 && (hasCopyWith || (hasEqualsOverride && hasHashCodeOverride))) {
    reporter.atToken(node.nameToken, code);
  }
});
```

There is no package-dependency gate. The rule also skips `@immutable` and `@JsonSerializable` classes, so a class that is already annotated is exempt, but a plain class in a project without freezed is not.

---

## Suggested Fix

Gate the rule on the analyzed package depending on `freezed_annotation` (the same project-context check the other package-specific rules use), or move the rule to a tier that is only enabled when the dependency is present.

---

## Fixture Gap

`example/lib/codegen/prefer_freezed_for_data_classes_fixture.dart` should include:

1. 3 final fields + manual `copyWith` in a package without `freezed_annotation` — expect NO lint
2. Same class in a package with `freezed_annotation` — expect LINT
3. Same class annotated `@freezed` — expect NO lint

---

## Environment

- saropa_lints version: `17.0.1-beta.4` (`pubspec.lock`)
- analyzer: `14.7.0`
- Dart SDK: 3.13.7
- Triggering project/files: `lib/database/models/schema/user_data/connection_db_model.dart:6`, `coaching_session_db_model.dart:9`
