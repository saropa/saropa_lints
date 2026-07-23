import 'dart:io';

import 'package:saropa_lints/src/rules/packages/rxdart_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 1 RxDart lint rule.
///
/// Rules:
///   - avoid_behavior_subject_last_value (Comprehensive, WARNING)
///
/// Test fixtures: example_packages/lib/rxdart/*
void main() {
  group('RxDart Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/rxdart');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);
      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/rxdart/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('RxDart Rules - Rule Instantiation', () {
    test('AvoidBehaviorSubjectLastValueRule instantiates correctly', () {
      final rule = AvoidBehaviorSubjectLastValueRule();
      expect(rule.code.lowerCaseName, 'avoid_behavior_subject_last_value');
      expect(
        rule.code.problemMessage,
        contains('[avoid_behavior_subject_last_value]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
