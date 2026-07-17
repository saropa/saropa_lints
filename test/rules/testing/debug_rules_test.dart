import 'dart:io';

import 'package:saropa_lints/src/rules/testing/debug_rules.dart';
import 'package:test/test.dart';

/// Tests for 9 Debug lint rules.
///
/// Test fixtures: example/lib/debug/*
// Test-only print/debug patterns and fail helpers in example fixtures.
void main() {
  group('Debug Rules - Rule Instantiation', () {
    test('AlwaysFailRule (prefer_fail_test_case)', () {
      final rule = AlwaysFailRule();
      expect(rule.code.lowerCaseName, 'prefer_fail_test_case');
      expect(rule.code.problemMessage, contains('[prefer_fail_test_case]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDebugPrintRule (avoid_debug_print)', () {
      final rule = AvoidDebugPrintRule();
      expect(rule.code.lowerCaseName, 'avoid_debug_print');
      expect(rule.code.problemMessage, contains('[avoid_debug_print]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUnguardedDebugRule (avoid_unguarded_debug)', () {
      final rule = AvoidUnguardedDebugRule();
      expect(rule.code.lowerCaseName, 'avoid_unguarded_debug');
      expect(rule.code.problemMessage, contains('[avoid_unguarded_debug]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferCommentingAnalyzerIgnoresRule', () {
      final rule = PreferCommentingAnalyzerIgnoresRule();
      expect(rule.code.lowerCaseName, 'prefer_commenting_analyzer_ignores');
      expect(
        rule.code.problemMessage,
        contains('[prefer_commenting_analyzer_ignores]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferDebugPrintRule (prefer_debug_print)', () {
      final rule = PreferDebugPrintRule();
      expect(rule.code.lowerCaseName, 'prefer_debug_print');
      expect(rule.code.problemMessage, contains('[prefer_debug_print]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPrintInReleaseRule (avoid_print_in_release)', () {
      final rule = AvoidPrintInReleaseRule();
      expect(rule.code.lowerCaseName, 'avoid_print_in_release');
      expect(rule.code.problemMessage, contains('[avoid_print_in_release]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireStructuredLoggingRule', () {
      final rule = RequireStructuredLoggingRule();
      expect(rule.code.lowerCaseName, 'require_structured_logging');
      expect(
        rule.code.problemMessage,
        contains('[require_structured_logging]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidSensitiveInLogsRule (avoid_sensitive_in_logs)', () {
      final rule = AvoidSensitiveInLogsRule();
      expect(rule.code.lowerCaseName, 'avoid_sensitive_in_logs');
      expect(rule.code.problemMessage, contains('[avoid_sensitive_in_logs]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireLogLevelForProductionRule', () {
      final rule = RequireLogLevelForProductionRule();
      expect(rule.code.lowerCaseName, 'require_log_level_for_production');
      expect(
        rule.code.problemMessage,
        contains('[require_log_level_for_production]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Debug Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/debug');

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
      test('$fixture fixture exists', () {
        final file = File('example/lib/debug/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
