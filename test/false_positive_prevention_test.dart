import 'dart:io';

import 'package:test/test.dart';

/// Tests for 6 rules for false positive prevention:
///
/// 1. prefer_correct_package_name - library directive naming
/// 2. avoid_getx_build_context_bypass - Get.context usage
/// 3. avoid_permission_handler_null_safety - deprecated API detection
/// 4. avoid_retaining_disposed_widgets - widget refs in non-widget classes
/// 5. require_secure_key_generation - predictable key patterns
/// 6. require_hive_web_subdirectory - missing subDir in initFlutter
///
/// Test fixtures: example/lib/false_positive_prevention_fixture.dart
void main() {
  group('Rules - False Positive Prevention', () {
    test('fixture file exists', () {
      final file = File('example/lib/false_positive_prevention_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    // Stub-only behavior tests were removed from this file.
  });
}
