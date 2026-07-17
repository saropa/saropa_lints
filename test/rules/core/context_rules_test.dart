import 'dart:io';

import 'package:saropa_lints/src/rules/core/context_rules.dart';
import 'package:test/test.dart';

/// Tests for 6 Context lint rules.
///
/// Test fixtures: example/lib/context/*
// BuildContext storage and async gap patterns in widget code.
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
    final fixtureDir = Directory('example/lib/context');

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
        final file = File('example/lib/context/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
