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
// ignore_for_file: non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type
// ignore_for_file: type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure
// Test fixture for: require_firebase_composite_index
// Source: lib\src\rules\packages\firebase_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: orderByChild + range filter needs .indexOn
// expect_lint: require_firebase_composite_index
void _bad1() async {
  final snapshot = await FirebaseDatabase.instance
      .ref('users')
      .orderByChild('age')
      .startAt(18)
      .endAt(65)
      .once();
}

// BAD: orderByChild + equalTo needs .indexOn
// expect_lint: require_firebase_composite_index
void _bad2() async {
  final snapshot = await FirebaseDatabase.instance
      .ref('users')
      .orderByChild('status')
      .equalTo('active')
      .once();
}

// BAD: orderByChild + startAfter needs .indexOn
// expect_lint: require_firebase_composite_index
void _bad3() async {
  final snapshot = await FirebaseDatabase.instance
      .ref('posts')
      .orderByChild('timestamp')
      .startAfter(1000)
      .get();
}

// GOOD: orderByChild without filter (simple sort)
void _good1() async {
  final snapshot =
      await FirebaseDatabase.instance.ref('users').orderByChild('name').once();
}

// GOOD: filter without orderByChild (no compound query)
void _good2() async {
  final snapshot =
      await FirebaseDatabase.instance.ref('users').limitToFirst(10).once();
}

// GOOD: simple ref query (no ordering or filtering)
void _good3() async {
  final snapshot = await FirebaseDatabase.instance.ref('users').once();
}

// GOOD: child path access (not a query)
void _good4() async {
  final snapshot =
      await FirebaseDatabase.instance.ref('users').child('user123').get();
}
