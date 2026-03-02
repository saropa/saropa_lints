// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `avoid_bool_in_widget_constructors` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Widget with named bool parameter
// expect_lint: avoid_bool_in_widget_constructors
Widget bad() => Switch(value: true, onChanged: null);

// GOOD: No bool in constructor
Widget good() => const Text('ok');

void main() {}
