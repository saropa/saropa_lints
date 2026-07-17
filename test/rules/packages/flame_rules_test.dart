import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/flame_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 2 Flame Engine lint rules.
///
/// Test fixtures: example_packages/lib/flame/*
void main() {
  group('Flame Rules - Rule Instantiation', () {
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
      'AvoidCreatingVectorInUpdateRule',
      'avoid_creating_vector_in_update',
      () => AvoidCreatingVectorInUpdateRule(),
    );

    testRule(
      'AvoidRedundantAsyncOnLoadRule',
      'avoid_redundant_async_on_load',
      () => AvoidRedundantAsyncOnLoadRule(),
    );
  });

  group('Flame Engine Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/flame');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_packages/lib/flame/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
