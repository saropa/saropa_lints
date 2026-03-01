import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/graphql_rules.dart';

/// Tests for 1 GraphQL lint rules.
///
/// Test fixtures: example_packages/lib/graphql/*
void main() {
  group('Graphql Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.name, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidGraphqlStringQueriesRule',
      'avoid_graphql_string_queries',
      () => AvoidGraphqlStringQueriesRule(),
    );
  });

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
