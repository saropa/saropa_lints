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

import 'dart:io';

/// BAD: User input (parameters) used in file path without sanitization

/// Path traversal vulnerability - user can pass '../../../etc/passwd'
Future<File> badUserPath(String userPath) async {
  // expect_lint: avoid_path_traversal
  return File('/data/$userPath');
}

/// Path traversal vulnerability in Directory
Future<Directory> badUserDirectory(String dirName) async {
  // expect_lint: avoid_path_traversal
  return Directory('/storage/$dirName');
}

/// Path traversal vulnerability with concatenation
Future<File> badConcatenation(String filename) async {
  // expect_lint: avoid_path_traversal
  return File('/data/' + filename);
}

/// GOOD: Trusted sources (should NOT trigger)

/// Using path_provider - trusted system API
Future<File> goodPathProvider() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/app_data.json');
}

/// Using private constant subdirectory
class WidgetPathUtils {
  static const String _imageSubdirectory = 'widget_images';
  static String? _cachedContainerPath;

  Future<Directory> getImageDirectory() async {
    return Directory('$_cachedContainerPath/$_imageSubdirectory');
  }

  Future<Directory> getAppImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_imageSubdirectory');
  }
}

/// Using MethodChannel to get system path - trusted source
Future<Directory> goodMethodChannelPath() async {
  final containerPath = await _getContainerPath();
  return Directory('$containerPath/images');
}

Future<String> _getContainerPath() async {
  return '/app/container';
}

/// GOOD: User input WITH proper sanitization

/// Sanitized user input - has basename check
Future<File> goodSanitizedBasename(String userPath) async {
  final sanitized = basename(userPath);
  return File('/data/$sanitized');
}

/// Sanitized user input - has startsWith validation
Future<File> goodSanitizedStartsWith(String userPath) async {
  final file = File('/data/$userPath');
  if (!file.path.startsWith('/data/')) {
    throw SecurityException('Invalid path');
  }
  return file;
}

/// Sanitized user input - has traversal check with throw
Future<File> goodDotDotCheck(String userPath) async {
  if (userPath.contains('..')) {
    throw SecurityException('Path traversal detected');
  }
  return File('/data/$userPath');
}

/// Sanitized user input - uses path.normalize
Future<File> goodNormalize(String userPath) async {
  final normalized = normalize(userPath);
  return File('/data/$normalized');
}

/// Sanitized user input - uses isWithin check
Future<File> goodIsWithin(String userPath) async {
  final file = File('/data/$userPath');
  if (!isWithin('/data', file.path)) {
    throw SecurityException('Invalid path');
  }
  return file;
}

class Directory {
  final String path;
  Directory(this.path);
}

class File {
  final String path;
  File(this.path);
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('/app/documents');
}

String basename(String path) => path.split('/').last;
String normalize(String path) => path.replaceAll('..', '');
bool isWithin(String parent, String child) => child.startsWith(parent);

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
}
