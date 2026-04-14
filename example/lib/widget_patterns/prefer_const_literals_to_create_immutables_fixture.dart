// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `prefer_const_literals_to_create_immutables` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Non-const list passed to immutable
// expect_lint: prefer_const_literals_to_create_immutables
Widget bad() => Column(children: [const Text('a')]);

// GOOD: Const literal
Widget good() => Column(children: const [Text('a')]);

void main() {}
