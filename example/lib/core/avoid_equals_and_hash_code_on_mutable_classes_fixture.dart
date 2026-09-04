// ignore_for_file: unused_element

/// Fixtures for avoid_equals_and_hash_code_on_mutable_classes.
library;

// =============================================================================
// BAD: mutable fields with hand-written == / hashCode
// =============================================================================

class MutablePoint {
  MutablePoint(this.x, this.y);

  // expect_lint: avoid_equals_and_hash_code_on_mutable_classes
  int x;
  // expect_lint: avoid_equals_and_hash_code_on_mutable_classes
  int y;

  @override
  bool operator ==(Object other) =>
      other is MutablePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

class MutableUser {
  MutableUser({required this.name, required this.email});

  final String name;
  // expect_lint: avoid_equals_and_hash_code_on_mutable_classes
  String email; // mutable field used by equality below

  @override
  bool operator ==(Object other) =>
      other is MutableUser && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

// =============================================================================
// GOOD: all fields final
// =============================================================================

class ImmutablePoint {
  const ImmutablePoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is ImmutablePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

// =============================================================================
// GOOD near-miss: mutable field present but no hand-written == / hashCode
// =============================================================================

class PlainMutableCounter {
  PlainMutableCounter(this.count);

  int count; // mutable, but no == / hashCode override -> not flagged
}

// =============================================================================
// GOOD near-miss: Equatable already covers this case elsewhere
// =============================================================================

// Deliberately not importing package:equatable here (fixtures avoid adding
// external dependencies). The rule's Equatable check only inspects the
// extends/with clause name textually, so a locally-declared stand-in class
// named `Equatable` still exercises the skip path without a real dependency.
abstract class Equatable {
  List<Object?> get props;
}

class EquatablePoint extends Equatable {
  EquatablePoint(this.x, this.y);

  // Mutable, but covered by avoid_mutable_field_in_equatable instead of
  // this rule, so no expect_lint marker here.
  int x;
  int y;

  @override
  List<Object?> get props => <Object?>[x, y];

  // Hand-written == / hashCode so this class also matches this rule's
  // structural trigger — the Equatable extends-clause check must skip it.
  @override
  bool operator ==(Object other) =>
      other is EquatablePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
