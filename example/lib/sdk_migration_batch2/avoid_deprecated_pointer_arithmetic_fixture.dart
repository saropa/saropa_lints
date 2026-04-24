// ignore_for_file: unused_element
// Test fixture for: avoid_deprecated_pointer_arithmetic
// Source: lib/src/rules/config/sdk_migration_batch2_rules.dart

import 'dart:ffi';

void badPointerElementAt(Pointer<Int8> ptr) {
  // expect_lint: avoid_deprecated_pointer_arithmetic
  ptr.elementAt(1);
}

void goodPointerPlus(Pointer<Int8> ptr) {
  final _ = ptr + 1;
}
