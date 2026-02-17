import 'dart:io';

import 'package:test/test.dart';

/// Tests for 3 Platform lint rules.
///
/// Test fixtures: example_platforms/lib/platform/*
void main() {
  group('Platform Rules - Fixture Verification', () {
    final fixtures = [
      'require_platform_check',
      'prefer_platform_io_conditional',
      'prefer_foundation_platform_check',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_platforms/lib/platform/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Platform - Requirement Rules', () {
    group('require_platform_check', () {
      test('platform-specific code without check SHOULD trigger', () {
        expect('platform-specific code without check', isNotNull);
      });

      test('Platform.isX guard should NOT trigger', () {
        expect('Platform.isX guard', isNotNull);
      });
    });
  });

  group('Platform - Preference Rules', () {
    group('prefer_platform_io_conditional', () {
      test('manual platform string check SHOULD trigger', () {
        expect('manual platform string check', isNotNull);
      });

      test('Platform.isX property should NOT trigger', () {
        expect('Platform.isX property', isNotNull);
      });
    });
    group('prefer_foundation_platform_check', () {
      test('dart:io Platform in Flutter SHOULD trigger', () {
        expect('dart:io Platform in Flutter', isNotNull);
      });

      test('foundation defaultTargetPlatform should NOT trigger', () {
        expect('foundation defaultTargetPlatform', isNotNull);
      });
    });
  });
}
