import 'dart:io';

import 'package:saropa_lints/src/rules/flow/return_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 8 Return lint rules.
///
/// Test fixtures: example/lib/return/*
// Return value style (cascades, async gaps) with small focused examples.
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
    final fixtureDir = Directory('example/lib/return');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

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
    });
    group('avoid_returning_void', () {
      test('rule offers quick fix (remove return from void expression)', () {
        final rule = AvoidReturningVoidRule();
        expect(rule.fixGenerators, isNotEmpty);
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
}
