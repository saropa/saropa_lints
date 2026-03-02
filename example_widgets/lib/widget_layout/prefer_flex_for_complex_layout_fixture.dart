// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `prefer_flex_for_complex_layout` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Row/Column where Flex would be clearer
// expect_lint: prefer_flex_for_complex_layout
Widget bad() => Row(children: [const Text('a'), const Text('b')]);

// GOOD: Flex for conditional direction
Widget good() => Flex(direction: Axis.horizontal, children: [const Text('a')]);

void main() {}
