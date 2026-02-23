# RESOLVED — avoid_god_class: False Positive on Static-Constant Namespace Classes

**Fixed in**: v5.0.0-beta.16 (rule version v6)
**Resolution**: `static const` and `static final` fields are now excluded from the field count. These represent compile-time or lazy constants, not instance state indicating a god class.

---

# avoid_god_class — False Positive on Static-Constant Namespace Classes

## 1 violation | Severity: warning

### Rule Description
Flags classes that declare more than 15 fields or 20 methods, citing a violation of the Single Responsibility Principle. The intent is to catch "god classes" that accumulate unrelated responsibilities, become difficult to test, and act as merge-conflict magnets.

### Assessment
- **False Positive**: Yes. The rule counts all `FieldDeclaration` nodes equally, including `static const` fields in `abstract final` classes used purely as constant namespaces. These classes have zero behavior, zero instance state, and a single cohesive responsibility (grouping related constants). The god-class heuristic does not apply to them.
- **Should Exclude**: Yes. The rule should exclude (or at minimum discount) `static const` and `static final` fields when evaluating the threshold, particularly in classes that have no instance members and no methods.

### Affected Files

**`saropa_dart_utils/lib/datetime/date_constants.dart:11`** — `DateConstants`:
```dart
// ignore: avoid_god_class
abstract final class DateConstants {
  static const int _unixEpochYear = 1970;
  static const int minMonth = 1;
  static const int maxMonth = 12;
  // ... 17 fields total (16 static const + 1 static final)
}
```

The class has 17 fields (16 `static const` + 1 `static final`) and 0 methods, triggering the `> 15 fields` threshold.

### Root Cause

In `architecture_rules.dart`, the field counting did not inspect `member.isStatic` or `member.fields.isConst`. Every `FieldDeclaration` contributed equally to the count.

### Fix Applied

Static const and static final fields are excluded from the field count:
```dart
if (member is FieldDeclaration) {
  final bool isStaticConstant = member.isStatic &&
      (member.fields.isConst || member.fields.isFinal);
  if (!isStaticConstant) {
    fieldCount += member.fields.variables.length;
  }
}
```
