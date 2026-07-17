import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/data/money_rules.dart';
import '../../helpers/fixture_discovery.dart';

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
    final fixtures = discoverFixtures(fixtureDir);
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
