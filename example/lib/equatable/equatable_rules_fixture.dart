// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, unused_field
// Test fixture for Equatable rules

// Mock Equatable for testing (since we may not have equatable package)
abstract class Equatable {
  const Equatable();
  List<Object?> get props;
}

mixin EquatableMixin {
  List<Object?> get props;
}

// Test cases

// === extend_equatable ===

// BAD: Class with operator == but doesn't extend Equatable
// expect_lint: extend_equatable
class PersonWithEquals {
  final String name;
  final int age;

  const PersonWithEquals(this.name, this.age);

  @override
  bool operator ==(Object other) =>
      other is PersonWithEquals && name == other.name && age == other.age;

  @override
  int get hashCode => Object.hash(name, age);
}

// GOOD: Class extends Equatable
class PersonWithEquatable extends Equatable {
  final String name;
  final int age;

  const PersonWithEquatable(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// GOOD: Class uses EquatableMixin
class PersonWithMixin with EquatableMixin {
  final String name;
  final int age;

  const PersonWithMixin(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// === list_all_equatable_fields ===

// BAD: Equatable class with missing field in props
class IncompleteEquatable extends Equatable {
  final String name;
  final int age;
  final String email; // This field is missing from props!

  const IncompleteEquatable(this.name, this.age, this.email);

  // expect_lint: list_all_equatable_fields
  @override
  List<Object?> get props => [name, age]; // email is missing!
}

// BAD: Equatable with mixin and missing fields
class IncompleteMixinEquatable with EquatableMixin {
  final String id;
  final String data;
  final int version; // Missing from props!

  const IncompleteMixinEquatable(this.id, this.data, this.version);

  // expect_lint: list_all_equatable_fields
  @override
  List<Object?> get props => [id, data]; // version is missing!
}

// GOOD: All fields in props
class CompleteEquatable extends Equatable {
  final String name;
  final int age;
  final String email;

  const CompleteEquatable(this.name, this.age, this.email);

  @override
  List<Object?> get props => [name, age, email];
}

// === prefer_equatable_mixin ===

// INFO: Class extends Equatable but could use mixin
// expect_lint: prefer_equatable_mixin
class SimpleEquatableClass extends Equatable {
  final String value;

  const SimpleEquatableClass(this.value);

  @override
  List<Object?> get props => [value];
}

// Already using mixin pattern - should still trigger because it's INFO
// expect_lint: prefer_equatable_mixin
class ClassWithMixins extends Equatable with SomeMixin {
  final String value;

  const ClassWithMixins(this.value);

  @override
  List<Object?> get props => [value];
}

mixin SomeMixin {}

// GOOD: Using EquatableMixin properly
class ProperMixinUsage with EquatableMixin {
  final String value;

  const ProperMixinUsage(this.value);

  @override
  List<Object?> get props => [value];
}

// === prefer_equatable_stringify ===

// BAD: Equatable without stringify override
// expect_lint: prefer_equatable_stringify
class PersonWithoutStringify extends Equatable {
  final String name;
  final int age;

  const PersonWithoutStringify(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// GOOD: Equatable with stringify override
// Note: Also triggers prefer_immutable_annotation since no @immutable
class PersonWithStringify extends Equatable {
  final String name;
  final int age;

  const PersonWithStringify(this.name, this.age);

  @override
  List<Object?> get props => [name, age];

  @override
  bool get stringify => true;
}

// === prefer_immutable_annotation ===

// Mock immutable annotation
const immutable = _Immutable();

class _Immutable {
  const _Immutable();
}

// BAD: Equatable without @immutable annotation
// expect_lint: prefer_immutable_annotation
class PersonWithoutImmutable extends Equatable {
  final String name;

  const PersonWithoutImmutable(this.name);

  @override
  List<Object?> get props => [name];

  @override
  bool get stringify => true;
}

// GOOD: Equatable with @immutable annotation
@immutable
class PersonWithImmutable extends Equatable {
  final String name;

  const PersonWithImmutable(this.name);

  @override
  List<Object?> get props => [name];

  @override
  bool get stringify => true;
}

// === require_freezed_explicit_json ===

// Mock Freezed annotations
const freezed = _Freezed();

class _Freezed {
  const _Freezed();
}

class Default {
  final Object? value;
  const Default(this.value);
}

// Mock for nested object type
class Address {
  final String street;
  const Address(this.street);
}

// BAD: Freezed class with nested object type
// expect_lint: require_freezed_explicit_json
@freezed
class UserWithNestedObject {
  factory UserWithNestedObject({
    required String name,
    required Address address, // Nested object needs explicit_to_json
  }) = _UserWithNestedObject;
}

class _UserWithNestedObject implements UserWithNestedObject {
  @override
  final String name;
  @override
  final Address address;
  _UserWithNestedObject({required this.name, required this.address});
}

// GOOD: Freezed class with only primitive types (no warning)
@freezed
class UserWithPrimitives {
  factory UserWithPrimitives({
    required String name,
    required int age,
    required bool isActive,
  }) = _UserWithPrimitives;
}

class _UserWithPrimitives implements UserWithPrimitives {
  @override
  final String name;
  @override
  final int age;
  @override
  final bool isActive;
  _UserWithPrimitives({
    required this.name,
    required this.age,
    required this.isActive,
  });
}

// === prefer_freezed_default_values ===

// BAD: Freezed class with nullable fields that could use @Default
// expect_lint: prefer_freezed_default_values
@freezed
class UserWithNullableFields {
  factory UserWithNullableFields({
    required String name,
    int? count, // expect_lint: prefer_freezed_default_values
    List<String>? items, // expect_lint: prefer_freezed_default_values
  }) = _UserWithNullableFields;
}

class _UserWithNullableFields implements UserWithNullableFields {
  @override
  final String name;
  @override
  final int? count;
  @override
  final List<String>? items;
  _UserWithNullableFields({required this.name, this.count, this.items});
}

// GOOD: Freezed class with @Default annotations
@freezed
class UserWithDefaultValues {
  factory UserWithDefaultValues({
    required String name,
    @Default(0) int count,
    @Default([]) List<String> items,
  }) = _UserWithDefaultValues;
}

class _UserWithDefaultValues implements UserWithDefaultValues {
  @override
  final String name;
  @override
  final int count;
  @override
  final List<String> items;
  _UserWithDefaultValues({
    required this.name,
    this.count = 0,
    this.items = const [],
  });
}

// === prefer_record_over_equatable ===

// BAD: Simple Equatable that could be a record
// expect_lint: prefer_record_over_equatable
class SimplePoint extends Equatable {
  final int x;
  final int y;

  const SimplePoint(this.x, this.y);

  @override
  List<Object?> get props => [x, y];
}

// GOOD: Equatable with methods (not suitable for record)
class PointWithMethods extends Equatable {
  final int x;
  final int y;

  const PointWithMethods(this.x, this.y);

  int get distance => x + y; // Custom method

  @override
  List<Object?> get props => [x, y];
}

// GOOD: Equatable with too many fields (not suitable for record)
class ComplexEntity extends Equatable {
  final String field1;
  final String field2;
  final String field3;
  final String field4;
  final String field5;
  final String field6; // More than 5 fields

  const ComplexEntity(
    this.field1,
    this.field2,
    this.field3,
    this.field4,
    this.field5,
    this.field6,
  );

  @override
  List<Object?> get props => [field1, field2, field3, field4, field5, field6];
}

// GOOD: Equatable with non-final field (not suitable for record)
// ignore: must_be_immutable
class MutableEquatable extends Equatable {
  String mutableField; // Non-final field

  MutableEquatable(this.mutableField);

  @override
  List<Object?> get props => [mutableField];
}

// === avoid_mutable_field_in_equatable ===

// BAD: Equatable class with non-final field
// ignore: must_be_immutable
class PersonWithMutableField extends Equatable {
  // expect_lint: avoid_mutable_field_in_equatable
  String name; // Non-final field - breaks equality contract!
  final int age;

  PersonWithMutableField(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// BAD: EquatableMixin with non-final field
// ignore: must_be_immutable
class MixinWithMutableField with EquatableMixin {
  // expect_lint: avoid_mutable_field_in_equatable
  int count; // Non-final field
  final String id;

  MixinWithMutableField(this.count, this.id);

  @override
  List<Object?> get props => [count, id];
}

// GOOD: Equatable with all final fields
class ImmutablePerson extends Equatable {
  final String name;
  final int age;

  const ImmutablePerson(this.name, this.age);

  @override
  List<Object?> get props => [name, age];
}

// GOOD: EquatableMixin with all final fields
class ImmutableMixinClass with EquatableMixin {
  final String id;
  final int version;

  const ImmutableMixinClass(this.id, this.version);

  @override
  List<Object?> get props => [id, version];
}
