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
