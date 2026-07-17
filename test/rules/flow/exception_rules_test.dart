import 'dart:io';

import 'package:saropa_lints/src/rules/flow/exception_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 5 Exception lint rules.
///
/// Test fixtures: example/lib/exception/*
void main() {
  group('Exception Rules - Rule Instantiation', () {
    test('AvoidNonFinalExceptionClassFieldsRule', () {
      final rule = AvoidNonFinalExceptionClassFieldsRule();
      expect(rule.code.lowerCaseName, 'avoid_non_final_exception_class_fields');
      expect(
        rule.code.problemMessage,
        contains('[avoid_non_final_exception_class_fields]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidOnlyRethrowRule', () {
      final rule = AvoidOnlyRethrowRule();
      expect(rule.code.lowerCaseName, 'avoid_only_rethrow');
      expect(rule.code.problemMessage, contains('[avoid_only_rethrow]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidThrowInCatchBlockRule', () {
      final rule = AvoidThrowInCatchBlockRule();
      expect(rule.code.lowerCaseName, 'avoid_throw_in_catch_block');
      expect(
        rule.code.problemMessage,
        contains('[avoid_throw_in_catch_block]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidThrowObjectsWithoutToStringRule', () {
      final rule = AvoidThrowObjectsWithoutToStringRule();
      expect(rule.code.lowerCaseName, 'avoid_throw_objects_without_tostring');
      expect(
        rule.code.problemMessage,
        contains('[avoid_throw_objects_without_tostring]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferPublicExceptionClassesRule', () {
      final rule = PreferPublicExceptionClassesRule();
      expect(rule.code.lowerCaseName, 'prefer_public_exception_classes');
      expect(
        rule.code.problemMessage,
        contains('[prefer_public_exception_classes]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Exception Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/exception');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/exception/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Exception - Avoidance Rules', () {
    group('avoid_only_rethrow', () {
      test('rule offers quick fix (remove try-catch that only rethrows)', () {
        final rule = AvoidOnlyRethrowRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });
}
