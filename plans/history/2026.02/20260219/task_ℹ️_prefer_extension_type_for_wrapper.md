# Task: `prefer_extension_type_for_wrapper`

## Summary
- **Rule Name**: `prefer_extension_type_for_wrapper`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
A common Dart pattern for type safety is the "newtype" or "wrapper" pattern: wrapping a primitive (like `int` or `String`) in a class to give it a distinct type, preventing accidental mixing of, say, a `UserId` integer with an `OrderId` integer. This is excellent practice for domain modeling.

However, the traditional class-based wrapper has a non-trivial runtime cost: every `UserId(42)` allocates a new object on the heap. For high-frequency code paths (e.g., collections of IDs, rendering loops), this allocation pressure can be measurable.

Dart 3.3 introduced **extension types**, which provide identical type safety with zero runtime overhead. An extension type compiles away entirely — `UserId(42)` is literally just `42` at runtime, with the type system enforcing the distinction at compile time only.

For wrapper classes that:
- Have exactly one field
- Have no real behavior beyond delegating to the wrapped type
- Have no inheritance (they cannot — extension types cannot be subclassed by non-extension types)

...conversion to an extension type is a straightforward performance and idiom improvement.

## Description (from ROADMAP)
A class that acts as a typed wrapper over a single field, has one constructor assigning that field, and has no significant behavior beyond what the wrapped type already provides is a candidate for conversion to a Dart 3.3 extension type. The rule flags such classes.

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. Exactly one `final` non-static field.
2. Exactly one constructor — generative, taking the single field as a formal parameter (`this.fieldName`).
3. No `extends` clause.
4. No `implements` clause.
5. No `with` clause.
6. Not abstract, sealed, base, interface, or final modifier.
7. All methods (if any) are either: `==`, `hashCode`, `toString`, or delegation methods that only call through to the wrapped field (`String get value => _value; int get length => _value.length;`).
8. The class has fewer than 4 methods total (classes with significant method count are not pure wrappers).
9. Dart SDK constraint is ≥ 3.3.0.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  if (_isWrapperClassCandidate(node)) {
    reporter.atNode(node.name, code);
  }
});
```

### Detection Logic
```dart
bool _isWrapperClassCandidate(ClassDeclaration node) {
  // No class modifiers
  if (node.abstractKeyword != null) return false;
  if (node.extendsClause != null) return false;
  if (node.implementsClause != null) return false;
  if (node.withClause != null) return false;

  // Exactly one final non-static field
  final fieldDecls = node.members.whereType<FieldDeclaration>().toList();
  if (fieldDecls.length != 1) return false;
  final fieldDecl = fieldDecls.first;
  if (!fieldDecl.fields.isFinal || fieldDecl.isStatic) return false;
  if (fieldDecl.fields.variables.length != 1) return false;

  // Exactly one generative constructor
  final constructors = node.members.whereType<ConstructorDeclaration>().toList();
  if (constructors.length != 1) return false;
  if (constructors.first.factoryKeyword != null) return false;

  // The constructor must take the field as a formal
  final ctor = constructors.first;
  final params = ctor.parameters.parameters;
  if (params.length != 1) return false;
  if (params.first is! DefaultFormalParameter &&
      params.first is! FieldFormalParameter) return false;

  // Methods must be delegation-only or standard overrides
  final methods = node.members.whereType<MethodDeclaration>().toList();
  if (methods.length > 4) return false;

  final nonBoilerplateMethods = methods.where((m) {
    const boilerplate = {'==', 'hashCode', 'toString'};
    return !boilerplate.contains(m.name.lexeme);
  }).toList();

  // Check delegation-only: methods that just call through to the field
  return nonBoilerplateMethods.every(_isDelegationMethod);
}

bool _isDelegationMethod(MethodDeclaration method) {
  // A delegation method has a body that is a single expression
  // referencing the wrapped field or its members.
  // Simplified: check if body is a single ExpressionFunctionBody
  // with a PrefixedIdentifier or PropertyAccess expression.
  final body = method.body;
  if (body is! ExpressionFunctionBody) return false;
  final expr = body.expression;
  // Allow: this.field.property or field.property
  return expr is PropertyAccess || expr is PrefixedIdentifier;
}
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: wrapper over int — allocates object every instantiation
class UserId {
  final int value;
  const UserId(this.value);
}

// LINT: wrapper over String with minor delegation
class Email {
  final String value;
  const Email(this.value);

  bool get isValid => value.contains('@');  // delegation/thin check
  int get length => value.length;           // pure delegation
}

// LINT: nominal typing over primitive
class Celsius {
  final double degrees;
  const Celsius(this.degrees);

  @override
  String toString() => '${degrees}°C';
}

// Usage creating allocation pressure:
final ids = List.generate(10000, (i) => UserId(i));  // 10k objects
```

### Good (compliant)
```dart
// Correct: zero-cost extension type
extension type UserId(int value) {}

// Extension type with delegation methods (also zero cost)
extension type Email(String value) {
  bool get isValid => value.contains('@');
  int get length => value.length;
}

// Extension type with toString override
extension type Celsius(double degrees) {
  @override
  String toString() => '${degrees}°C';
}

// Usage — zero heap allocation:
final ids = List.generate(10000, (i) => UserId(i));  // just ints at runtime

