// Error handling rules: stack trace / logging / swallowing patterns; fixtures in example/lib.
library;

import 'dart:io';

import 'package:saropa_lints/src/rules/flow/error_handling_rules.dart';
import 'package:test/test.dart';

/// Tests for 22 Error Handling lint rules.
///
/// These rules cover exception handling, error logging, stack trace
/// preservation, and production error safety.
///
/// Test fixtures: example/lib/error_handling/*
// Split between instantiation and integration-style cases in groups below.
void main() {
  group('Error Handling Rules - Rule Instantiation', () {
    test('AvoidSwallowingExceptionsRule', () {
      final rule = AvoidSwallowingExceptionsRule();
      expect(rule.code.lowerCaseName, 'avoid_swallowing_exceptions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_swallowing_exceptions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidLosingStackTraceRule', () {
      final rule = AvoidLosingStackTraceRule();
      expect(rule.code.lowerCaseName, 'avoid_losing_stack_trace');
      expect(rule.code.problemMessage, contains('[avoid_losing_stack_trace]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidGenericExceptionsRule', () {
      final rule = AvoidGenericExceptionsRule();
      expect(rule.code.lowerCaseName, 'avoid_generic_exceptions');
      expect(rule.code.problemMessage, contains('[avoid_generic_exceptions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorContextRule', () {
      final rule = RequireErrorContextRule();
      expect(rule.code.lowerCaseName, 'require_error_context');
      expect(rule.code.problemMessage, contains('[require_error_context]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferResultPatternRule', () {
      final rule = PreferResultPatternRule();
      expect(rule.code.lowerCaseName, 'prefer_result_pattern');
      expect(rule.code.problemMessage, contains('[prefer_result_pattern]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireAsyncErrorDocumentationRule', () {
      final rule = RequireAsyncErrorDocumentationRule();
      expect(rule.code.lowerCaseName, 'require_async_error_documentation');
      expect(
        rule.code.problemMessage,
        contains('[require_async_error_documentation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNestedTryStatementsRule', () {
      final rule = AvoidNestedTryStatementsRule();
      expect(rule.code.lowerCaseName, 'avoid_nested_try_statements');
      expect(
        rule.code.problemMessage,
        contains('[avoid_nested_try_statements]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorBoundaryRule', () {
      final rule = RequireErrorBoundaryRule();
      expect(rule.code.lowerCaseName, 'require_error_boundary');
      expect(rule.code.problemMessage, contains('[require_error_boundary]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUncaughtFutureErrorsRule', () {
      final rule = AvoidUncaughtFutureErrorsRule();
      expect(rule.code.lowerCaseName, 'avoid_uncaught_future_errors');
      expect(
        rule.code.problemMessage,
        contains('[avoid_uncaught_future_errors]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPrintErrorRule', () {
      final rule = AvoidPrintErrorRule();
      expect(rule.code.lowerCaseName, 'avoid_print_error');
      expect(rule.code.problemMessage, contains('[avoid_print_error]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorHandlingGracefulRule', () {
      final rule = RequireErrorHandlingGracefulRule();
      expect(rule.code.lowerCaseName, 'require_error_handling_graceful');
      expect(
        rule.code.problemMessage,
        contains('[require_error_handling_graceful]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCatchAllRule', () {
      final rule = AvoidCatchAllRule();
      expect(rule.code.lowerCaseName, 'avoid_catch_all');
      expect(rule.code.problemMessage, contains('[avoid_catch_all]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCatchExceptionAloneRule', () {
      final rule = AvoidCatchExceptionAloneRule();
      expect(rule.code.lowerCaseName, 'avoid_catch_exception_alone');
      expect(
        rule.code.problemMessage,
        contains('[avoid_catch_exception_alone]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidExceptionInConstructorRule', () {
      final rule = AvoidExceptionInConstructorRule();
      expect(rule.code.lowerCaseName, 'avoid_exception_in_constructor');
      expect(
        rule.code.problemMessage,
        contains('[avoid_exception_in_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireCacheKeyDeterminismRule', () {
      final rule = RequireCacheKeyDeterminismRule();
      expect(rule.code.lowerCaseName, 'require_cache_key_determinism');
      expect(
        rule.code.problemMessage,
        contains('[require_cache_key_determinism]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequirePermissionPermanentDenialHandlingRule', () {
      final rule = RequirePermissionPermanentDenialHandlingRule();
      expect(
        rule.code.lowerCaseName,
        'require_permission_permanent_denial_handling',
      );
      expect(
        rule.code.problemMessage,
        contains('[require_permission_permanent_denial_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireNotificationActionHandlingRule', () {
      final rule = RequireNotificationActionHandlingRule();
      expect(rule.code.lowerCaseName, 'require_notification_action_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_notification_action_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireFinallyCleanupRule', () {
      final rule = RequireFinallyCleanupRule();
      expect(rule.code.lowerCaseName, 'require_finally_cleanup');
      expect(rule.code.problemMessage, contains('[require_finally_cleanup]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorLoggingRule', () {
      final rule = RequireErrorLoggingRule();
      expect(rule.code.lowerCaseName, 'require_error_logging');
      expect(rule.code.problemMessage, contains('[require_error_logging]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireAppStartupErrorHandlingRule', () {
      final rule = RequireAppStartupErrorHandlingRule();
      expect(rule.code.lowerCaseName, 'require_app_startup_error_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_app_startup_error_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidAssertInProductionRule', () {
      final rule = AvoidAssertInProductionRule();
      expect(rule.code.lowerCaseName, 'avoid_assert_in_production');
      expect(
        rule.code.problemMessage,
        contains('[avoid_assert_in_production]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('HandleThrowingInvocationsRule', () {
      final rule = HandleThrowingInvocationsRule();
      expect(rule.code.lowerCaseName, 'handle_throwing_invocations');
      expect(
        rule.code.problemMessage,
        contains('[handle_throwing_invocations]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  // example/lib/flow/error_handling/: try/catch, async, and error propagation fixtures.
  group('Error Handling Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/error_handling');

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
        final file = File('example/lib/error_handling/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Rules that flag swallowing errors, empty catches, or misleading handlers.
  group('Error Handling - Avoidance Rules', () {
    group('avoid_swallowing_exceptions', () {
      test('rule offers quick fix (add rethrow in catch)', () {
        final rule = AvoidSwallowingExceptionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_uncaught_future_errors', () {
      test(
        'enum declarations must NOT crash the analyzer (SDK 3.11+ regression)',
        () async {
          final repoRoot = Directory.current;
          expect(
            File(
              '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
            ).existsSync(),
            isTrue,
            reason: 'Run tests from the saropa_lints repo root.',
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'saropa_lints_enum_crash_',
          );
          addTearDown(() async {
            for (var attempt = 0; attempt < 3; attempt++) {
              try {
                if (tempDir.existsSync()) {
                  await tempDir.delete(recursive: true);
                }
                return;
              } on FileSystemException {
                await Future<void>.delayed(
                  Duration(milliseconds: 500 * (attempt + 1)),
                );
              }
            }
          });

          final repoPathForYaml = repoRoot.path.replaceAll('\\', '/');

          await Directory(
            '${tempDir.path}${Platform.pathSeparator}lib',
          ).create(recursive: true);

          await File(
            '${tempDir.path}${Platform.pathSeparator}pubspec.yaml',
          ).writeAsString('''
name: tmp_saropa_lints_enum_crash
publish_to: none

environment:
  sdk: ">=3.10.0 <4.0.0"

dev_dependencies:
  saropa_lints:
    path: "$repoPathForYaml"
''');

          await File(
            '${tempDir.path}${Platform.pathSeparator}analysis_options.yaml',
          ).writeAsString('''
plugins:
  saropa_lints:
    diagnostics:
      avoid_uncaught_future_errors: true
''');

          // File with enum, mixin, extension, and extension type declarations.
          // Before the fix, any enum would crash the entire analyzer plugin.
          await File(
            '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
          ).writeAsString('''
enum MyEnum { a, b, c }

enum EnumWithMethod {
  x, y;
  Future<void> doWork() async {}
}

mixin MyMixin {
  Future<void> mixinWork() async {}
}

extension MyExt on String {
  Future<void> extWork() async {}
}

extension type MyExtType(int value) {
  Future<void> extTypeWork() async {}
}

void main() {}
''');

          final pubGet = await Process.run(
            'dart',
            ['pub', 'get'],
            workingDirectory: tempDir.path,
            runInShell: true,
          );
          expect(
            pubGet.exitCode,
            0,
            reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
          );

          final analyze = await Process.run(
            'dart',
            ['analyze', 'lib/main.dart'],
            workingDirectory: tempDir.path,
            runInShell: true,
          );

          expect(
            analyze.exitCode,
            isNot(4),
            reason:
                'Analyzer plugin crashed (exit code 4). '
                'EnumDeclaration.body likely threw UnsupportedError:\n'
                '${analyze.stdout}\n${analyze.stderr}',
          );

          final combined = '${analyze.stdout}\n${analyze.stderr}';
          expect(
            combined,
            isNot(contains('UnsupportedError')),
            reason:
                'Analyzer threw UnsupportedError on declaration type:\n'
                '$combined',
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test(
        'unawaited(futureCall()) must NOT trigger (explicit fire-and-forget)',
        () async {
          final repoRoot = Directory.current;
          expect(
            File(
              '${repoRoot.path}${Platform.pathSeparator}pubspec.yaml',
            ).existsSync(),
            isTrue,
            reason: 'Run tests from the saropa_lints repo root.',
          );

          final tempDir = await Directory.systemTemp.createTemp(
            'saropa_lints_uncaught_future_',
          );
          addTearDown(() async {
            for (var attempt = 0; attempt < 3; attempt++) {
              try {
                if (tempDir.existsSync()) {
                  await tempDir.delete(recursive: true);
                }
                return;
              } on FileSystemException {
                // Windows: process may still hold a lock; wait and retry.
                await Future<void>.delayed(
                  Duration(milliseconds: 500 * (attempt + 1)),
                );
              }
            }
          });

          final repoPathForYaml = repoRoot.path.replaceAll('\\', '/');

          await Directory(
            '${tempDir.path}${Platform.pathSeparator}lib',
          ).create(recursive: true);

          await File(
            '${tempDir.path}${Platform.pathSeparator}pubspec.yaml',
          ).writeAsString('''
name: tmp_saropa_lints_consumer
publish_to: none

environment:
  sdk: ">=3.10.0 <4.0.0"

dev_dependencies:
  saropa_lints:
    path: "$repoPathForYaml"
''');

          await File(
            '${tempDir.path}${Platform.pathSeparator}analysis_options.yaml',
          ).writeAsString('''
plugins:
  saropa_lints:
    diagnostics:
      avoid_uncaught_future_errors: true
''');

          await File(
            '${tempDir.path}${Platform.pathSeparator}lib${Platform.pathSeparator}main.dart',
          ).writeAsString('''
import 'dart:async';

Future<void> _futureCall() async {}

void main() {
  unawaited(_futureCall());
}
''');

          final pubGet = await Process.run(
            'dart',
            ['pub', 'get'],
            workingDirectory: tempDir.path,
            runInShell: true,
          );
          expect(
            pubGet.exitCode,
            0,
            reason: 'dart pub get failed:\n${pubGet.stdout}\n${pubGet.stderr}',
          );

          final analyze = await Process.run(
            'dart',
            ['analyze', 'lib/main.dart'],
            workingDirectory: tempDir.path,
            runInShell: true,
          );

          final combined = '${analyze.stdout}\n${analyze.stderr}';
          expect(
            combined,
            isNot(contains('avoid_uncaught_future_errors')),
            reason:
                'unawaited(futureCall()) must never be reported:\n$combined',
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });
  });

  // Rules that require logging, rethrow, or typed handling when failures occur.
}
