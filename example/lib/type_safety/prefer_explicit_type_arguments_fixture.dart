// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// Test fixture for: prefer_explicit_type_arguments
// Source: lib\src\rules\type_safety_rules.dart

import '../flutter_mocks.dart';

dynamic future;
dynamic value;

// BAD: Should trigger prefer_explicit_type_arguments
// expect_lint: prefer_explicit_type_arguments
void _bad1239() {
  final list = []; // List<dynamic>
  final map = {}; // Map<dynamic, dynamic>
  final future = Future.value(1); // Inferred
}

// GOOD: Should NOT trigger prefer_explicit_type_arguments
void _good1239() {
  final list = <String>[];
  final map = <String, int>{};
  final future = Future<int>.value(1);
}
