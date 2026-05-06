# BUG: `avoid_unassigned_late_fields` - False positive for RenderObject parent data lifecycle fields

**Status: Fixed**

Created: 2026-04-29
Rule: `avoid_unassigned_late_fields`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~1359)
Severity: False positive

---

## Summary

The rule flags `late` fields in RenderObject parent data classes that are assigned during layout/paint lifecycle before use.

---

## Attribution Evidence

```bash
rg "'avoid_unassigned_late_fields'" d:/src/saropa_lints/lib/src/rules
# d:/src/saropa_lints/lib/src/rules/code_quality/code_quality_variables_rules.dart:1359
```

---

## Reproducer

```dart
class MultiSliverParentData extends SliverPhysicalParentData {
  late double mainAxisPosition; // OK (assigned during layout)
  late SliverGeometry geometry; // OK (assigned during layout)
  late SliverConstraints constraints; // OK (assigned during layout)
}
```

Frequency: Always

---

## Resolution

- Updated `avoid_unassigned_late_fields` to skip classes in the `ParentData`
  inheritance chain (including subclasses such as `SliverPhysicalParentData`).
- Added a non-triggering fixture case in
  `example/lib/code_quality/avoid_unassigned_late_fields_fixture.dart` to
  cover RenderObject parent data lifecycle initialization patterns.