// Compliant: wrapper with validation logic — NOT a pure wrapper
class PositiveInt {
  final int value;

  PositiveInt(int v) : value = v {
    if (v <= 0) throw ArgumentError('Must be positive: $v');
  }

  // Validation in constructor — extension types cannot throw in their primary constructor
  // the same way. Keep as class.
}

// Compliant: wrapper with multiple fields — use record instead (different rule)
class UserRef {
  final int id;
  final String tenant;
  const UserRef(this.id, this.tenant);
}

// Compliant: wrapper that extends something
class CustomString extends Comparable<CustomString> {
  final String value;
  const CustomString(this.value);
  @override int compareTo(CustomString other) => value.compareTo(other.value);
}

// Compliant: wrapper with significant business logic
class Money {
  final int cents;
  const Money(this.cents);

  Money operator +(Money other) => Money(cents + other.cents);
  Money operator -(Money other) => Money(cents - other.cents);
  Money scale(double factor) => Money((cents * factor).round());
  String format(String currencyCode) => '$currencyCode ${cents / 100}';
}
```

## Edge Cases & False Positives
- **Validation in constructor**: Extension type primary constructors cannot throw exceptions or contain validation logic. Classes that validate in the constructor (`if (v <= 0) throw ...`) must remain as classes. Detect this: if the constructor has a body (not just formals), do not flag.
- **Classes used as `implements` targets**: If another class `implements UserId`, converting `UserId` to an extension type would break that relationship. The rule checks `implementsClause` on the candidate class, but cannot check if OTHER classes implement it. This is a cross-file concern — document in correction message.
- **Classes subclassed by others**: If `class SpecialUserId extends UserId` exists, `UserId` cannot be converted to an extension type. The rule cannot detect this cross-file. Document the limitation.
- **Dart version 3.3+**: Extension types were introduced in Dart 3.3. The rule must check the SDK lower bound in `pubspec.yaml`. Skip entirely if below `sdk: '>=3.3.0'`.
- **`const` constructors**: Extension types support `const`. The fix should preserve `const` where applicable.
- **`@JsonKey` and similar annotations**: Wrapper classes used with JSON serialization packages often have code generation annotations. Converting to extension type would require `fromJson`/`toJson` re-implementation. If the class has any annotations from known codegen packages, do not flag.
- **`Equatable` base class**: If the wrapper extends `Equatable`, it has an `extends` clause — already excluded by condition 3.
- **Generic wrappers**: `class Box<T> { final T value; const Box(this.value); }` — extension types can be generic: `extension type Box<T>(T value) {}`. Still flag.
- **Named constructors on wrapper classes**: `class Email { ... Email.fromString(String s) : value = s.toLowerCase(); }` — having a named constructor beyond the primary one means there is construction logic. Do NOT flag such classes; they are not trivially convertable.

## Unit Tests

### Should Trigger (violations)
```dart
// Classic newtype pattern — LINT
class OrderId {
  final String value;
  const OrderId(this.value);
}

// Simple typed wrapper — LINT
class Percentage {
  final double value;
  const Percentage(this.value);
}

// Delegation-only methods — still LINT
class PhoneNumber {
  final String digits;
  const PhoneNumber(this.digits);

  int get length => digits.length;
  bool get isEmpty => digits.isEmpty;
}
```

### Should NOT Trigger (compliant)
```dart
// Has validation in constructor — keep as class
class NaturalNumber {
  final int value;
  NaturalNumber(int v) : value = v {
    if (v < 0) throw RangeError.value(v, 'v', 'Must be non-negative');
  }
}

// Multiple fields — use record instead (different rule)
class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

// Significant methods — real behavior, not just delegation
class RichText {
  final String raw;
  const RichText(this.raw);

  String get plainText => raw.replaceAll(RegExp(r'<[^>]+>'), '');
  String toHtml() => '<p>$raw</p>';
  RichText operator +(RichText other) => RichText('$raw ${other.raw}');
}

// Named constructor — construction logic exists
class UpperCaseString {
  final String value;
  UpperCaseString(String s) : value = s.toUpperCase();
}
```

## Quick Fix
**"Convert to extension type"** — Replace the class declaration with:
```dart
extension type ClassName(FieldType fieldName) {
  // Keep non-boilerplate methods (== and hashCode are automatic in ext types)
}
```
Remove `==`, `hashCode`, and `toString` if they are trivial delegations (extension types inherit from the representation type). Keep any delegation methods as extension type members.

Priority: 70 (performance benefit makes this higher priority than pure style rules).

## Notes & Issues
- Extension types differ from classes in that they do not have structural subtyping — `UserId` and `int` are NOT the same type. Callers cannot pass a `UserId` where an `int` is expected unless the extension type has `implements int`. The fix should note this for callers who may rely on implicit assignment compatibility (which doesn't exist for classes either, but is worth clarifying).
- Extension types with `implements` clauses (e.g., `extension type UserId(int value) implements int`) expose the underlying type — document this option in the correction message.
- The rule name is clear and consistent with `prefer_record_over_tuple_class`. Together they cover the two main "data class to modern Dart" migrations.
- Dart 3.3 minimum is required. The saropa_lints package should document its minimum Dart SDK requirement, and this rule should only activate when that minimum is met.
