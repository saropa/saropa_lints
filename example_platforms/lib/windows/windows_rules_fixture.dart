// ignore_for_file: unused_local_variable, unused_element, avoid_print
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

import 'dart:io';

// =============================================================================
// avoid_hardcoded_drive_letters
// =============================================================================

/// BAD: Hardcoded Windows drive letter paths
void badDriveLetters() {
  // expect_lint: avoid_hardcoded_drive_letters
  final config = File('C:\\Users\\me\\AppData\\myapp\\config.json');

  // expect_lint: avoid_hardcoded_drive_letters
  final program = Directory('C:\\Program Files\\MyApp');

  // expect_lint: avoid_hardcoded_drive_letters
  final temp = File('D:\\temp\\cache.dat');

  // expect_lint: avoid_hardcoded_drive_letters
  final data = File('E:/backup/data.db');
}

/// GOOD: Dynamic paths
Future<void> goodDynamicPaths() async {
  final appData = Platform.environment['APPDATA'];
  final config = File('$appData\\myapp\\config.json');

  final appDir = await getApplicationSupportDirectory();
  final data = File('${appDir.path}\\data.db');
}

// =============================================================================
// avoid_forward_slash_path_assumption
// =============================================================================

/// BAD: Path concatenation with '/'
void badForwardSlashPaths() {
  final dir = '/some/directory';
  final file = 'data.txt';

  // expect_lint: avoid_forward_slash_path_assumption
  final filePath = dir + '/' + file;

  final basePath = '/base';
  final subDir = 'sub';

  // expect_lint: avoid_forward_slash_path_assumption
  final nested = '$basePath/$subDir';
}

/// GOOD: Using path.join
void goodPathJoin() {
  final dir = '/some/directory';
  final file = 'data.txt';
  final filePath = join(dir, file);
}

// =============================================================================
// avoid_case_sensitive_path_comparison
// =============================================================================

/// BAD: Case-sensitive path comparison
void badCaseSensitiveComparison() {
  final filePath = 'C:\\Users\\Me\\Documents\\file.txt';
  final expectedPath = 'C:\\Users\\me\\documents\\file.txt';

  // expect_lint: avoid_case_sensitive_path_comparison
  if (filePath == expectedPath) {
    print('Same file');
  }

  final dirPath = 'C:\\Program Files';
  final otherDirPath = 'c:\\program files';

  // expect_lint: avoid_case_sensitive_path_comparison
  if (dirPath != otherDirPath) {
    print('Different paths');
  }
}

/// GOOD: Case-insensitive comparison
void goodCaseInsensitiveComparison() {
  final filePath = 'C:\\Users\\Me\\Documents\\file.txt';
  final expectedPath = 'C:\\Users\\me\\documents\\file.txt';

  if (filePath.toLowerCase() == expectedPath.toLowerCase()) {
    print('Same file');
  }
}

// =============================================================================
// require_windows_single_instance_check
// =============================================================================

// NOTE: This rule fires on function declarations named 'main' that contain
// Platform.isWindows but lack single-instance handling. Because only one
// top-level `main` is allowed per file, these examples use comments to
// describe the expected behavior rather than `expect_lint`.

/// BAD pattern (cannot use expect_lint — only one main per file):
/// ```dart
/// void main() {
///   if (Platform.isWindows) { /* no single instance check */ }
///   runApp('MyApp');
/// }
/// ```

/// GOOD: Windows main with single instance check
void main() {
  if (Platform.isWindows) {
    // ensureSingleInstance suppresses the lint
  }
  runApp('MyApp');
}

// =============================================================================
// avoid_max_path_risk
// =============================================================================

/// BAD: Deeply nested paths
void badDeepPaths() {
  // expect_lint: avoid_max_path_risk
  final deep = p.join(
    'base',
    'company',
    'product',
    'version',
    'module',
    'feature',
    'data.json',
  );

  // expect_lint: avoid_max_path_risk
  final literal =
      'C:\\Users\\username\\AppData\\Local\\MyCompany\\MyApp\\data\\cache\\images\\file.png';
}

/// GOOD: Flat paths
void goodFlatPaths() {
  final flat = p.join('base', 'cache', 'data.json');
  final short = 'C:\\MyApp\\cache\\file.png';
}

// =============================================================================
// Mock types for compilation
// =============================================================================

Future<Directory> getApplicationSupportDirectory() async => Directory('.');
void runApp(String app) {}

/// Mock path package to provide a target for method invocation detection.
class _Path {
  String join(String a,
          [String? b, String? c, String? d, String? e, String? f, String? g]) =>
      '$a\\$b';
}

final p = _Path();
