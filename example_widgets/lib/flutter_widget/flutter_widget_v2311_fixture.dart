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
// Test fixture for flutter widget rules added in v2.3.11

// =========================================================================
// avoid_builder_index_out_of_bounds
// =========================================================================
// Warns when itemBuilder accesses list without bounds check.
// If the list changes while the builder is running, index may be invalid.

import 'package:flutter/widgets.dart';

// BAD: No bounds check on list access
class BadListBuilderNoBoundsCheck extends StatelessWidget {
  const BadListBuilderNoBoundsCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        return Text(items[index]); // items might change!
      },
    );
  }
}

// BAD: Using 'i' as index without bounds check
class BadListBuilderIVariable extends StatelessWidget {
  const BadListBuilderIVariable({super.key, required this.data});
  final List<int> data;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: data.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, i) {
        return Text('${data[i]}'); // data might change!
      },
    );
  }
}

// GOOD: With bounds check
class GoodListBuilderWithBoundsCheck extends StatelessWidget {
  const GoodListBuilderWithBoundsCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (index >= items.length) return const SizedBox.shrink();
        return Text(items[index]); // Safe - bounds checked
      },
    );
  }
}

// GOOD: Using isEmpty check
class GoodListBuilderIsEmptyCheck extends StatelessWidget {
  const GoodListBuilderIsEmptyCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Text(items[index]);
      },
    );
  }
}

// GOOD: No list access in itemBuilder (safe)
class GoodListBuilderNoAccess extends StatelessWidget {
  const GoodListBuilderNoAccess({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Text('Item $index'); // No list access
      },
    );
  }
}

// GOOD: Using isNotEmpty check
class GoodListBuilderIsNotEmptyCheck extends StatelessWidget {
  const GoodListBuilderIsNotEmptyCheck({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (items.isNotEmpty && index < items.length) {
          return Text(items[index]);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// BAD: Bounds check on WRONG list - should be caught!
class BadListBuilderWrongListCheck extends StatelessWidget {
  const BadListBuilderWrongListCheck({
    super.key,
    required this.items,
    required this.otherList,
  });
  final List<String> items;
  final List<String> otherList;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        // Bounds check on otherList, but accessing items!
        if (otherList.length > 0) {
          return Text(items[index]); // WRONG - items not checked!
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// GOOD: Property access with correct bounds check
class GoodListBuilderPropertyAccess extends StatelessWidget {
  const GoodListBuilderPropertyAccess({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (index >= items.length) return const SizedBox.shrink();
        return Text(items[index]); // Safe - correct list checked
      },
    );
  }
}

// BAD: Multiple lists accessed, only one checked
class BadListBuilderMultipleLists extends StatelessWidget {
  const BadListBuilderMultipleLists({
    super.key,
    required this.names,
    required this.ages,
  });
  final List<String> names;
  final List<int> ages;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: names.length,
      // expect_lint: avoid_builder_index_out_of_bounds
      itemBuilder: (context, index) {
        // Only names is checked, but ages is also accessed
        if (index >= names.length) return const SizedBox.shrink();
        return Text('${names[index]}: ${ages[index]}'); // ages not checked!
      },
    );
  }
}

// =========================================================================
// Flutter Widget Rules (from v4.1.5)
// =========================================================================

// BAD: GlobalKey in StatefulWidget
// expect_lint: avoid_global_keys_in_state
class BadGlobalKeyWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Wrong place!

  @override
  State<BadGlobalKeyWidget> createState() => _BadGlobalKeyWidgetState();
}

class _BadGlobalKeyWidgetState extends State<BadGlobalKeyWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: GlobalKey in State
class GoodGlobalKeyWidget extends StatefulWidget {
  const GoodGlobalKeyWidget({super.key});

  @override
  State<GoodGlobalKeyWidget> createState() => _GoodGlobalKeyWidgetState();
}

class _GoodGlobalKeyWidgetState extends State<GoodGlobalKeyWidget> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // Correct!

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: GlobalKey passed as constructor parameter (pass-through from parent)
class GoodPassThroughGlobalKeyWidget extends StatefulWidget {
  const GoodPassThroughGlobalKeyWidget({this.navKey, super.key});

  final GlobalKey<State<StatefulWidget>>? navKey; // Not owned here

  @override
  State<GoodPassThroughGlobalKeyWidget> createState() =>
      _GoodPassThroughGlobalKeyWidgetState();
}

class _GoodPassThroughGlobalKeyWidgetState
    extends State<GoodPassThroughGlobalKeyWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

// BAD: Static router config
class AppRouter {
  // expect_lint: avoid_static_route_config
  static final GoRouter router = GoRouter(routes: []);
}

// Mock classes
class GlobalKey<T extends State> {
  GlobalKey();
}

class FormState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) => Container();
}

class GoRouter {
  GoRouter({required List<Object> routes});
}

class Container extends Widget {
  const Container({super.key});
}

class StatefulWidget extends Widget {
  const StatefulWidget({super.key});
  State createState() => throw UnimplementedError();
}

abstract class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  Widget build(BuildContext context);
}

class BuildContext {}
