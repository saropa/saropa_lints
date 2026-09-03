# PROPOSAL: Avoid Equals And Hash Code On Mutable Classes

**Status: Open**

Created: 2026-09-02

## Summary

Flags a class that overrides both `operator ==` and `hashCode` while also declaring one or more non-final instance fields.

## Existing Coverage

`AvoidMutableFieldInEquatableRule` (`avoid_mutable_field_in_equatable`, `lib/src/rules/packages/equatable_rules.dart`) covers the same defect but only for classes that extend `Equatable` or mix in `EquatableMixin`. This proposal is a genuine extension: it targets any class with a hand-written `operator ==`/`hashCode` pair, regardless of whether it uses the `equatable` package, which is the more common case in plain Dart/Flutter code.

## Motivation

`==` and `hashCode` are contractually required to stay in sync with the object's observable state for the lifetime the object spends in a hash-based collection (`HashSet`, `HashMap`, as a `Map` key, in a `Set`). If a field used by either method is mutable, changing it after insertion silently corrupts the collection: lookups fail, duplicates appear, and `remove()` stops working. These bugs are intermittent, hard to reproduce, and rarely caught by unit tests that don't mutate-then-query.

## Detection / Behavior

Triggers when a class declares both `operator ==` and `hashCode` (or `get hashCode`) and has at least one non-final, non-static instance field referenced by either method (or, conservatively, any non-final field on the class).

```dart
// BAD
class Point {
  Point(this.x, this.y);
  int x; // mutable
  int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

// GOOD
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
```

## Quick Fix

None — manual refactor required. Making fields `final` may require constructor changes or introducing a `copyWith` method, which is a design decision the tool should not make automatically.

## Alternatives Considered

A narrower version that only fires when the mutable field is provably read inside `==`/`hashCode` (via data-flow) would reduce false positives on classes with unrelated mutable fields, but requires flow analysis this package doesn't currently do elsewhere for this class of rule. Starting with "any non-final field on a class with `==`/`hashCode`" is consistent with the existing Equatable-specific rule's conservative approach.
