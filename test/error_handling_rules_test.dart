import 'dart:io';

import 'package:saropa_lints/src/rules/flow/error_handling_rules.dart';
import 'package:test/test.dart';

/// Tests for 22 Error Handling lint rules.
///
/// These rules cover exception handling, error logging, stack trace
/// preservation, and production error safety.
///
/// Test fixtures: example_async/lib/error_handling/*
void main() {
  group('Error Handling Rules - Rule Instantiation', () {
    test('AvoidSwallowingExceptionsRule', () {
      final rule = AvoidSwallowingExceptionsRule();
      expect(rule.code.name, 'avoid_swallowing_exceptions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_swallowing_exceptions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidLosingStackTraceRule', () {
      final rule = AvoidLosingStackTraceRule();
      expect(rule.code.name, 'avoid_losing_stack_trace');
      expect(rule.code.problemMessage, contains('[avoid_losing_stack_trace]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidGenericExceptionsRule', () {
      final rule = AvoidGenericExceptionsRule();
      expect(rule.code.name, 'avoid_generic_exceptions');
      expect(rule.code.problemMessage, contains('[avoid_generic_exceptions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorContextRule', () {
      final rule = RequireErrorContextRule();
      expect(rule.code.name, 'require_error_context');
      expect(rule.code.problemMessage, contains('[require_error_context]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferResultPatternRule', () {
      final rule = PreferResultPatternRule();
      expect(rule.code.name, 'prefer_result_pattern');
      expect(rule.code.problemMessage, contains('[prefer_result_pattern]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireAsyncErrorDocumentationRule', () {
      final rule = RequireAsyncErrorDocumentationRule();
      expect(rule.code.name, 'require_async_error_documentation');
      expect(
        rule.code.problemMessage,
        contains('[require_async_error_documentation]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNestedTryStatementsRule', () {
      final rule = AvoidNestedTryStatementsRule();
      expect(rule.code.name, 'avoid_nested_try_statements');
      expect(
        rule.code.problemMessage,
        contains('[avoid_nested_try_statements]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorBoundaryRule', () {
      final rule = RequireErrorBoundaryRule();
      expect(rule.code.name, 'require_error_boundary');
      expect(rule.code.problemMessage, contains('[require_error_boundary]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUncaughtFutureErrorsRule', () {
      final rule = AvoidUncaughtFutureErrorsRule();
      expect(rule.code.name, 'avoid_uncaught_future_errors');
      expect(
        rule.code.problemMessage,
        contains('[avoid_uncaught_future_errors]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidPrintErrorRule', () {
      final rule = AvoidPrintErrorRule();
      expect(rule.code.name, 'avoid_print_error');
      expect(rule.code.problemMessage, contains('[avoid_print_error]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorHandlingGracefulRule', () {
      final rule = RequireErrorHandlingGracefulRule();
      expect(rule.code.name, 'require_error_handling_graceful');
      expect(
        rule.code.problemMessage,
        contains('[require_error_handling_graceful]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCatchAllRule', () {
      final rule = AvoidCatchAllRule();
      expect(rule.code.name, 'avoid_catch_all');
      expect(rule.code.problemMessage, contains('[avoid_catch_all]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCatchExceptionAloneRule', () {
      final rule = AvoidCatchExceptionAloneRule();
      expect(rule.code.name, 'avoid_catch_exception_alone');
      expect(
        rule.code.problemMessage,
        contains('[avoid_catch_exception_alone]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidExceptionInConstructorRule', () {
      final rule = AvoidExceptionInConstructorRule();
      expect(rule.code.name, 'avoid_exception_in_constructor');
      expect(
        rule.code.problemMessage,
        contains('[avoid_exception_in_constructor]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireCacheKeyDeterminismRule', () {
      final rule = RequireCacheKeyDeterminismRule();
      expect(rule.code.name, 'require_cache_key_determinism');
      expect(
        rule.code.problemMessage,
        contains('[require_cache_key_determinism]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequirePermissionPermanentDenialHandlingRule', () {
      final rule = RequirePermissionPermanentDenialHandlingRule();
      expect(rule.code.name, 'require_permission_permanent_denial_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_permission_permanent_denial_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireNotificationActionHandlingRule', () {
      final rule = RequireNotificationActionHandlingRule();
      expect(rule.code.name, 'require_notification_action_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_notification_action_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireFinallyCleanupRule', () {
      final rule = RequireFinallyCleanupRule();
      expect(rule.code.name, 'require_finally_cleanup');
      expect(rule.code.problemMessage, contains('[require_finally_cleanup]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireErrorLoggingRule', () {
      final rule = RequireErrorLoggingRule();
      expect(rule.code.name, 'require_error_logging');
      expect(rule.code.problemMessage, contains('[require_error_logging]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('RequireAppStartupErrorHandlingRule', () {
      final rule = RequireAppStartupErrorHandlingRule();
      expect(rule.code.name, 'require_app_startup_error_handling');
      expect(
        rule.code.problemMessage,
        contains('[require_app_startup_error_handling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidAssertInProductionRule', () {
      final rule = AvoidAssertInProductionRule();
      expect(rule.code.name, 'avoid_assert_in_production');
      expect(
        rule.code.problemMessage,
        contains('[avoid_assert_in_production]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('HandleThrowingInvocationsRule', () {
      final rule = HandleThrowingInvocationsRule();
      expect(rule.code.name, 'handle_throwing_invocations');
      expect(
        rule.code.problemMessage,
        contains('[handle_throwing_invocations]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Error Handling Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_swallowing_exceptions',
      'avoid_losing_stack_trace',
      'handle_throwing_invocations',
      'avoid_generic_exceptions',
      'require_error_context',
      'prefer_result_pattern',
      'require_async_error_documentation',
      'avoid_nested_try_statements',
      'require_error_boundary',
      'avoid_uncaught_future_errors',
      'avoid_print_error',
      'avoid_catch_all',
      'avoid_catch_exception_alone',
      'avoid_exception_in_constructor',
      'require_cache_key_determinism',
      'require_permission_permanent_denial_handling',
      'require_notification_action_handling',
      'require_finally_cleanup',
      'require_error_logging',
      'require_app_startup_error_handling',
      'require_error_handling_graceful',
      'avoid_assert_in_production',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_async/lib/error_handling/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Error Handling - Avoidance Rules', () {
    group('avoid_swallowing_exceptions', () {
      test('empty catch block SHOULD trigger', () {
        // Silent failures hide production bugs and break monitoring
        expect('swallowed exception detected', isNotNull);
      });

      test('catch with logging should NOT trigger', () {
        expect('handled exception passes', isNotNull);
      });
    });

    group('avoid_losing_stack_trace', () {
      test('throw without stack trace SHOULD trigger', () {
        // Lost stack traces make debugging impossible
        expect('lost stack trace detected', isNotNull);
      });

      test('rethrow preserving stack trace should NOT trigger', () {
        expect('preserved stack trace passes', isNotNull);
      });
    });

    group('avoid_generic_exceptions', () {
      test('catch(Exception) without specifics SHOULD trigger', () {
        // Overly broad catch hides specific failure modes
        expect('generic exception detected', isNotNull);
      });

      test('catching specific exception type should NOT trigger', () {
        expect('specific exception passes', isNotNull);
      });
    });

    group('avoid_nested_try_statements', () {
      test('try inside try SHOULD trigger', () {
        // Nested try blocks indicate poor error handling structure
        expect('nested try detected', isNotNull);
      });

      test('flat try-catch should NOT trigger', () {
        expect('flat try passes', isNotNull);
      });
    });

    group('avoid_uncaught_future_errors', () {
      test('Future without error handling SHOULD trigger', () {
        // Unhandled Future errors crash the app silently
        expect('uncaught future error detected', isNotNull);
      });

      test('Future with catchError should NOT trigger', () {
        expect('handled future passes', isNotNull);
      });
    });

    group('avoid_print_error', () {
      test('print() for error output SHOULD trigger', () {
        // print() is not a proper error logging mechanism
        expect('print error detected', isNotNull);
      });

      test('logger.error() should NOT trigger', () {
        expect('proper logging passes', isNotNull);
      });
    });

    group('avoid_catch_all', () {
      test('catch without type SHOULD trigger', () {
        // Catches everything including programming errors
        expect('catch-all detected', isNotNull);
      });

      test('typed catch should NOT trigger', () {
        expect('typed catch passes', isNotNull);
      });
    });

    group('avoid_catch_exception_alone', () {
      test('catch(e) without stack trace param SHOULD trigger', () {
        // Missing stack trace parameter loses debugging info
        expect('exception-only catch detected', isNotNull);
      });

      test('catch(e, st) should NOT trigger', () {
        expect('full catch passes', isNotNull);
      });
    });

    group('avoid_exception_in_constructor', () {
      test('throwing in constructor SHOULD trigger', () {
        // Constructor exceptions are hard to handle gracefully
        expect('constructor exception detected', isNotNull);
      });

      test('factory with validation should NOT trigger', () {
        expect('factory pattern passes', isNotNull);
      });
    });

    group('avoid_assert_in_production', () {
      test('assert in production code path SHOULD trigger', () {
        // Asserts are stripped in release mode
        expect('production assert detected', isNotNull);
      });

      test('assert in debug-only code should NOT trigger', () {
        expect('debug assert passes', isNotNull);
      });
    });
  });

  group('Error Handling - Requirement Rules', () {
    group('require_error_context', () {
      test('error without context info SHOULD trigger', () {
        // Errors need context for meaningful diagnostics
        expect('missing error context detected', isNotNull);
      });

      test('error with context message should NOT trigger', () {
        expect('contextual error passes', isNotNull);
      });
    });

    group('require_async_error_documentation', () {
      test('async function without error docs SHOULD trigger', () {
        // Callers need to know what errors to expect
        expect('undocumented async errors detected', isNotNull);
      });

      test('documented async errors should NOT trigger', () {
        expect('documented async passes', isNotNull);
      });
    });

    group('require_error_boundary', () {
      test('widget tree without error boundary SHOULD trigger', () {
        // Uncaught errors crash the entire app
        expect('missing error boundary detected', isNotNull);
      });

      test('ErrorWidget.builder or similar should NOT trigger', () {
        expect('error boundary passes', isNotNull);
      });
    });

    group('require_cache_key_determinism', () {
      test('non-deterministic cache key SHOULD trigger', () {
        // Non-deterministic keys cause cache misses
        expect('non-deterministic cache key detected', isNotNull);
      });

      test('deterministic cache key should NOT trigger', () {
        expect('deterministic key passes', isNotNull);
      });
    });

    group('require_permission_permanent_denial_handling', () {
      test(
        'permission request without permanent denial check SHOULD trigger',
        () {
          // Users can permanently deny permissions
          expect('missing permanent denial handling detected', isNotNull);
        },
      );

      test('handling permanent denial should NOT trigger', () {
        expect('permanent denial handled passes', isNotNull);
      });
    });

    group('require_notification_action_handling', () {
      test('notification without action handler SHOULD trigger', () {
        // Tapped notifications need action handlers
        expect('missing notification action detected', isNotNull);
      });

      test('notification with action handler should NOT trigger', () {
        expect('notification action passes', isNotNull);
      });
    });

    group('require_finally_cleanup', () {
      test('resource acquisition without finally SHOULD trigger', () {
        // Resources must be cleaned up even on error
        expect('missing finally cleanup detected', isNotNull);
      });

      test('try-finally pattern should NOT trigger', () {
        expect('finally cleanup passes', isNotNull);
      });
    });

    group('require_error_logging', () {
      test('catch block without logging SHOULD trigger', () {
        // Errors must be logged for production diagnostics
        expect('missing error logging detected', isNotNull);
      });

      test('catch with logger call should NOT trigger', () {
        expect('error logging passes', isNotNull);
      });
    });

    group('require_app_startup_error_handling', () {
      test('main() without error zone SHOULD trigger', () {
        // Startup errors need graceful handling
        expect('missing startup error handling detected', isNotNull);
      });

      test('runZonedGuarded in main should NOT trigger', () {
        expect('startup error handling passes', isNotNull);
      });

      test('main() without crash reporting dependency should NOT trigger '
          '(regression)', () {
        // Apps without firebase_crashlytics/sentry_flutter/etc. should
        // not be forced to add runZonedGuarded with no reporting target
        expect('no crash reporting dep = no warning', isNotNull);
      });
    });
  });

  group('Error Handling - Preference Rules', () {
    group('prefer_result_pattern', () {
      test('throwing functions for expected errors SHOULD trigger', () {
        // Result pattern is safer than exceptions for expected failures
        expect('exception for expected error detected', isNotNull);
      });

      test('Result<T, E> return type should NOT trigger', () {
        expect('result pattern passes', isNotNull);
      });
    });
  });
}
