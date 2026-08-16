// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters_skip_private
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
// Test fixture for: prefer_static_method
// Source: lib\src\rules\structure_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic a;
dynamic b;

// BAD: Should trigger prefer_static_method
// expect_lint: prefer_static_method
class _bad1060_Utils {
  int add(int a, int b) => a + b; // Doesn't use this
}

// GOOD: Should NOT trigger prefer_static_method
class _good1060_Utils {
  static int add(int a, int b) => a + b;
}

// Regression fixture for: prefer_static_method false positive on bare
// (unprefixed) instance-member access — see plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md
class _ImplicitAccessState {
  final ValueNotifier<Map<String, int>> _countsNotifier =
      ValueNotifier<Map<String, int>>(<String, int>{});
  int _count = 0;

  // GOOD: writes a bare field — must NOT lint. Regression case: a pure write
  // target has a null `SimpleIdentifier.element` (only reads resolve there),
  // so this needs the assignment's own writeElement to be detected.
  void writeBareGood() {
    _count = 5;
  }

  // GOOD: bare field increment — must NOT lint (same writeElement fallback).
  void incrementBareGood() {
    _count++;
  }

  // GOOD: reads instance state (`_countsNotifier`) via a bare identifier
  // inside a nested closure — must NOT lint, even though no `this.` appears.
  Widget buildCountsGood() {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: _countsNotifier,
      builder: (BuildContext _, Map<String, int> counts, Widget? _) =>
          Text('${counts.length}'),
    );
  }

  // BAD: touches no instance state itself — must still lint (true positive).
  // expect_lint: prefer_static_method
  void _helper() {}

  // GOOD: calls another instance method via a bare identifier — must NOT lint.
  void callsHelperGood() {
    _helper();
  }

  // BAD: touches no instance state anywhere, including nested closures —
  // must still lint (true positive preserved).
  // expect_lint: prefer_static_method
  int computeGood(int x, int y) {
    final List<int> values = <int>[x, y];
    return values.fold(0, (int a, int b) => a + b);
  }

  // GOOD: explicit `this.field` access — already correctly not linted.
  void explicitThisGood() {
    this._countsNotifier.value = <String, int>{};
  }

  // BAD: cascaded calls on a local variable are not instance-state access —
  // must still lint. Regression case for the cascade/target-detection gap.
  // expect_lint: prefer_static_method
  int cascadeOnLocalGood(int x, int y) {
    final List<int> values = <int>[]..add(x)..add(y);
    return values.length;
  }

  // GOOD: cascading on `this` — must NOT lint. Confirms the cascade-section
  // exclusion above only skips non-`this` targets; ThisExpression itself
  // still signals instance-state usage for a `this..` cascade.
  void cascadeOnThisGood() {
    this
      .._countsNotifier.value = <String, int>{}
      .._helper();
  }

  // GOOD: a local function closes over the enclosing instance, so a bare
  // field read inside it is still instance-state access — must NOT lint.
  void localFunctionClosureGood() {
    void inner() {
      _countsNotifier.value = <String, int>{};
    }

    inner();
  }
}

mixin _ImplicitAccessMixin {
  int get _count => 0;

  // GOOD: reads a mixin's own instance getter via a bare identifier —
  // must NOT lint.
  int mixinReadsGood() => _count;
}

enum _ImplicitAccessEnum {
  a(1),
  b(2);

  const _ImplicitAccessEnum(this._value);
  final int _value;

  // GOOD: enum instance method reading its own field via a bare identifier
  // — must NOT lint.
  int enumReadsGood() => _value;
}
