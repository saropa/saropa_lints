// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument
// ignore_for_file: undefined_named_parameter
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this
// ignore_for_file: expected_class_member
// ignore_for_file: body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type
// ignore_for_file: use_of_void_result
// ignore_for_file: missing_function_body
// ignore_for_file: extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments
// ignore_for_file: unused_label
// ignore_for_file: unused_element_parameter
// ignore_for_file: non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token
// ignore_for_file: duplicate_definition
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: extends_non_class
// ignore_for_file: no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable
// ignore_for_file: named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration
// ignore_for_file: await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause
// ignore_for_file: could_not_infer
// ignore_for_file: uri_does_not_exist
// ignore_for_file: const_method
// ignore_for_file: redirect_to_non_class
// ignore_for_file: unused_catch_clause
// ignore_for_file: type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member
// ignore_for_file: extraneous_modifier
// ignore_for_file: experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override
// ignore_for_file: not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable
// ignore_for_file: assignment_to_final
// ignore_for_file: equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element
// ignore_for_file: missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type
// ignore_for_file: instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter
// ignore_for_file: non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type
// ignore_for_file: type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for: avoid_large_list_copy
// Source: lib\src\rules\performance_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

final largeList = List.generate(1000, (i) => i);
final dynamicList = <dynamic>[1, 2, 3];

// BAD: Should trigger avoid_large_list_copy
// expect_lint: avoid_large_list_copy
void _bad794() {
  final copy = List.from(largeList); // No type args — gratuitous copy
}

// GOOD: Should NOT trigger avoid_large_list_copy
void _good794() {
  // Use Iterable operations lazily
  final filtered = largeList.where((e) => e > 0);
  // Or document the intentional copy
  final copy = List<int>.of(largeList); // Explicit copy
}

// GOOD: List<T>.from() with type args is a type-casting pattern
void _good794b() {
  final typed = List<int>.from(dynamicList); // Type cast, not gratuitous copy
}

// GOOD: .toList() in return statement — function contract requires List
List<int> _good794c() {
  return largeList.where((e) => e > 0).toList(); // Required by return type
}

// GOOD: .toList() assigned to variable — caller needs concrete List
void _good794d() {
  final list = largeList.where((e) => e > 0).toList(); // Variable assignment
  list.shuffle();
}

// GOOD: .toList() is a cascade target — ..sort() is a List-only mutator
// absent from Iterable, so a concrete List is structurally required.
void _good794e() {
  final sorted = largeList.map((e) => e * 2).toList()..sort();
}

// GOOD: .toList() in a ternary assigned to a typed List — the wrapper does
// not remove the requirement; the result is indexed afterward.
void _good794f(bool cond) {
  final List<int> picked = cond
      ? largeList.where((e) => e > 0).toList()
      : largeList.skip(1).toList();
  final first = picked[0];
}

// GOOD: take(N) caps the result at N elements, so take(...).toList() is never
// a large copy — not flagged even when the result is discarded.
void _good794g() {
  largeList.take(10).toList();
}

// BAD: bare .toList() on a lazy chain whose result is discarded — no concrete
// List is required, so the copy is gratuitous.
void _bad794b() {
  // expect_lint: avoid_large_list_copy
  largeList.where((e) => e > 0).toList();
}

final List<int>? nullableSource = null;

// GOOD: .toList() is a named argument (`children:`). The NamedExpression wraps
// the ArgumentList, where a concrete List is structurally required.
void _good794h() {
  Column(children: largeList.map((e) => Text('$e')).toList());
}

// GOOD: .toList() is the left operand of `??` with a fallback list. The binary
// expression's result flows to the typed List variable, so the copy is required.
void _good794i() {
  final List<int> selected =
      nullableSource?.where((e) => e > 0).toList() ?? <int>[];
}

// GOOD: a getter (`.nonEmpty`) is accessed on the .toList() result. The getter
// is defined on List, not Iterable, so the .toList() is required to compile.
void _good794j() {
  final hasItems = largeList.map((e) => e + 1).toList().nonEmpty;
}

// GOOD: .toList() is the value of a map literal entry (e.g. a toJson() map).
// jsonEncode rejects a lazy Iterable, so the value must be a concrete List.
Map<String, Object?> _good794k() {
  return <String, Object?>{
    'items': largeList.map((e) => '$e').toList(),
  };
}

// GOOD: .toList() is an element of a set literal — the element slot expects a
// concrete List, not a lazy Iterable.
void _good794l() {
  final set = <List<int>>{
    largeList.where((e) => e > 0).toList(),
  };
}

// GOOD: .toList() is an element of a list literal (a List<List<int>>).
void _good794m() {
  final nested = <List<int>>[
    largeList.map((e) => e * 2).toList(),
  ];
}

// GOOD: .toList() in a switch-expression arm inside a List<T> getter. The arm
// value flows to the ExpressionFunctionBody, which requires a List.
List<int> _good794n(int category) => switch (category) {
  0 => largeList.where((e) => e > 0).toList(),
  1 => largeList.map((e) => e * 2).toList(),
  _ => const <int>[],
};

// GOOD: switch expression in a `return` with List<T> return type.
List<int> _good794o(int category) {
  return switch (category) {
    0 => largeList.map((e) => e + 1).toList(),
    _ => const <int>[],
  };
}

// GOOD: .toList() at a List<T> position inside a returned record literal.
(List<int>, String) _good794p() {
  return (largeList.map((e) => e).toList(), 'ok');
}

// GOOD: .toList() yielded from a sync* generator with List<int> element type.
Iterable<List<int>> _good794q() sync* {
  yield largeList.map((e) => e * 3).toList();
}
