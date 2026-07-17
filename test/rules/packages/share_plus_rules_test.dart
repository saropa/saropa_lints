import 'dart:io';

import 'package:saropa_lints/src/rules/packages/share_plus_rules.dart';
import 'package:test/test.dart';

/// Instantiation-pin tests for 5 share_plus lint rules.
///
/// These tests verify:
///   1. Each rule instantiates without error.
///   2. The rule code name matches the expected snake_case identifier.
///   3. The problem message starts with the `[rule_code]` prefix and is >200 chars.
///   4. A correction message is provided.
///
/// Test fixtures: example_packages/lib/share_plus/share_plus_fixture.dart
void main() {
  group('SharePlus Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(
          rule.code.problemMessage.length,
          greaterThan(200),
          reason:
              'Problem message must exceed 200 chars (includes {v1} suffix)',
        );
        expect(rule.code.correctionMessage, isNotNull);
        expect(
          rule.code.correctionMessage,
          isNotEmpty,
          reason: 'Correction message must not be empty',
        );
      });
    }

    testRule(
      'PreferSharePlusInstanceRule',
      'prefer_shareplus_instance',
      () => PreferSharePlusInstanceRule(),
    );

    testRule(
      'SharePlusMissingPositionOriginRule',
      'share_plus_missing_position_origin',
      () => SharePlusMissingPositionOriginRule(),
    );

    testRule(
      'SharePlusUncheckedResultRule',
      'share_plus_unchecked_result',
      () => SharePlusUncheckedResultRule(),
    );

    testRule(
      'SharePlusEmptyShareParamsRule',
      'share_plus_empty_share_params',
      () => SharePlusEmptyShareParamsRule(),
    );

    testRule(
      'SharePlusUriAndTextConflictRule',
      'share_plus_uri_and_text_conflict',
      () => SharePlusUriAndTextConflictRule(),
    );
  });

  group('SharePlus Rules - Fixture Verification', () {
    final fixtureDir = Directory('example_packages/lib/share_plus');

    // Auto-discover fixtures from disk so new files are verified

    // automatically — no manual list to maintain.

    final fixtures =
        fixtureDir
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .where((name) => name.endsWith('_fixture.dart'))
            .map((name) => name.replaceAll('_fixture.dart', ''))
            .toList()
          ..sort();

    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('\$fixture fixture exists', () {
        final file = File(
          'example_packages/lib/share_plus/${fixture}_fixture.dart',
        );

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('SharePlus Rules - Metadata', () {
    test('PreferSharePlusInstanceRule has fix generators', () {
      final rule = PreferSharePlusInstanceRule();
      expect(rule.fixGenerators, isNotEmpty);
    });

    test('SharePlusMissingPositionOriginRule has no fix generators', () {
      final rule = SharePlusMissingPositionOriginRule();
      // Report-only rule: the correct Rect requires widget context.
      expect(rule.fixGenerators, isEmpty);
    });

    test('SharePlusUncheckedResultRule has no fix generators', () {
      final rule = SharePlusUncheckedResultRule();
      // Report-only: correct handling depends on app logic.
      expect(rule.fixGenerators, isEmpty);
    });

    test('SharePlusEmptyShareParamsRule has no fix generators', () {
      final rule = SharePlusEmptyShareParamsRule();
      // Report-only: safe removal depends on whether ShareParams is passed
      // directly to share() or assigned to a variable used elsewhere.
      expect(rule.fixGenerators, isEmpty);
    });

    test('SharePlusUriAndTextConflictRule has no fix generators', () {
      final rule = SharePlusUriAndTextConflictRule();
      // Report-only for non-literal operands; literal-only fix is deferred.
      expect(rule.fixGenerators, isEmpty);
    });

    test('Migration rule severity is WARNING', () {
      final rule = PreferSharePlusInstanceRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'warning');
    });

    test('Empty params rule severity is ERROR', () {
      final rule = SharePlusEmptyShareParamsRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'error');
    });

    test('URI/text conflict rule severity is ERROR', () {
      final rule = SharePlusUriAndTextConflictRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'error');
    });

    test('Missing position origin rule severity is WARNING', () {
      final rule = SharePlusMissingPositionOriginRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'warning');
    });

    test('Unchecked result rule severity is INFO', () {
      final rule = SharePlusUncheckedResultRule();
      expect(rule.code.severity.displayName.toLowerCase(), 'info');
    });
  });
}
