// ignore_for_file: unused_local_variable, depend_on_referenced_packages
// Test fixture for: require_platform_check (case 5 — guards against over-suppression)
// Source: lib\src\rules\config\platform_rules.dart
//
// This file is referenced BOTH conditionally (dual_entry.dart, io branch) AND
// unconditionally (dual_unconditional.dart, plain import). Because the
// unconditional path can load it on web, it is NOT native-only and the kIsWeb
// guard is genuinely required. require_platform_check MUST fire here.
import 'dart:io';

// BAD: reachable on web via an unconditional import — expect lint.
// expect_lint: require_platform_check
void cache() {
  final file = File('cache.bin');
  file.writeAsBytesSync(const <int>[]);
}
