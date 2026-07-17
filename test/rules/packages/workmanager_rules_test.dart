import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/workmanager_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 3 WorkManager lint rules.
///
/// Test fixtures: example_packages/lib/workmanager/*
void main() {
  group('Workmanager Rules - Rule Instantiation', () {
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
      'RequireWorkmanagerConstraintsRule',
      'require_workmanager_constraints',
      () => RequireWorkmanagerConstraintsRule(),
    );

    testRule(
      'RequireWorkmanagerResultReturnRule',
      'require_workmanager_result_return',
      () => RequireWorkmanagerResultReturnRule(),
    );

    testRule(
      'RequireWorkmanagerForBackgroundRule',
      'require_workmanager_for_background',
      () => RequireWorkmanagerForBackgroundRule(),
    );
  });

  group('WorkManager Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/workmanager');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/workmanager/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
