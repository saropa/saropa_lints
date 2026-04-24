// ignore_for_file: unused_element
// Test fixture for: prefer_never_over_always_throws
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

import 'package:meta/meta.dart';

// expect_lint: prefer_never_over_always_throws
@alwaysThrows
void legacyThrows(String message) {
  throw ArgumentError(message);
}

Never modernNever(String message) {
  throw ArgumentError(message);
}
