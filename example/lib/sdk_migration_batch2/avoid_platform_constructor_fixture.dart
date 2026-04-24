// ignore_for_file: unused_local_variable, instantiate_abstract_class
// Test fixture for: avoid_platform_constructor
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

import 'dart:io';

void badPlatformCtor() {
  // expect_lint: avoid_platform_constructor
  final p = Platform();
}

void goodPlatformStatics() {
  final a = Platform.isAndroid;
  final b = Platform.environment;
}
