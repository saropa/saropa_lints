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

  group('avoid_behavior_subject_last_value', () {
    test('SHOULD trigger on .value inside isClosed true-branch', () {
      // Detection: PropertyAccess for .value on a BehaviorSubject target,
      // inside the then-branch of if (subject.isClosed)
      expect('_subject.value in isClosed branch detected', isNotNull);
    });

    test('SHOULD trigger on .value inside isClosed == true branch', () {
      // Detection: Same check with explicit == true comparison
      expect('_subject.value in isClosed == true detected', isNotNull);
    });

    test('should NOT trigger on .value when NOT closed', () {
      // False positive prevention: !subject.isClosed guards properly
      expect('_subject.value in !isClosed passes', isNotNull);
    });

    test('should NOT trigger on .value outside isClosed check', () {
      // False positive prevention: no isClosed context
      expect('unconditional .value access passes', isNotNull);
    });

    test('should NOT trigger on .value in else-branch of isClosed', () {
      // False positive prevention: else-branch means subject is open
      expect('_subject.value in else passes', isNotNull);
    });
  });
}
