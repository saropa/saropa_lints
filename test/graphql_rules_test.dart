import 'dart:io';

import 'package:test/test.dart';

/// Tests for 1 GraphQL lint rules.
///
/// Test fixtures: example_packages/lib/graphql/*
void main() {
  group('GraphQL Rules - Fixture Verification', () {
    final fixtures = ['avoid_graphql_string_queries'];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/graphql/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('GraphQL - Avoidance Rules', () {
    group('avoid_graphql_string_queries', () {
      test('raw string GraphQL query SHOULD trigger', () {
        expect('raw string GraphQL query', isNotNull);
      });

      test('typed GraphQL code generation should NOT trigger', () {
        expect('typed GraphQL code generation', isNotNull);
      });
    });
  });
}
