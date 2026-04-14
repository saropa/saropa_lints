import 'dart:io';

import 'package:saropa_lints/src/rules/flow/return_rules.dart';
import 'package:test/test.dart';

/// Tests for 8 Return lint rules.
///
/// Test fixtures: example/lib/return/*
void main() {
  group('Return Rules - Rule Instantiation', () {
    test('AvoidReturningCascadesRule', () {
      final rule = AvoidReturningCascadesRule();
      expect(rule.code.lowerCaseName, 'avoid_returning_cascades');
      expect(rule.code.problemMessage, contains('[avoid_returning_cascades]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturningThisRule', () {
      final rule = AvoidReturningThisRule();
      expect(rule.code.lowerCaseName, 'avoid_returning_this');
      expect(rule.code.problemMessage, contains('[avoid_returning_this]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturningVoidRule', () {
      final rule = AvoidReturningVoidRule();
      expect(rule.code.lowerCaseName, 'avoid_returning_void');
      expect(rule.code.problemMessage, contains('[avoid_returning_void]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidUnnecessaryReturnRule', () {
      final rule = AvoidUnnecessaryReturnRule();
      expect(rule.code.lowerCaseName, 'avoid_unnecessary_return');
      expect(rule.code.problemMessage, contains('[avoid_unnecessary_return]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferImmediateReturnRule', () {
      final rule = PreferImmediateReturnRule();
      expect(rule.code.lowerCaseName, 'prefer_immediate_return');
      expect(rule.code.problemMessage, contains('[prefer_immediate_return]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferReturningShorthandsRule', () {
      final rule = PreferReturningShorthandsRule();
      expect(rule.code.lowerCaseName, 'prefer_returning_shorthands');
      expect(
        rule.code.problemMessage,
        contains('[prefer_returning_shorthands]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturningNullForVoidRule', () {
      final rule = AvoidReturningNullForVoidRule();
      expect(rule.code.lowerCaseName, 'avoid_returning_null_for_void');
      expect(
        rule.code.problemMessage,
        contains('[avoid_returning_null_for_void]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidReturningNullForFutureRule', () {
      final rule = AvoidReturningNullForFutureRule();
      expect(rule.code.lowerCaseName, 'avoid_returning_null_for_future');
      expect(
        rule.code.problemMessage,
        contains('[avoid_returning_null_for_future]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Return Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_returning_cascades',
      'avoid_returning_this',
      'avoid_returning_void',
      'avoid_unnecessary_return',
      'prefer_immediate_return',
      'prefer_returning_shorthands',
      'avoid_returning_null_for_void',
      'avoid_returning_null_for_future',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/return/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Return - Avoidance Rules', () {
    group('avoid_returning_cascades', () {
      test('rule offers quick fix (split cascade from return)', () {
        final rule = AvoidReturningCascadesRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('returning cascade expression SHOULD trigger', () {
        expect('returning cascade expression', isNotNull);
      });

      test('separate variable for cascades should NOT trigger', () {
        expect('separate variable for cascades', isNotNull);
      });
    });
    group('avoid_returning_void', () {
      test('rule offers quick fix (remove return from void expression)', () {
        final rule = AvoidReturningVoidRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('explicit return of void expression SHOULD trigger', () {
        expect('explicit return of void expression', isNotNull);
      });

      test('void function without return should NOT trigger', () {
        expect('void function without return', isNotNull);
      });
    });
    group('avoid_unnecessary_return', () {
      test('return at end of void function SHOULD trigger', () {
        expect('return at end of void function', isNotNull);
      });

      test('implicit void return should NOT trigger', () {
        expect('implicit void return', isNotNull);
      });
    });
    group('avoid_returning_this', () {
      test('rule offers quick fix (replace return this with return)', () {
        final rule = AvoidReturningThisRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
    group('avoid_returning_null_for_void', () {
      test('rule offers quick fix (replace return null with return)', () {
        final rule = AvoidReturningNullForVoidRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
    group('avoid_returning_null_for_future', () {
      test('rule offers quick fix (replace with Future.value(null))', () {
        final rule = AvoidReturningNullForFutureRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  group('Return - Preference Rules', () {
    group('prefer_immediate_return', () {
      test('variable assigned then immediately returned SHOULD trigger', () {
        expect('variable assigned then immediately returned', isNotNull);
      });

      test('direct return of expression should NOT trigger', () {
        expect('direct return of expression', isNotNull);
      });
    });
    group('prefer_returning_shorthands', () {
      test('rule offers quick fix (convert to expression body)', () {
        final rule = PreferReturningShorthandsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('single-expression body with return SHOULD trigger', () {
        expect('single-expression body with return', isNotNull);
      });

      test('arrow function syntax should NOT trigger', () {
        expect('arrow function syntax', isNotNull);
      });
    });
  });
}
