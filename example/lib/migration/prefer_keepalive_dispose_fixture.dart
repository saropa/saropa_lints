// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: prefer_keepalive_dispose
// Test fixture for: prefer_keepalive_dispose
// Source: lib\src\rules\config\migration_rules.dart

import '../flutter_mocks.dart';

// BAD: Using deprecated 'release()' method
// expect_lint: prefer_keepalive_dispose
void _badRelease() {
  final handle = KeepAliveHandle();
  handle.release();
}

// GOOD: Using the replacement 'dispose()' method
void _goodDispose() {
  final handle = KeepAliveHandle();
  handle.dispose();
}

// FALSE POSITIVE: release() on a different type
void _fpOtherRelease() {
  final list = <int>[];
  // Not KeepAliveHandle, so should not trigger
  list.length;
}
