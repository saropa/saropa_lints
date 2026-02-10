// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters, override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member, extends_non_class
// ignore_for_file: mixin_of_non_class, field_initializer_outside_constructor
// ignore_for_file: final_not_initialized, super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member, type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument, undefined_named_parameter
// ignore_for_file: argument_type_not_assignable, invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named, undefined_annotation
// ignore_for_file: creation_with_non_type, invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this, expected_class_member
// ignore_for_file: body_might_complete_normally, not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value, return_of_invalid_type
// ignore_for_file: use_of_void_result, missing_function_body
// ignore_for_file: extra_positional_arguments, not_enough_positional_arguments
// ignore_for_file: unused_label, unused_element_parameter
// ignore_for_file: non_type_as_type_argument, expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token, duplicate_definition
// ignore_for_file: override_on_non_overriding_member, extends_non_class
// ignore_for_file: no_default_super_constructor, extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters, invalid_annotation
// ignore_for_file: invalid_assignment, expected_executable
// ignore_for_file: named_parameter_outside_group, obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration, await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause, could_not_infer
// ignore_for_file: uri_does_not_exist, const_method
// ignore_for_file: redirect_to_non_class, unused_catch_clause
// ignore_for_file: type_test_with_undefined_name, undefined_identifier
// ignore_for_file: undefined_function, undefined_method
// ignore_for_file: undefined_getter, undefined_setter
// ignore_for_file: undefined_class, undefined_super_member
// ignore_for_file: extraneous_modifier, experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type, undefined_operator
// ignore_for_file: dead_code, invalid_override
// ignore_for_file: not_initialized_non_nullable_variable, list_element_type_not_assignable
// ignore_for_file: assignment_to_final, equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration, const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element, missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check, invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type, instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable, constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final, mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class, dead_code_on_catch_subtype
// ignore_for_file: unreachable_switch_case, new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local, late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter, non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression, illegal_async_return_type
// ignore_for_file: type_test_with_non_type, invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure, wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable, static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor, abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for code quality rules added in v2.5.0

// =========================================================================
// no_boolean_literal_compare
// =========================================================================
// Warns when comparing boolean expressions to boolean literals.

void badBooleanComparisons(bool isEnabled, bool? maybeEnabled) {
  // expect_lint: no_boolean_literal_compare
  if (isEnabled == true) {}

  // expect_lint: no_boolean_literal_compare
  if (isEnabled == false) {}

  // expect_lint: no_boolean_literal_compare
  if (true == isEnabled) {}

  // expect_lint: no_boolean_literal_compare
  if (isEnabled != false) {}

  // OK - nullable bool needs explicit comparison
  if (maybeEnabled == true) {} // This is valid for bool?
}

void goodBooleanExpressions(bool isEnabled) {
  if (isEnabled) {} // Direct use
  if (!isEnabled) {} // Negation
}

// =========================================================================
// prefer_future_wait
// =========================================================================
// Warns when sequential awaits could use Future.wait.

Future<void> badSequentialAwaits() async {
  // expect_lint: prefer_future_wait
  final a = await fetchA();
  final b = await fetchB();
  final c = await fetchC();
  print('$a $b $c');
}

Future<void> goodParallelAwaits() async {
  final results = await Future.wait([fetchA(), fetchB(), fetchC()]);
  print(results);
}

Future<void> okDependentAwaits() async {
  // OK - b depends on a
  final a = await fetchA();
  final b = await fetchWithArg(a);
  print('$a $b');
}

// =========================================================================
// prefer_constructor_injection
// =========================================================================
// Warns when setter/method injection is used instead of constructor.

class BadServiceLocatorInjection {
  // expect_lint: prefer_constructor_injection
  late final ApiService _api; // Late field for dependency

  // expect_lint: prefer_constructor_injection
  set api(ApiService api) => _api = api; // Setter injection

  // expect_lint: prefer_constructor_injection
  void configure(UserRepository repo) {
    // Method injection
  }
}

