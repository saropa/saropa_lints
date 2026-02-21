# Task: `prefer_record_over_tuple_class`

## Summary
- **Rule Name**: `prefer_record_over_tuple_class`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Design Patterns

## Problem Statement
Before Dart 3.0 introduced records, developers who needed to return multiple values from a function or bundle related data without a full class had to create small "tuple" or "pair" data classes — classes with only `final` fields, no behavior, and often named things like `Coordinates`, `NameAndAge`, `KeyValuePair`, or `ParseResult`.

These boilerplate classes have several downsides:
1. **Boilerplate overhead**: Requires writing a class declaration, constructor, and possibly `toString`/`==`/`hashCode`.
2. **No structural equality by default**: Two `Coordinates(1.0, 2.0)` instances are not `==` without manual `==`/`hashCode` override.
3. **Namespace pollution**: Every tuple class adds a name to the library namespace.

Dart 3.0 records (`(int, String)`, `({double lat, double lng})`) provide:
- Structural equality by default
- Zero-boilerplate syntax
- Named or positional access
- First-class language support with type inference

This rule detects simple "tuple" classes that have migrated to records.

## Description (from ROADMAP)
A class that has only `final` fields, a single constructor that assigns those fields, no methods (other than possibly `toString`, `==`, or `hashCode`), and no inheritance is a candidate for replacement with a Dart 3 record type. The rule flags such classes and suggests a record equivalent.

## Trigger Conditions
A `ClassDeclaration` where ALL of the following hold:
1. All fields are `final` and non-static.
2. The class has exactly one constructor, and it is a generative constructor (no factory).
3. The constructor uses only field-initializing formals (`this.fieldName`) or assigns to all fields.
4. The class has no instance methods other than `toString`, `operator ==`, and `hashCode` (which are all replaceable by record structural equality).
5. No `extends` clause (other than implicit `Object`).
6. No `implements` clause.
7. No `with` clause.
8. The class has 2–5 fields (1-field wrappers are better as extension types; 6+ field classes likely have real identity concerns).
9. Dart SDK constraint is ≥ 3.0.0.

## Implementation Approach

### AST Visitor
```dart
context.registry.addClassDeclaration((node) {
  if (_isTupleClassCandidate(node)) {
    reporter.atNode(node.name, code);
  }
});
```

### Detection Logic
```dart
bool _isTupleClassCandidate(ClassDeclaration node) {
  // No inheritance
  if (node.extendsClause != null) return false;
  if (node.implementsClause != null) return false;
  if (node.withClause != null) return false;
  if (node.abstractKeyword != null) return false;
  if (node.sealedKeyword != null) return false;

  // All fields must be final and non-static
  final fields = node.members.whereType<FieldDeclaration>().toList();
  if (fields.isEmpty || fields.length > 5) return false;
  if (fields.any((f) => !f.fields.isFinal || f.isStatic)) return false;

  // Count fields total
  final totalFields = fields
      .expand((f) => f.fields.variables)
      .length;
  if (totalFields < 2 || totalFields > 5) return false;

  // Methods must be only toString/==/hashCode
  final allowedMethodNames = {'toString', '==', 'hashCode', 'copyWith'};
  final methods = node.members.whereType<MethodDeclaration>().toList();
  if (methods.any((m) => !allowedMethodNames.contains(m.name.lexeme))) {
    return false;
  }

  // Exactly one constructor — generative, positional or named formals
  final constructors = node.members.whereType<ConstructorDeclaration>().toList();
  if (constructors.length != 1) return false;
  if (constructors.first.factoryKeyword != null) return false;

  return true;
}
```

## Code Examples

### Bad (triggers rule)
```dart
// LINT: simple coordinate tuple — should be a record
class Coordinates {
  final double lat;
  final double lng;

  const Coordinates(this.lat, this.lng);
}

// LINT: key-value pair — pure data, no behavior
class MapEntry2<K, V> {
  final K key;
  final V value;

  const MapEntry2(this.key, this.value);
}

// LINT: simple result tuple with 3 fields
class SearchResult {
  final String query;
  final int count;
  final Duration elapsed;

  const SearchResult(this.query, this.count, this.elapsed);
}

// Usage that would trigger
Coordinates getLocation() => Coordinates(40.7128, -74.0060);

final loc = getLocation();
print('${loc.lat}, ${loc.lng}');
```

