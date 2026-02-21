# Task: `avoid_equals_and_hash_code_on_mutable_classes`

## Summary
- **Rule Name**: `avoid_equals_and_hash_code_on_mutable_classes`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Dart's `Set` and `Map` (and their subtypes) use `hashCode` to bucket objects and `==`
to confirm identity within a bucket. The contract requires that an object's `hashCode`
must not change while it is in a collection. When a class defines custom `operator ==`
and `hashCode` but has mutable (non-final) fields, mutating those fields after the
object is inserted into a set or map silently corrupts the collection invariants:

- The object is stored in the bucket for its original hash.
- After mutation, its new hash may map to a different bucket.
- The object becomes unfindable: `set.contains(obj)` returns `false` even though the
  object is in the set.
- The object is never removed: `set.remove(obj)` also fails.

This is a classic, hard-to-debug bug. The rule catches the structural precondition for
this bug: a class that defines equality and hashing but is mutable.

## Description (from ROADMAP)
Flag classes that define `operator ==` and/or `hashCode` but have at least one mutable
(non-final) instance field, as mutation after insertion into a collection breaks hash invariants.

## Trigger Conditions
1. A `ClassDeclaration` contains a method with name `==` (operator declaration) or a
   getter named `hashCode`.
2. The same class (excluding static fields) has at least one non-final, non-const
   instance field — either declared with `var` or with a bare type (no `final`/`const`).
3. The class is not abstract (abstract classes define contracts, not concrete behavior).
4. The class is not annotated with `@immutable` already (the `@immutable` annotation
   would make other lints fire for the mutable field — don't double-report).

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) { ... });
```

### Detection Logic
1. For each `ClassDeclaration`:
2. Check if the class defines `operator ==`: look for a `MethodDeclaration` with
   `isOperator == true` and `name.lexeme == '=='`.
3. Also check if the class defines `hashCode`: look for a `MethodDeclaration` or
   `FieldDeclaration` with name `hashCode` that is a getter or field.
4. If neither is found, skip.
5. Gather all `FieldDeclaration` nodes in the class body that are:
   - Not `static`
   - Not `final` (or `const`)
   - Instance fields (not inside a factory method)
6. If any such mutable field exists, report the `operator ==` or `hashCode` declaration
   (whichever is present), with the mutable field names listed in the message.
7. For inherited mutability: only scan fields declared directly in the class. Fields
   inherited from superclasses are not analyzed in this pass (conservative).

## Code Examples

### Bad (triggers rule)
```dart
class Item {
  String name;        // mutable
  int quantity;       // mutable

  Item(this.name, this.quantity);

  @override
  bool operator ==(Object other) =>
      other is Item && name == other.name && quantity == other.quantity;

  @override
  int get hashCode => Object.hash(name, quantity);
}

// Bug: after mutating, item is lost in the set
final s = {Item('apple', 3)};
s.first.quantity = 5;
print(s.contains(Item('apple', 5))); // false — broken!
```

```dart
class Account {
  String ownerId;         // mutable
  double balance = 0.0;  // mutable

  Account(this.ownerId);

  @override
  bool operator ==(Object other) =>
      other is Account && ownerId == other.ownerId;

  @override
  int get hashCode => ownerId.hashCode;
}
```

### Good (compliant)
```dart
// ok: all fields are final
class Item {
  final String name;
  final int quantity;

  const Item(this.name, this.quantity);

  @override
  bool operator ==(Object other) =>
      other is Item && name == other.name && quantity == other.quantity;

  @override
  int get hashCode => Object.hash(name, quantity);
}
```

```dart
// ok: no custom == or hashCode — uses identity equality
class MutableItem {
  String name;
  int quantity;
  MutableItem(this.name, this.quantity);
}
```

```dart
// ok: hashCode based only on final field (id), mutable fields excluded
class UserProfile {
  final String id;        // final — hashCode based on this
  String displayName;     // mutable — but not used in hashCode or ==

  UserProfile(this.id, this.displayName);

  @override
  bool operator ==(Object other) => other is UserProfile && id == other.id;

  @override
  int get hashCode => id.hashCode;
  // Note: this is still a design concern but technically safe for collections.
  // Rule should NOT flag when hashCode only uses final fields.
}
```

## Edge Cases & False Positives
- **Mutable fields not used in `==`/`hashCode`**: If the mutable field is not referenced
  inside `operator ==` or `hashCode`, the collection invariant is preserved (the hash
  won't change on mutation). The rule should check if mutable fields are referenced in
  the `==` and `hashCode` implementations. If no mutable field appears in either, do not
  flag. This requires analyzing the method bodies.
- **`late final` fields**: `late final` fields can only be assigned once (after which
  they are effectively final). They are safe. Do not flag `late final` fields.
- **`@immutable` annotation**: A class annotated with `@immutable` is expected to have
  all fields final — another lint will catch violations. Do not double-report here.
- **Setters for final backing fields**: A setter that wraps a `final` backing field is
  a mutable field by another name. However, the backing field itself is final, so the
  hash won't change. Skip classes where mutable access is through setters backed by
  private final fields.
- **Static fields**: Static fields don't affect instance equality. Ignore them.
- **Abstract classes**: Skip — they define contracts, not implementations.
- **Frozen/copyWith patterns**: Some patterns use mutable classes intentionally with
  copyWith semantics, never placing them in sets. This rule cannot detect usage patterns,
  so it flags conservatively.
- **Classes with `@protected` mutable fields**: Subclasses may re-seal them. Flag with
  a note rather than suppressing.

## Unit Tests

### Should Trigger (violations)
```dart
class Tag {
  String label;              // mutable
  Tag(this.label);
  @override bool operator ==(Object other) => other is Tag && label == other.label;
  @override int get hashCode => label.hashCode;
  // LINT: mutable field used in == and hashCode
}
```

### Should NOT Trigger (compliant)
```dart
// ok: all final
class Tag {
  final String label;
  const Tag(this.label);
  @override bool operator ==(Object other) => other is Tag && label == other.label;
  @override int get hashCode => label.hashCode;
}

// ok: mutable field not used in == or hashCode
class Record {
  final String id;
  String notes = '';   // mutable but excluded from == and hashCode
  Record(this.id);
  @override bool operator ==(Object other) => other is Record && id == other.id;
  @override int get hashCode => id.hashCode;
}

// ok: no custom == at all
class Widget {
  String title;
  Widget(this.title);
}
```

## Quick Fix
**Suggest making mutable fields `final` or removing the custom `==`/`hashCode`.**

Two options:
1. "Make field `name` final" — for each mutable field referenced in `==`/`hashCode`.
2. "Remove custom `operator ==` and `hashCode`" — falls back to identity equality.

Option 1 is the safe default when the intent is value semantics. Option 2 is appropriate
when the class needs to be mutable and equality semantics should be identity-based.

The auto-fix for option 1 adds `final` to each reported mutable field declaration.

## Notes & Issues
- Analyzing which fields are referenced inside `operator ==` and `hashCode` method
  bodies requires walking those method bodies and collecting `SimpleIdentifier` references.
  This is necessary to avoid false positives on the "mutable field not in equality"
  pattern.
- The analysis of method bodies for field references should use resolved elements
  (not just name strings) to handle renamed fields, shadowed names, etc.
- This rule is particularly valuable when combined with `avoid_implementing_value_types`
  (task 7) — together they cover the two most common equality-related design bugs.
- Consider adding to the rule's problem message a link to Effective Dart's section on
  value types and the `dart:collection` hash contract.
- The OWASP mapping M10 (Code Quality) applies here.
