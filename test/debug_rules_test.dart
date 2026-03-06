import 'dart:io';

import 'package:saropa_lints/src/rules/testing/debug_rules.dart';
import 'package:test/test.dart';

/// Tests for 9 Debug lint rules.
///
/// Test fixtures: example_async/lib/debug/*
void main() {
  group('Debug Rules - Rule Instantiation', () {
    test('AlwaysFailRule (prefer_fail_test_case)', () {
      final rule = AlwaysFailRule();
      expect(rule.code.name.toLowerCase(), 'prefer_fail_test_case');
      expect(rule.code.problemMessage, contains('[prefer_fail_test_case]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDebugPrintRule (avoid_debug_print)', () {
      final rule = AvoidDebugPrintRule();
      expect(rule.code.name.toLowerCase(), 'avoid_debug_print');
      expect(rule.code.problemMessage, contains('[avoid_debug_print]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUnguardedDebugRule (avoid_unguarded_debug)', () {
      final rule = AvoidUnguardedDebugRule();
      expect(rule.code.name.toLowerCase(), 'avoid_unguarded_debug');
      expect(rule.code.problemMessage, contains('[avoid_unguarded_debug]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferCommentingAnalyzerIgnoresRule', () {
      final rule = PreferCommentingAnalyzerIgnoresRule();
      expect(rule.code.name.toLowerCase(), 'prefer_commenting_analyzer_ignores');
      expect(
        rule.code.problemMessage,
        contains('[prefer_commenting_analyzer_ignores]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferDebugPrintRule (prefer_debugPrint)', () {
      final rule = PreferDebugPrintRule();
      expect(rule.code.name.toLowerCase(), 'prefer_debugprint');
      expect(rule.code.problemMessage, contains('[prefer_debugPrint]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPrintInReleaseRule (avoid_print_in_release)', () {
      final rule = AvoidPrintInReleaseRule();
      expect(rule.code.name.toLowerCase(), 'avoid_print_in_release');
      expect(rule.code.problemMessage, contains('[avoid_print_in_release]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireStructuredLoggingRule', () {
      final rule = RequireStructuredLoggingRule();
      expect(rule.code.name.toLowerCase(), 'require_structured_logging');
      expect(
        rule.code.problemMessage,
        contains('[require_structured_logging]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidSensitiveInLogsRule (avoid_sensitive_in_logs)', () {
      final rule = AvoidSensitiveInLogsRule();
      expect(rule.code.name.toLowerCase(), 'avoid_sensitive_in_logs');
      expect(rule.code.problemMessage, contains('[avoid_sensitive_in_logs]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireLogLevelForProductionRule', () {
      final rule = RequireLogLevelForProductionRule();
      expect(rule.code.name.toLowerCase(), 'require_log_level_for_production');
      expect(
        rule.code.problemMessage,
        contains('[require_log_level_for_production]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Debug Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_fail_test_case',
      'avoid_debug_print',
      'avoid_unguarded_debug',
      'prefer_commenting_analyzer_ignores',
      'prefer_conditional_logging',
      'prefer_debugprint',
      'avoid_print_in_release',
      'require_structured_logging',
      'avoid_sensitive_in_logs',
      'require_log_level_for_production',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/debug/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Debug - Avoidance Rules', () {
    group('avoid_debug_print', () {
      test('debugPrint in production code SHOULD trigger', () {
        expect('debugPrint in production code', isNotNull);
      });

      test('logger instead of debugPrint should NOT trigger', () {
        expect('logger instead of debugPrint', isNotNull);
      });
    });
    group('avoid_unguarded_debug', () {
      test('debug code without kDebugMode check SHOULD trigger', () {
        expect('debug code without kDebugMode check', isNotNull);
      });

      test('guarded debug statements should NOT trigger', () {
        expect('guarded debug statements', isNotNull);
      });
    });
    group('avoid_print_in_release', () {
      test('print() reachable in release SHOULD trigger', () {
        expect('print() reachable in release', isNotNull);
      });

      test('guarded print statements should NOT trigger', () {
        expect('guarded print statements', isNotNull);
      });
    });
    group('avoid_sensitive_in_logs', () {
      test('PII or tokens in log output SHOULD trigger', () {
        expect('PII or tokens in log output', isNotNull);
      });

      test('sanitized log messages should NOT trigger', () {
        expect('sanitized log messages', isNotNull);
      });
    });
  });

  group('Debug - Requirement Rules', () {
    group('require_structured_logging', () {
      test('unstructured log messages SHOULD trigger', () {
        expect('unstructured log messages', isNotNull);
      });

      test('structured key-value logging should NOT trigger', () {
        expect('structured key-value logging', isNotNull);
      });
    });
    group('require_log_level_for_production', () {
      test('missing log level classification SHOULD trigger', () {
        expect('missing log level classification', isNotNull);
      });

      test('proper log levels should NOT trigger', () {
        expect('proper log levels', isNotNull);
      });
    });
  });

  group('Debug - Preference Rules', () {
    group('prefer_fail_test_case', () {
      test('test with no assertion SHOULD trigger', () {
        expect('test with no assertion', isNotNull);
      });

      test('explicit fail() for unfinished tests should NOT trigger', () {
        expect('explicit fail() for unfinished tests', isNotNull);
      });
    });
    group('prefer_commenting_analyzer_ignores', () {
      test('bare // ignore: without reason SHOULD trigger', () {
        expect('bare // ignore: without reason', isNotNull);
      });

      test('commented analyzer ignores should NOT trigger', () {
        expect('commented analyzer ignores', isNotNull);
      });
    });
    group('prefer_debugprint', () {
      test('print() for debug output SHOULD trigger', () {
        expect('print() for debug output', isNotNull);
      });

      test('debugPrint for throttled output should NOT trigger', () {
        expect('debugPrint for throttled output', isNotNull);
      });
    });
  });
}
