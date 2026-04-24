// ignore_for_file: unused_element
// Test fixture for: prefer_visibility_over_opacity_zero
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

import '../flutter_mocks.dart';

Widget badOpacityZero() {
  // expect_lint: prefer_visibility_over_opacity_zero
  return const Opacity(opacity: 0, child: Text('hidden'));
}

Widget badOpacityZeroDouble() {
  // expect_lint: prefer_visibility_over_opacity_zero
  return const Opacity(opacity: 0.0, child: Text('hidden'));
}

Widget goodVisibility() {
  return const Visibility(visible: false, child: Text('hidden'));
}
