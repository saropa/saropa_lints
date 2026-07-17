import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/data/money_rules.dart';

/// Tests for 2 Money/Currency lint rules.
///
/// Test fixtures: example/lib/money/*
void main() {
  group('Money Rules - Rule Instantiation', () {
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
      'AvoidDoubleForMoneyRule',
      'avoid_double_for_money',
      () => AvoidDoubleForMoneyRule(),
    );

    testRule(
      'RequireCurrencyCodeWithAmountRule',
      'require_currency_code_with_amount',
      () => RequireCurrencyCodeWithAmountRule(),
    );
  });

  group('Money/Currency Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/money');

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
        final file = File('example/lib/money/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
