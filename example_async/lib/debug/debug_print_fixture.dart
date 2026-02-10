// Fixture to test quick fixes for debug print rules.
//
// Quick fix available: "Comment out debugPrint statement"
// Quick fix available: "Comment out print statement"

// ignore_for_file: unused_local_variable
// ignore_for_file: unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, unnecessary_import
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

void debugPrintExample() {
  final value = 42;

  // expect_lint: avoid_debug_print
  debugPrint('Debug value: $value');

  // expect_lint: avoid_print_in_production
  print('Production print: $value');
}

void alreadyFixed() {
  final value = 42;

  // Commented out by quick fix - preserves developer intent
  // debugPrint('Debug value: $value');

  // Commented out by quick fix - preserves developer intent
  // print('Production print: $value');
}

// =============================================================================
// Logging Rules (from v4.1.6)
// =============================================================================

// BAD: print without kDebugMode check
void testPrintInRelease() {
  // expect_lint: avoid_print_in_release
  print('This runs in release builds!');
}

// GOOD: print with kDebugMode check
void testPrintWithDebugMode() {
  if (kDebugMode) {
    print('Only runs in debug mode');
  }
}

// BAD: String concatenation in logs
void testStructuredLogging(String user, DateTime time) {
  // expect_lint: require_structured_logging
  print('User ' + user + ' logged in at ' + time.toString());
}

// GOOD: String interpolation instead
void testGoodLogging(String user, DateTime time) {
  if (kDebugMode) {
    print('User $user logged in at $time');
  }
}

// BAD: Sensitive data in logs
void testSensitiveInLogs(String password, String apiKey) {
  // expect_lint: avoid_sensitive_in_logs
  print('Login with password: $password');

  // expect_lint: avoid_sensitive_in_logs
  debugPrint('Using API key: $apiKey');
}

// GOOD: No sensitive data in logs
void testGoodSecureLogs(String userId) {
  if (kDebugMode) {
    print('Login attempt for user: $userId');
  }
}

const bool kDebugMode = true;
