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
        expect(rule.code.lowerCaseName, codeName);
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
    final fixtureDir = Directory('example_packages/lib/graphql');

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
        final file = File(
          'example_packages/lib/graphql/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
