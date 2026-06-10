import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/workmanager_rules.dart';

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
    final fixtures = [
      'require_workmanager_constraints',
      'require_workmanager_result_return',
      'require_workmanager_for_background',
    ];

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
