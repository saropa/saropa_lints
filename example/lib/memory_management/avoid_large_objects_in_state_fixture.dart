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
// Test fixture for: avoid_large_objects_in_state
// Source: lib\src\rules\memory_management_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic data;

// BAD: Should trigger avoid_large_objects_in_state
// Unbounded List accumulated via .add() — genuine growth-without-limit.
// expect_lint: avoid_large_objects_in_state
class _bad467__MyWidgetState extends State<MyWidget> {
  List<LargeDataModel> allItems = []; // LINT — grows unbounded via .add()
  Map<String, Uint8List> imageCache = {}; // LINT — no reassignment or bound

  void loadMore(List<LargeDataModel> items) {
    allItems.addAll(items); // accumulates across calls
  }
}

// BAD: Field accumulated via .add() across multiple calls without clear.
// expect_lint: avoid_large_objects_in_state
class _bad468__AccumulatedState extends State<MyWidget> {
  List<String> history = []; // LINT — accumulated, never cleared/replaced

  void onEvent(String event) {
    history.add(event); // accumulates without bound
  }
}

// GOOD: Field always reassigned to a fresh collection — not accumulated.
class _good467__MyWidgetState extends State<MyWidget> {
  // Use pagination or streaming
  late final ScrollController _controller;
  // Or use external cache with LRU eviction
}

// GOOD: Fields reassigned wholesale in a recompute method — bounded by input.
class _good468__RecomputedCacheState extends State<MyWidget> {
  List<DateTime>? _groupValues; // no LINT — replaced every recompute
  Map<DateTime, List<String>>? _groupedByDate; // no LINT — replaced

  void _recompute(Map<DateTime, List<String>> byDate) {
    // Replaces both fields with fresh collections sized to the input.
    _groupValues = byDate.keys.toList()
      ..sort((DateTime a, DateTime b) => b.compareTo(a));
    _groupedByDate = <DateTime, List<String>>{};
    for (final DateTime key in _groupValues!) {
      _groupedByDate![key] = byDate[key]!;
    }
  }
}

// GOOD: Field reassigned via ..sort() cascade on a fresh .toList().
class _good469__SortedListState extends State<MyWidget> {
  List<int>? _sorted; // no LINT — fresh list each time

  void refresh(List<int> source) {
    _sorted = source.toList()..sort();
  }
}

// BAD: Field grown via subscript-assignment (`_cache[k] = v`) — unbounded
// even though a `reset()` method elsewhere reassigns the field wholesale.
// Growth-via-subscript is unbounded whenever reset() isn't called, so the
// presence of a reset must not suppress the diagnostic.
// expect_lint: avoid_large_objects_in_state
class _bad469__SubscriptGrownState extends State<MyWidget> {
  Map<String, String> cache = {}; // LINT — grows via cache[k] = v, unbounded

  void store(String key, String value) {
    cache[key] = value; // subscript-assignment accumulation
  }

  void reset() {
    cache = {}; // unrelated wholesale reassignment — does not bound growth
  }
}

// BAD: Field accumulated via cascade (`..add()`) — the double-dot form must
// not evade detection just because it differs from the single-dot `.add()`.
// expect_lint: avoid_large_objects_in_state
class _bad470__CascadeAccumulatedState extends State<MyWidget> {
  List<int> items = []; // LINT — grows via cascade ..add()

  void addItems(List<int> newItems) {
    items
      ..addAll(newItems)
      ..sort();
  }
}

// BAD: Self-reassigning cascade (`field = field..add(x)`) — looks like a
// reassignment but is actually accumulation. The reassignment regex must
// not suppress this because the cascade mutates the same collection.
// expect_lint: avoid_large_objects_in_state
class _bad471__SelfReassigningCascadeState extends State<MyWidget> {
  List<String> log = []; // LINT — cascade append disguised as reassignment

  void append(String entry) {
    log = log..add(entry); // self-reassigning cascade, still accumulates
  }
}
