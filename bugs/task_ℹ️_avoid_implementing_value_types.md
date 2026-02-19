# Task: `avoid_implementing_value_types`

## Summary
- **Rule Name**: `avoid_implementing_value_types`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
In Dart, `implements` creates a structural contract: the implementing class must provide
the same API but shares no behavior with the implemented class. When a class defines
custom `operator ==` and `hashCode` (making it a "value type"), implementing it creates
a serious semantic inconsistency:

1. The implementing class has a different equality implementation than the original.
2. Code that receives an `implements`-relationship instance and calls `==` will get
   unexpected results compared to the original class's semantics.
3. This violates the Liskov Substitution Principle for equality: a `MockPoint implements
   Point` may not compare equal to a `Point` with the same coordinates, even though the
   contract promises the same interface.
4. Collections (sets, maps) built around the original type's equality semantics will
   behave incorrectly when mixed with implementing instances.

The correct approach for value types is to use `extends` (to inherit equality semantics)
or to explicitly override `==` and `hashCode` in the implementing class.

## Description (from ROADMAP)
Flag classes that `implements` a class which defines custom `operator ==` or `hashCode`,
because the implementing class has incompatible equality semantics by default.

## Trigger Conditions
1. A `ClassDeclaration` has an `ImplementsClause`.
2. At least one of the implemented types has a class declaration in the analyzed codebase
   (or a resolved element) that defines `operator ==` and/or `hashCode` (non-default
   implementations, i.e., not inherited from `Object`).
3. The implementing class does NOT itself override `operator ==` or `hashCode` (making
   the inconsistency concrete — it inherits `Object`'s identity equality while claiming
   to fulfill the value type's contract).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) { ... });
```

### Detection Logic
1. For each `ClassDeclaration` with a non-empty `implementsClause`:
2. For each type in `implementsClause.interfaces`:
   a. Resolve the type to its `ClassElement`.
   b. Look up `operator ==` and `hashCode` on the element, checking if they are
      declared directly on the class (not inherited from `Object`). Use
      `element.lookUpMethod('==', ...)` and check `enclosingElement != objectElement`.
3. If any implemented class defines custom equality:
   a. Check if the implementing class itself declares `operator ==`. If yes, it has
      made an explicit choice — do not flag (the inconsistency is at least visible).
   b. If the implementing class does NOT declare `operator ==`, report a violation
      on the `ImplementsClause` or the specific type name that has custom equality.
4. Skip `abstract` classes (they are defining an interface, not a concrete
   implementation — the value type contract inconsistency applies at the concrete level).
5. Skip classes annotated with `@visibleForTesting` (mocks are intentionally different).

## Code Examples

### Bad (triggers rule)
```dart
class Point {
  final int x, y;
  const Point(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is Point && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

// BAD: implements Point but inherits Object's identity equality
class MutablePoint implements Point {
  @override
  int x, y;
  MutablePoint(this.x, this.y);
}
```

```dart
class Money {
  final int cents;
  final String currency;
  const Money(this.cents, this.currency);

  @override
  bool operator ==(Object other) =>
      other is Money && cents == other.cents && currency == other.currency;

  @override
  int get hashCode => Object.hash(cents, currency);
}

// BAD: MockMoney will use identity equality, not value equality
class MockMoney implements Money {
  @override
  final int cents;
  @override
  final String currency;
  const MockMoney(this.cents, this.currency);
}
```

### Good (compliant)
```dart
// ok: extends inherits equality semantics
class Point3D extends Point {
  final int z;
  const Point3D(int x, int y, this.z) : super(x, y);

  @override
  bool operator ==(Object other) =>
      other is Point3D && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

// ok: implements but explicitly overrides ==
class MockPoint implements Point {
  @override
  int x, y;
  MockPoint(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is MockPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

// ok: the implemented interface does NOT define custom ==
abstract class Describable {
  String describe();
}

class Item implements Describable {
  final String name;
  const Item(this.name);
  @override
  String describe() => 'Item: $name';
}
```

## Edge Cases & False Positives
- **`@immutable` annotation**: Immutable value types are the most common case. The rule
  should fire for any class with custom `==`, not just `@immutable` ones.
- **Abstract implementing classes**: If the class is `abstract`, it may not have a
  concrete instantiation. Flag only concrete (non-abstract) implementing classes.
- **`mixin` implementations**: A `mixin` can appear in `implements` clauses; check if
  the mixin defines custom `==`. Mixins rarely do, but handle correctly.
- **Dart records**: Records have structural equality built-in and cannot be extended.
  If a class `implements` a record type, flag it (records have custom equality by
  definition in Dart 3+).
- **`Comparable` and standard interfaces**: `Comparable`, `Pattern`, etc. do not
  themselves define custom `==`. Skip interfaces from `dart:core` that don't define `==`.
- **`Equatable` base class**: A class that `extends Equatable` and is then implemented
  should be flagged. The rule detects custom `==` on the resolved element regardless of
  how it was achieved.
- **Classes with only `hashCode` override but not `==`**: Rare but valid — if `hashCode`
  is overridden without `==`, the class still has unusual semantics. Flag with a softer
  message.
- **`@visibleForTesting` mocks**: Suppress for classes annotated with
  `@visibleForTesting`. Mock objects in tests intentionally implement contracts.
- **Third-party library classes**: If the implemented class is from an external package
  and its source is not available, use element inspection (not AST walking) to check
  for overridden `==`.

## Unit Tests

### Should Trigger (violations)
```dart
class ValueId {
  final int id;
  const ValueId(this.id);
  @override bool operator ==(Object other) => other is ValueId && id == other.id;
  @override int get hashCode => id.hashCode;
}

// LINT: implements value type without overriding ==
class FakeId implements ValueId {
  @override final int id;
  FakeId(this.id);
}
```

### Should NOT Trigger (compliant)
```dart
// ok: overrides == explicitly
class FakeId2 implements ValueId {
  @override final int id;
  FakeId2(this.id);
  @override bool operator ==(Object other) => other is FakeId2 && id == other.id;
  @override int get hashCode => id.hashCode;
}

// ok: extends instead of implements
class SubId extends ValueId {
  SubId(int id) : super(id);
}

// ok: implemented interface has no custom ==
abstract class Printable { void print(); }
class Report implements Printable { @override void print() {} }
```

## Quick Fix
**Suggest using `extends` instead of `implements`, or add `operator ==` and `hashCode`.**

Offer two options:
1. "Change `implements ValueType` to `extends ValueType`" — simplest fix when inheritance
   is appropriate.
2. "Add `operator ==` and `hashCode` overrides" — when inheritance is not appropriate
   (e.g., the class also implements other interfaces or uses different fields).

The auto-fix for option 1 replaces `implements` with `extends` in the clause. This may
require removing the interface from `implements` and adding it to `extends` (the class
may already have an extends clause — in that case, offer only option 2).

## Notes & Issues
- Looking up overridden `operator ==` on a `ClassElement` requires checking
  `element.methods` and filtering for the method named `==`. Use
  `element.getMethod('==')` and check if `enclosingElement2` is not `Object`.
- The hashCode getter is looked up similarly via `element.getGetter('hashCode')`.
- This rule is closely related to the `Effective Dart` guidance on value types and
  equality. Reference the Dart documentation in the rule's problem message.
- Consider adding the OWASP mapping for M10 (Code Quality) if the project uses that
  classification.
