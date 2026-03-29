import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:saropa_lints/src/rules/widget/flutter_migration_widget_rules.dart';
import 'package:test/test.dart';

/// Tests for Flutter widget migration rules (super.key, chip delete InkWell).
///
/// Fixture: example/lib/flutter_migration_widget_rules_fixture.dart
void main() {
  group('Flutter migration widget rules - fixture', () {
    test('fixture file exists', () {
      expect(
        File(
          'example/lib/flutter_migration_widget_rules_fixture.dart',
        ).existsSync(),
        isTrue,
      );
    });
  });

  group('PreferSuperKeyRule', () {
    test('instantiates with expected metadata', () {
      final rule = PreferSuperKeyRule();
      expect(rule.code.lowerCaseName, 'prefer_super_key');
      expect(rule.code.problemMessage, contains('[prefer_super_key]'));
      expect(rule.code.problemMessage.length, greaterThan(80));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isNotEmpty);
      expect(rule.impact, LintImpact.medium);
    });
  });

  group('AvoidChipDeleteInkWellCircleBorderRule', () {
    test('instantiates with expected metadata', () {
      final rule = AvoidChipDeleteInkWellCircleBorderRule();
      expect(
        rule.code.lowerCaseName,
        'avoid_chip_delete_inkwell_circle_border',
      );
      expect(
        rule.code.problemMessage,
        contains('[avoid_chip_delete_inkwell_circle_border]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(80));
      expect(rule.code.correctionMessage, isNotNull);
      expect(rule.fixGenerators, isEmpty);
    });
  });
}
