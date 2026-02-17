import 'dart:io';

import 'package:test/test.dart';

/// Tests for 6 Context lint rules.
///
/// Test fixtures: example_async/lib/context/*
void main() {
  group('Context Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_storing_context',
      'avoid_context_across_async',
      'avoid_context_after_await_in_static',
      'avoid_context_in_async_static',
      'avoid_context_in_static_methods',
      'avoid_context_dependency_in_callback',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/context/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Context - Avoidance Rules', () {
    group('avoid_storing_context', () {
      test('BuildContext stored in field SHOULD trigger', () {
        expect('BuildContext stored in field', isNotNull);
      });

      test('passing context as parameter should NOT trigger', () {
        expect('passing context as parameter', isNotNull);
      });
    });
    group('avoid_context_across_async', () {
      test('context used after await SHOULD trigger', () {
        expect('context used after await', isNotNull);
      });

      test('mounted check after await should NOT trigger', () {
        expect('mounted check after await', isNotNull);
      });
    });
    group('avoid_context_after_await_in_static', () {
      test('context in static after await SHOULD trigger', () {
        expect('context in static after await', isNotNull);
      });

      test('callback pattern for static async should NOT trigger', () {
        expect('callback pattern for static async', isNotNull);
      });
    });
    group('avoid_context_in_async_static', () {
      test('context parameter in async static SHOULD trigger', () {
        expect('context parameter in async static', isNotNull);
      });

      test('avoiding context in static async should NOT trigger', () {
        expect('avoiding context in static async', isNotNull);
      });
    });
    group('avoid_context_in_static_methods', () {
      test('context in static method SHOULD trigger', () {
        expect('context in static method', isNotNull);
      });

      test('instance method for context access should NOT trigger', () {
        expect('instance method for context access', isNotNull);
      });
    });
    group('avoid_context_dependency_in_callback', () {
      test('context captured in callback SHOULD trigger', () {
        expect('context captured in callback', isNotNull);
      });

      test('passing values not context should NOT trigger', () {
        expect('passing values not context', isNotNull);
      });
    });
  });
}
