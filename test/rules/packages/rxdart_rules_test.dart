import 'dart:io';

import 'package:saropa_lints/src/rules/packages/rxdart_rules.dart';
import 'package:test/test.dart';

/// Tests for 1 RxDart lint rule.
///
/// Rules:
///   - avoid_behavior_subject_last_value (Comprehensive, WARNING)
///
/// Test fixtures: example_packages/lib/rxdart/*
void main() {
  group('RxDart Rules - Fixture Verification', () {
    test('avoid_behavior_subject_last_value fixture exists', () {
      final file = File(
        'example_packages/lib/rxdart/'
        'avoid_behavior_subject_last_value_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
    });
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
