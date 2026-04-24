// ignore_for_file: unused_element, undefined_named_parameter, unused_element_parameter
// Test fixture for: avoid_removed_appbar_backwards_compatibility
// Source: lib/src/rules/config/flutter_sdk_migration_rules.dart

import '../flutter_mocks.dart';

Widget appBarBackwardsCompatibilityBad() {
  // expect_lint: avoid_removed_appbar_backwards_compatibility
  return AppBar(backwardsCompatibility: false, title: const _Empty());
}

Widget sliverAppBarBackwardsCompatibilityBad() {
  // expect_lint: avoid_removed_appbar_backwards_compatibility
  return SliverAppBar(backwardsCompatibility: false, title: const _Empty());
}

Widget appBarBackwardsCompatibilityGood() {
  return AppBar(title: const _Empty());
}

Widget appBarBackwardsCompatibilityFalsePositive() {
  return _CustomBar(backwardsCompatibility: true);
}

class _Empty extends Widget {
  const _Empty();
}

class _CustomBar extends Widget {
  const _CustomBar({super.key, this.backwardsCompatibility = false});
  final bool backwardsCompatibility;
}