### Good (compliant)
```dart
// Correct: use a named record type alias
typedef Coordinates = ({double lat, double lng});

Coordinates getLocation() => (lat: 40.7128, lng: -74.0060);

final loc = getLocation();
print('${loc.lat}, ${loc.lng}');

// OR: inline record without typedef
({String query, int count, Duration elapsed}) search(String q) =>
    (query: q, count: 0, elapsed: Duration.zero);

// Compliant: class has behavior methods (not just toString/==/hashCode)
class Coordinates {
  final double lat;
  final double lng;
  const Coordinates(this.lat, this.lng);

  // Real behavior — not just a tuple
  double distanceTo(Coordinates other) => ...;
  Coordinates translate(double dLat, double dLng) =>
      Coordinates(lat + dLat, lng + dLng);
}

// Compliant: class implements an interface
class SearchResult implements Comparable<SearchResult> {
  final String query;
  final int count;
  const SearchResult(this.query, this.count);

  @override
  int compareTo(SearchResult other) => count.compareTo(other.count);
}

// Compliant: single field — better as extension type (different rule)
class UserId {
  final int value;
  const UserId(this.value);
}

// Compliant: too many fields — likely has real identity
class PersonRecord {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime birthDate;
  final String address;
  const PersonRecord(this.firstName, this.lastName, this.email,
      this.phone, this.birthDate, this.address);
}
```

## Edge Cases & False Positives
- **Classes used as map keys or in collections requiring identity**: Records have structural equality, which is the desired behavior. However, if the class is intentionally used with reference equality (very rare for data-only classes), conversion changes semantics. The rule cannot detect this intent — document in the correction message.
- **`@immutable` annotation**: Classes marked `@immutable` are good candidates for record conversion. The annotation is not a blocker.
- **`copyWith` methods**: A `copyWith` method is a common boilerplate addition to data classes. Records do not have `copyWith` natively. If the class has a `copyWith`, it may be in use at call sites — flag but note that records lack `copyWith`.
- **JSON serialization**: Classes with `fromJson`/`toJson` methods are NOT tuple candidates (they have real behavior). The detection already excludes classes with non-standard methods.
- **`const` constructors**: Records support `const` expressions (record literals can be const). This is not a blocker for conversion.
- **Named vs positional fields**: Records can be either positional `(int, String)` or named `({int x, String y})`. The suggestion should prefer named records for readability when fields have meaningful names.
- **Dart version**: Records require Dart 3.0+. Skip if SDK constraint is below `3.0.0`.
- **Classes in public API of packages**: Converting a class to a `typedef` record type can break external API consumers. Flag but include a breaking-change warning.
- **Generics**: `class Pair<A, B> { final A first; final B second; ... }` — records support generics implicitly through type inference. `typedef Pair<A, B> = (A, B);` is valid. Still flag.

## Unit Tests

### Should Trigger (violations)
```dart
// 2-field data class, no behavior — LINT
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}

// 3-field result class — LINT
class PageInfo {
  final int page;
  final int totalPages;
  final int totalItems;
  const PageInfo(this.page, this.totalPages, this.totalItems);
}
```

### Should NOT Trigger (compliant)
```dart
// Has real behavior — not a tuple
class Vector2D {
  final double x;
  final double y;
  const Vector2D(this.x, this.y);

  Vector2D operator +(Vector2D other) => Vector2D(x + other.x, y + other.y);
  double get magnitude => sqrt(x * x + y * y);
}

// Implements interface — cannot be trivially replaced with record
class TaggedValue implements Comparable<TaggedValue> {
  final String tag;
  final int value;
  const TaggedValue(this.tag, this.value);
  @override int compareTo(TaggedValue other) => value.compareTo(other.value);
}

// Single field — should be extension type instead (different rule)
class OrderId {
  final String value;
  const OrderId(this.value);
}
```

## Quick Fix
**"Replace with record type alias"** — Generate:
```dart
typedef ClassName = ({FieldType fieldName, ...});
```
And update the constructor call sites to use record literal syntax. This is a multi-file fix for the typedef + all instantiation sites. The fix for the declaration itself is straightforward; update call sites is best-effort (same file only).

Priority: 65.

## Notes & Issues
- The 2–5 field range is a heuristic. A team may prefer a stricter (2–3) or looser (2–7) range. Consider making it configurable via `analysis_options.yaml`.
- `copyWith` detection: if `copyWith` is present, the fix should note that the record equivalent requires a custom extension method for `copyWith` support.
- The rule name `prefer_record_over_tuple_class` is clear. Alternative name: `prefer_record_types` (shorter but less specific).
- This rule is closely related to `prefer_extension_type_for_wrapper` (single-field classes). Document the distinction: `prefer_record_over_tuple_class` targets 2-5 field classes; `prefer_extension_type_for_wrapper` targets single-field wrapper classes.
