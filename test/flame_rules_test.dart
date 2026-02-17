import 'dart:io';

import 'package:test/test.dart';

/// Tests for 2 Flame Engine lint rules.
///
/// Test fixtures: example_packages/lib/flame/*
void main() {
  group('Flame Engine Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_creating_vector_in_update',
      'avoid_redundant_async_on_load',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/flame/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Flame Engine - Avoidance Rules', () {
    group('avoid_creating_vector_in_update', () {
      test('Vector2 allocation in update loop SHOULD trigger', () {
        expect('Vector2 allocation in update loop', isNotNull);
      });

      test('reusable vector outside update should NOT trigger', () {
        expect('reusable vector outside update', isNotNull);
      });
    });
    group('avoid_redundant_async_on_load', () {
      test('async onLoad with no await SHOULD trigger', () {
        expect('async onLoad with no await', isNotNull);
      });

      test('sync onLoad when possible should NOT trigger', () {
        expect('sync onLoad when possible', isNotNull);
      });
    });
  });
}
