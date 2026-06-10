import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/windows_rules.dart';

/// Tests for 5 Windows lint rules.
///
/// Test fixtures: example/lib/windows/
void main() {
  group('Windows Rules - Rule Instantiation', () {
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
      'AvoidHardcodedDriveLettersRule',
      'avoid_hardcoded_drive_letters',
      () => AvoidHardcodedDriveLettersRule(),
    );

    testRule(
      'AvoidForwardSlashPathAssumptionRule',
      'avoid_forward_slash_path_assumption',
      () => AvoidForwardSlashPathAssumptionRule(),
    );

    testRule(
      'AvoidCaseSensitivePathComparisonRule',
      'avoid_case_sensitive_path_comparison',
      () => AvoidCaseSensitivePathComparisonRule(),
    );

    testRule(
      'RequireWindowsSingleInstanceCheckRule',
      'require_windows_single_instance_check',
      () => RequireWindowsSingleInstanceCheckRule(),
    );

    testRule(
      'AvoidMaxPathRiskRule',
      'avoid_max_path_risk',
      () => AvoidMaxPathRiskRule(),
    );
  });

  group('Windows Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hardcoded_drive_letters',
      'avoid_forward_slash_path_assumption',
      'avoid_case_sensitive_path_comparison',
      'require_windows_single_instance_check',
      'avoid_max_path_risk',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/windows/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });
}