class GoodConstructorInjection {
  const GoodConstructorInjection(this._api, this._repo);

  final ApiService _api;
  final UserRepository _repo;
}

// =========================================================================
// avoid_not_encodable_in_to_json
// =========================================================================
// Warns when toJson returns non-JSON-encodable types.

class BadJsonModel {
  final DateTime createdAt;
  final void Function() callback;

  BadJsonModel(this.createdAt, this.callback);

  Map<String, dynamic> toJson() {
    return {
      // expect_lint: avoid_not_encodable_in_to_json
      'date': DateTime.now(), // DateTime not encodable!
      // expect_lint: avoid_not_encodable_in_to_json
      'callback': callback, // Function not encodable!
    };
  }
}

class GoodJsonModel {
  final DateTime createdAt;
  final String userId;

  GoodJsonModel(this.createdAt, this.userId);

  Map<String, dynamic> toJson() {
    return {
      'date': createdAt.toIso8601String(), // Converted to string
      'userId': userId, // Primitive type
    };
  }
}

// =========================================================================
// require_error_logging
// =========================================================================
// Warns when catch blocks don't log errors.

void badSilentCatch() {
  try {
    riskyOperation();
  } catch (e) {
    // expect_lint: require_error_logging
    // Error swallowed silently!
  }
}

void goodErrorLogging() {
  try {
    riskyOperation();
  } catch (e, stackTrace) {
    debugPrint('Error: $e'); // Logged
    // Or: logger.error('Failed', error: e, stackTrace: stackTrace);
  }
}

// =========================================================================
// prefer_returning_conditional_expressions
// =========================================================================
// Warns when if/else blocks only contain return statements.

// BAD: If/else with single returns
bool badConditionalReturn(bool condition) {
  // expect_lint: prefer_returning_conditional_expressions
  if (condition) {
    return true;
  } else {
    return false;
  }
}

// BAD: Another if/else with returns
String badConditionalReturnString(bool flag) {
  // expect_lint: prefer_returning_conditional_expressions
  if (flag) {
    return 'yes';
  } else {
    return 'no';
  }
}

// GOOD: Direct boolean return
bool goodBooleanReturn(bool condition) {
  return condition;
}

// GOOD: Ternary expression
String goodTernaryReturn(bool flag) {
  return flag ? 'yes' : 'no';
}

// GOOD: Complex logic in branches (not just returns)
String goodComplexBranches(bool flag) {
  if (flag) {
    print('Processing true case');
    return 'yes';
  } else {
    print('Processing false case');
    return 'no';
  }
}

// =========================================================================
// prefer_late_final
// =========================================================================
// Warns when late variables are never reassigned after initial assignment.

// BAD: Late field assigned once from a single call site
class BadSingleAssignment {
  // expect_lint: prefer_late_final
  late String _name;

  void init() {
    _name = 'value';
  }

  String get name => _name;
}

// GOOD: Already late final
class GoodLateFinal {
  late final String _name;

  void init() {
    _name = 'value';
  }

  String get name => _name;
}

// OK: Multiple direct assignments - not a candidate
class OkMultipleAssignments {
  late String _name;

  void init() {
    _name = 'initial';
  }

  void reset() {
    _name = 'reset';
  }

  String get name => _name;
}

// OK: Helper method called from multiple sites - field IS reassigned at runtime
class OkHelperCalledMultipleTimes {
  late String _data;
  final int id;

  OkHelperCalledMultipleTimes(this.id);

  void _fetchData() {
    _data = 'data_$id';
  }

  void init() {
    _fetchData();
  }

  void refresh() {
    _fetchData();
  }

  String get data => _data;
}

// =========================================================================
// Mock classes and functions
// =========================================================================

class ApiService {}

class UserRepository {}

Future<String> fetchA() async => 'a';
Future<String> fetchB() async => 'b';
Future<String> fetchC() async => 'c';
Future<String> fetchWithArg(String arg) async => 'result: $arg';

void riskyOperation() {}
void debugPrint(String message) {}
