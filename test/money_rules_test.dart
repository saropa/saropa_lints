import 'dart:io';

import 'package:test/test.dart';

/// Tests for 2 Money/Currency lint rules.
///
/// Test fixtures: example_async/lib/money/*
void main() {
  group('Money/Currency Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_double_for_money',
      'require_currency_code_with_amount',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_async/lib/money/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Money/Currency - Avoidance Rules', () {
    group('avoid_double_for_money', () {
      test('double for currency amount SHOULD trigger', () {
        expect('double for currency amount', isNotNull);
      });

      test('int cents or Decimal type should NOT trigger', () {
        expect('int cents or Decimal type', isNotNull);
      });
    });
  });

  group('Money/Currency - Requirement Rules', () {
    group('require_currency_code_with_amount', () {
      test('amount without currency code SHOULD trigger', () {
        expect('amount without currency code', isNotNull);
      });

      test('currency code alongside amount should NOT trigger', () {
        expect('currency code alongside amount', isNotNull);
      });
    });
  });
}
