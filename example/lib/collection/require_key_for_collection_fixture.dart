// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `require_key_for_collection` lint rule.

import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Should trigger require_key_for_collection
// expect_lint: require_key_for_collection
void _bad248(BuildContext ctx) {
  ListView.builder(
    itemBuilder: (ctx, i) => Text('item'), // No key — state may be lost
  );
}

// GOOD: Should NOT trigger require_key_for_collection
void _good248(BuildContext ctx) {
  ListView.builder(
    itemBuilder: (ctx, i) => Text('item', key: ValueKey(i)), // Keyed
  );
}

void main() {}
