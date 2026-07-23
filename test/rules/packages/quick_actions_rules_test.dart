import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/packages/quick_actions_rules.dart';
import '../../helpers/fixture_discovery.dart';

/// Tests for 5 quick_actions lint rules.
///
/// Test fixtures: example_packages/lib/quick_actions/*
void main() {
  group('QuickActions Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(200));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'QuickActionsSetBeforeInitializeRule',
      'quick_actions_set_before_initialize',
      () => QuickActionsSetBeforeInitializeRule(),
    );

    testRule(
      'QuickActionsMissingInitializeRule',
      'quick_actions_missing_initialize',
      () => QuickActionsMissingInitializeRule(),
    );

    testRule(
      'QuickActionsEmptyShortcutTypeRule',
      'quick_actions_empty_shortcut_type',
      () => QuickActionsEmptyShortcutTypeRule(),
    );

    testRule(
      'QuickActionsEmptyLocalizedTitleRule',
      'quick_actions_empty_localized_title',
      () => QuickActionsEmptyLocalizedTitleRule(),
    );

    testRule(
      'QuickActionsFlutterAssetIconRule',
      'quick_actions_flutter_asset_icon',
      () => QuickActionsFlutterAssetIconRule(),
    );
  });

  group('QuickActions Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/quick_actions');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/quick_actions/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
