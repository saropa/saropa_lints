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
// Test fixture for: avoid_permission_request_loop
// Source: lib\src\rules\permission_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// ============================================================================
// BAD: Should trigger avoid_permission_request_loop
// ============================================================================

// expect_lint: avoid_permission_request_loop
Future<void> _bad1() async {
  bool granted = false;
  while (!granted) {
    final status = await Permission.camera.request(); // Loop!
    granted = status.isGranted;
  }
}

// expect_lint: avoid_permission_request_loop
Future<void> _bad2() async {
  for (int i = 0; i < 3; i++) {
    final status = await Permission.location.request(); // Loop!
    if (status.isGranted) break;
  }
}

// expect_lint: avoid_permission_request_loop
Future<void> _bad3() async {
  bool granted = false;
  do {
    final status = await Permission.microphone.request(); // Loop!
    granted = status.isGranted;
  } while (!granted);
}

// ============================================================================
// GOOD: Should NOT trigger avoid_permission_request_loop
// ============================================================================

// OK: Request once and check result
Future<void> _good1() async {
  var status = await Permission.camera.request();
  if (status.isPermanentlyDenied) {
    await openAppSettings();
  }
}

// OK: Request once with rationale
Future<void> _good2() async {
  if (await Permission.location.isDenied) {
    // Show rationale first
    await showPermissionRationale();
    final status = await Permission.location.request();
    if (!status.isGranted) {
      handleDenied();
    }
  }
}

// OK: Check status without requesting in loop
Future<void> _good3() async {
  final status = await Permission.camera.status;
  if (status.isGranted) {
    openCamera();
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
  } else {
    final newStatus = await Permission.camera.request();
    if (newStatus.isGranted) {
      openCamera();
    }
  }
}

// ============================================================================
// FALSE POSITIVES: Should NOT trigger avoid_permission_request_loop
// ============================================================================

// OK: Non-Permission request() inside a loop
Future<void> _falsePositive1() async {
  for (final url in ['a', 'b', 'c']) {
    await httpClient.request(url); // Not Permission.request()
  }
}

// OK: Loop without Permission.request()
Future<void> _falsePositive2() async {
  final permissions = [Permission.camera, Permission.location];
  // Just checking status, not requesting
  for (final p in permissions) {
    final status = await p.status;
    print(status);
  }
}

// Helpers
Future<void> openAppSettings() async {}
Future<void> showPermissionRationale() async {}
void handleDenied() {}
void openCamera() {}

class _HttpClient {
  Future<void> request(String url) async {}
}

final httpClient = _HttpClient();
