// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `avoid_unnecessary_containers` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Container with only child
// expect_lint: avoid_unnecessary_containers
Widget bad() => Container(child: const Text('x'));

// GOOD: Child directly or use Padding/Align when needed
Widget good() => const Text('x');

void main() {}
