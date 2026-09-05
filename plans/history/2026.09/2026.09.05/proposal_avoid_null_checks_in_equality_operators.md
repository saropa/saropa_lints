# PROPOSAL: Avoid Null Checks In Equality Operators

**Status: Implemented**

Created: 2026-09-02

## Summary

Flags a redundant `other == null` (or `identical(other, null)`) check inside an `operator ==` override, since the parameter type (`Object`, non-nullable) can never be `null` under sound null safety.

## Existing Coverage

`lib/src/rules/data/equality_rules.dart` has `AvoidEqualExpressionsRule`, `AvoidNegationsInEqualityChecksRule`, `AvoidSelfCompareRule`, and `AvoidUnnecessaryCompareToRule`, but none inspect the body of `operator ==` specifically for a dead null check on its non-nullable parameter. No duplicate.

## Motivation

Under Dart's null-safe type system, `operator ==(Object other)` takes a non-nullable `Object`, so `other == null` is always `false` and the branch is dead code. It's a common carry-over from pre-null-safety Dart or from copy-pasted Java/C# equality boilerplate. Leaving it in doesn't cause a bug, but it's misleading dead code that implies a nullability the type signature already rules out, and it adds noise to every generated or hand-written `==` in the codebase.

## Detection / Behavior

Triggers when the body of an `operator ==` override contains a comparison of its (non-nullable) parameter against `null`, whether as an early return (`if (other == null) return false;`) or inside a compound boolean expression.

```dart
// BAD
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) {
    if (other == null) return false; // dead: other is Object, non-nullable
    return other is Point && other.x == x && other.y == y;
  }
}

// GOOD
class Point {
  const Point(this.x, this.y);
  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;
}
```

## Quick Fix

Remove the dead `other == null` check (and the `if` block around it, replacing an early `return false;` guard with nothing, or simplifying `a && b` to `b` when the null check is ANDed in).

## Alternatives Considered

Extending the check to any parameter typed `Object`/`Object?` misused this way (not just inside `operator ==`) was considered but rejected as out of scope — the value here is specifically catching stale equality-operator boilerplate, and generalizing risks flagging legitimate defensive code in APIs that still accept `dynamic` callers from JS interop or reflection.
