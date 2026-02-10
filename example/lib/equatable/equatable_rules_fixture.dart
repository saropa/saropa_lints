// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: unused_element, unused_field
// ignore_for_file: depend_on_referenced_packages, unnecessary_import
// ignore_for_file: unused_import, avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member, annotate_overrides
// ignore_for_file: duplicate_ignore, non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor, final_not_initialized
// ignore_for_file: super_in_invalid_context, concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds, missing_required_argument
// ignore_for_file: undefined_named_parameter, argument_type_not_assignable
// ignore_for_file: invalid_constructor_name, super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class, invalid_reference_to_this
// ignore_for_file: expected_class_member, body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field, unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type, use_of_void_result
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type
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

// === require_deep_equality_collections ===
// Warns when List/Set/Map in Equatable props are compared by reference.

// BAD: List in Equatable props without deep equality
class BadEquatableWithList extends Equatable {
  const BadEquatableWithList(this.items);
  // expect_lint: require_deep_equality_collections
  final List<String> items;

  @override
  List<Object?> get props => [items]; // Reference comparison!
}

// BAD: Map in Equatable props
class BadEquatableWithMap extends Equatable {
  const BadEquatableWithMap(this.data);
  // expect_lint: require_deep_equality_collections
  final Map<String, int> data;

  @override
  List<Object?> get props => [data];
}

// GOOD: Using DeepCollectionEquality wrapper
class GoodEquatableWithDeepEquality extends Equatable {
  const GoodEquatableWithDeepEquality(this.items);
  final List<String> items;

  @override
  List<Object?> get props => [DeepCollectionEquality().equals(items, items)];
}

class DeepCollectionEquality {
  bool equals(Object? a, Object? b) => true;
}

// === avoid_equatable_datetime ===
// Warns when DateTime is in Equatable props.

// BAD: DateTime in Equatable props
class BadEquatableWithDateTime extends Equatable {
  const BadEquatableWithDateTime(this.createdAt);
  // expect_lint: avoid_equatable_datetime
  final DateTime createdAt;

  @override
  List<Object?> get props => [createdAt]; // Flaky equality!
}

// GOOD: Using millisecondsSinceEpoch for stable comparison
class GoodEquatableWithEpoch extends Equatable {
  const GoodEquatableWithEpoch(this.createdAt);
  final DateTime createdAt;

  @override
  List<Object?> get props => [createdAt.millisecondsSinceEpoch];
}
