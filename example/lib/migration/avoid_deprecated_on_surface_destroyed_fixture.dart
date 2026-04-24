// ignore_for_file: unused_local_variable, unused_element
// Test fixture for: avoid_deprecated_on_surface_destroyed
// Source: lib/src/rules/config/migration_rules.dart
// package:flutter/ — rule requires this substring; SurfaceProducer from ../flutter_mocks.dart

import '../flutter_mocks.dart';

// BAD: use onSurfaceCleanup
// expect_lint: avoid_deprecated_on_surface_destroyed
void _bad() {
  final p = SurfaceProducer();
  p.onSurfaceDestroyed = () {};
}

// GOOD: replacement name
void _good() {
  final p = SurfaceProducer();
  p.onSurfaceCleanup = () {};
}
