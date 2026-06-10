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
// Test fixture for: avoid_string_substring
// Source: lib\src\rules\code_quality_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic result;
final text = 'text';

// BAD: Should trigger avoid_string_substring
// expect_lint: avoid_string_substring
void _bad159() {
  final result = text.substring(5, 10);
}

// GOOD: Should NOT trigger avoid_string_substring
void _good159() {
  final result = text.length >= 10 ? text.substring(5, 10) : text;
  // or use split/pattern matching for extracting parts
}

// GOOD: indexOf-guarded substring — semiIndex is checked for -1 before use
String? _goodIndexOfGuard(String s) {
  final semiIndex = s.indexOf(';');
  if (semiIndex == -1) return null;
  return s.substring(0, semiIndex);
}

// GOOD: while-loop guard — offset is bounded by loop condition
String _goodWhileLoopGuard(String text) {
  final buf = StringBuffer();
  int offset = 0;
  final int length = text.length;
  while (offset < length) {
    final ampIndex = text.indexOf('&', offset);
    if (ampIndex == -1) {
      buf.write(text.substring(offset));
      break;
    }
    if (ampIndex > offset) {
      buf.write(text.substring(offset, ampIndex));
    }
    offset = ampIndex + 1;
  }
  return buf.toString();
}

// GOOD: for-loop guard — end is bounded by loop condition
String? _goodForLoopGuard(String text, int offset, int maxLen) {
  final bound = text.length < offset + maxLen ? text.length : offset + maxLen;
  for (int end = bound; end >= offset + 3; end--) {
    final candidate = text.substring(offset, end);
    if (candidate == '&amp') return candidate;
  }
  return null;
}

// GOOD: arithmetic guard with early return before substring
String? _goodArithmeticGuard(String text, int offset) {
  if (offset + 3 >= text.length) return null;
  final semiIndex = text.indexOf(';', offset + 2);
  if (semiIndex == -1) return null;
  final digitStart = offset + 3;
  if (digitStart >= semiIndex) return null;
  return text.substring(digitStart, semiIndex);
}

// GOOD: else-branch of an indexOf ternary — the safe slice is normally the
// else branch (the then handles "not found").
String _goodElseBranchTernary(String local) {
  final int i = local.indexOf('+');
  return i < 0 ? local : local.substring(0, i);
}

// GOOD: emptiness guard proves length >= 1 for substring(1) / substring(0, 1).
String _goodIsEmptyTernary(String t) => t.isEmpty ? t : t.substring(1);

// GOOD: startsWith early-exit proves the prefix length is present.
String? _goodStartsWithEarlyExit(String fragment) {
  if (!fragment.startsWith('p/')) return null;
  return fragment.substring(2);
}

// GOOD: substring arg is a property access (prefix.length) — the receiver
// guard (startsWith) still recognizes the bound.
String? _goodPropertyAccessArg(String value, String prefix) {
  if (!value.startsWith(prefix)) return null;
  return value.substring(prefix.length);
}

// GOOD: regex format guard guarantees a minimum length before the slice.
int? _goodRegexGuard(String key, RegExp pattern) {
  if (!pattern.hasMatch(key)) return null;
  return int.tryParse(key.substring(0, 2));
}

// GOOD: post-loop slice — the preceding while bounded `i` against length.
String _goodPostLoopSlice(String source, int start) {
  int i = start;
  while (i < source.length) {
    i++;
  }
  return source.substring(start, i);
}
