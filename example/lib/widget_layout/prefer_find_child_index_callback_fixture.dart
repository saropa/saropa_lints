// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors

/// Fixture for `prefer_find_child_index_callback` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: List of children with index instead of builder
// expect_lint: prefer_find_child_index_callback
Widget bad() => ListView(children: [const Text('0'), const Text('1')]);

// GOOD: findChildIndexCallback or SliverChildBuilderDelegate
Widget good() => ListView.builder(itemBuilder: (context, i) => Text('$i'));

void main() {}
