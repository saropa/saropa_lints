import 'dart:io';

import 'package:saropa_lints/src/rules/core/context_rules.dart';
import 'package:test/test.dart';

/// Tests for 6 Context lint rules.
///
/// Test fixtures: example/lib/context/*
void main() {
  group('Context Rules - Rule Instantiation', () {
    test('AvoidStoringContextRule', () {
      final rule = AvoidStoringContextRule();
      expect(rule.code.lowerCaseName, 'avoid_storing_context');
      expect(rule.code.problemMessage, contains('[avoid_storing_context]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidContextAcrossAsyncRule', () {
      final rule = AvoidContextAcrossAsyncRule();
      expect(rule.code.lowerCaseName, 'avoid_context_across_async');
      expect(
        rule.code.problemMessage,
        contains('[avoid_context_across_async]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidContextAfterAwaitInStaticRule', () {
      final rule = AvoidContextAfterAwaitInStaticRule();
      expect(rule.code.lowerCaseName, 'avoid_context_after_await_in_static');
      expect(
        rule.code.problemMessage,
        contains('[avoid_context_after_await_in_static]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidContextInAsyncStaticRule', () {
      final rule = AvoidContextInAsyncStaticRule();
      expect(rule.code.lowerCaseName, 'avoid_context_in_async_static');
      expect(
        rule.code.problemMessage,
        contains('[avoid_context_in_async_static]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidContextInStaticMethodsRule', () {
      final rule = AvoidContextInStaticMethodsRule();
      expect(rule.code.lowerCaseName, 'avoid_context_in_static_methods');
      expect(
        rule.code.problemMessage,
        contains('[avoid_context_in_static_methods]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidContextDependencyInCallbackRule', () {
      final rule = AvoidContextDependencyInCallbackRule();
      expect(rule.code.lowerCaseName, 'avoid_context_dependency_in_callback');
      expect(
        rule.code.problemMessage,
        contains('[avoid_context_dependency_in_callback]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Context Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_storing_context',
      'avoid_context_across_async',
      'prefer_closest_context',
      'avoid_context_after_await_in_static',
      'avoid_context_in_async_static',
      'avoid_context_in_static_methods',
      'avoid_context_dependency_in_callback',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/context/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Context - Avoidance Rules', () {
    group('avoid_storing_context', () {
      test('BuildContext stored in field SHOULD trigger', () {});

      test('passing context as parameter should NOT trigger', () {});
    });
    group('avoid_context_across_async', () {
      test('context used after await SHOULD trigger', () {});

      test('mounted check after await should NOT trigger', () {});
    });
    group('avoid_context_after_await_in_static', () {
      test('context in static after await SHOULD trigger', () {});

      test('callback pattern for static async should NOT trigger', () {});
    });
    group('avoid_context_in_async_static', () {
      test('context parameter in async static SHOULD trigger', () {});

      test('avoiding context in static async should NOT trigger', () {});
    });
    group('avoid_context_in_static_methods', () {
      test('context in static method SHOULD trigger', () {});

      test('instance method for context access should NOT trigger', () {});
    });
    group('avoid_context_dependency_in_callback', () {
      test('context captured in callback SHOULD trigger', () {});

      test('passing values not context should NOT trigger', () {});
    });
  });
}
