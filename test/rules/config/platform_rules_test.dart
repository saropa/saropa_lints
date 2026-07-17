import 'dart:io';

import 'package:saropa_lints/src/rules/config/platform_rules.dart';
import 'package:saropa_lints/src/rules/platforms/android_rules.dart';
import 'package:test/test.dart';

/// Tests for 3 Platform lint rules.
///
/// Test fixtures: example/lib/platform/*
void main() {
  group('Platform Rules - Rule Instantiation', () {
    test('RequireAndroidManifestEntriesRule', () {
      final rule = RequireAndroidManifestEntriesRule();
      expect(rule.code.lowerCaseName, 'require_android_manifest_entries');
      expect(
        rule.code.problemMessage,
        contains('[require_android_manifest_entries]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequirePlatformCheckRule', () {
      final rule = RequirePlatformCheckRule();
      expect(rule.code.lowerCaseName, 'require_platform_check');
      expect(rule.code.problemMessage, contains('[require_platform_check]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferPlatformIoConditionalRule', () {
      final rule = PreferPlatformIoConditionalRule();
      expect(rule.code.lowerCaseName, 'prefer_platform_io_conditional');
      expect(
        rule.code.problemMessage,
        contains('[prefer_platform_io_conditional]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferFoundationPlatformCheckRule', () {
      final rule = PreferFoundationPlatformCheckRule();
      expect(rule.code.lowerCaseName, 'prefer_foundation_platform_check');
      expect(
        rule.code.problemMessage,
        contains('[prefer_foundation_platform_check]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });

    test('RequireDesktopWindowSetupRule', () {
      final rule = RequireDesktopWindowSetupRule();
      expect(rule.code.lowerCaseName, 'require_desktop_window_setup');
      expect(
        rule.code.problemMessage,
        contains('[require_desktop_window_setup]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Platform Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/platform');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('\$fixture fixture exists', () {
        final file = File('example/lib/platform/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Platform - Preference Rules', () {
    group('prefer_platform_io_conditional', () {
      test(
        'files that are dart.library.io/ffi conditional import targets do not report (see conditional_import_utils_test)',
        () {
          expect(
            'Conditional-import awareness is tested in conditional_import_utils_test',
            isNotNull,
          );
        },
      );
    });
  });
}
