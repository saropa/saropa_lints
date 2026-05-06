# BUG: `avoid_unsafe_cast` - False positive on guarded RenderObject parentData casts

**Status: Fixed**

Created: 2026-04-29
Rule: `avoid_unsafe_cast`
File: `lib/src/rules/data/type_safety_rules.dart` (line ~63)
Severity: False positive

---

## Summary

The rule flagged `child.parentData as MultiSliverParentData` in render object workflows where `setupParentData` guarantees the type.

---

## Attribution Evidence

```bash
rg "'avoid_unsafe_cast'" d:/src/saropa_lints/lib/src/rules
# d:/src/saropa_lints/lib/src/rules/data/type_safety_rules.dart:63
```

---

## Reproducer

```dart
@override
void setupParentData(RenderObject child) {
  if (child.parentData is! MultiSliverParentData) {
    child.parentData = MultiSliverParentData();
  }
}

void update(RenderObject child) {
  final MultiSliverParentData data = child.parentData! as MultiSliverParentData; // OK (should not lint)
}
```

Frequency: Always

---

## Resolution

Implemented an AST-based safe-cast exemption in `avoid_unsafe_cast` for guarded parentData casts when:
- the cast target is a `*ParentData` type,
- the cast expression is `*.parentData` (optionally with `!`),
- and the enclosing class has `setupParentData(...)` that performs:
  - `child.parentData is! TargetParentData`, then
  - `child.parentData = TargetParentData()`.

Also added a fixture GOOD case in `example/lib/type_safety/avoid_unsafe_cast_fixture.dart` to document and guard this scenario.
