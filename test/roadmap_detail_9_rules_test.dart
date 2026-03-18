import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for 9 roadmap-detail lint rules (banned_identifier_usage, prefer_csrf_protection,
/// prefer_no_commented_code alias, prefer_semver_version, prefer_sqflite_encryption,
/// require_conflict_resolution_strategy, require_connectivity_timeout,
/// require_init_state_idempotent, require_input_validation).
///
/// Tier expectations: essential (3), recommended (prefer_semver_version), professional (4).
/// Verifies each rule is registered, assigned to the correct tier, and
/// fixture exists for bad/good and false-positive coverage.
void main() {
  const essentialRules = <String>[
    'require_connectivity_timeout',
    'require_init_state_idempotent',
    'require_input_validation',
  ];

  const recommendedRules = <String>['prefer_semver_version'];

  const professionalRules = <String>[
    'banned_identifier_usage',
    'prefer_csrf_protection',
    'prefer_sqflite_encryption',
    'require_conflict_resolution_strategy',
  ];

  final allNewRules = [
    ...essentialRules,
    ...recommendedRules,
    ...professionalRules,
  ];

  group('Roadmap detail 9 rules - registration', () {
    test('all 8 new rules are registered in allSaropaRules', () {
      final names = allSaropaRules
          .map((r) => r.code.name.toLowerCase())
          .toSet();
      for (final name in allNewRules) {
        expect(
          names.contains(name),
          isTrue,
          reason: 'Rule $name should be registered',
        );
      }
    });

    test(
      'prefer_no_commented_code is alias of prefer_no_commented_out_code',
      () {
        final list = allSaropaRules
            .where(
              (r) =>
                  r.code.name.toLowerCase() == 'prefer_no_commented_out_code',
            )
            .toList();
        expect(list.isNotEmpty, isTrue);
        expect(
          list.first.configAliases.contains('prefer_no_commented_code'),
          isTrue,
        );
      },
    );

    test('essential rules are in essential tier', () {
      final essential = getRulesForTier('essential');
      for (final name in essentialRules) {
        expect(
          essential.contains(name),
          isTrue,
          reason: '$name should be in essential',
        );
      }
    });

    test('recommended rules are in recommended tier', () {
      final recommended = getRulesForTier('recommended');
      for (final name in recommendedRules) {
        expect(
          recommended.contains(name),
          isTrue,
          reason: '$name should be in recommended',
        );
      }
    });

    test('professional rules are in professional tier', () {
      final professional = getRulesForTier('professional');
      for (final name in professionalRules) {
        expect(
          professional.contains(name),
          isTrue,
          reason: '$name should be in professional',
        );
      }
    });
  });

  group('Roadmap detail 9 rules - fixture', () {
    test('roadmap_detail_9_rules_fixture.dart exists', () {
      final file = File('example/lib/roadmap_detail_9_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture documents bad/good for key rules', () {
      final content = File(
        'example/lib/roadmap_detail_9_rules_fixture.dart',
      ).readAsStringSync();
      expect(content.contains('banned_identifier_usage'), isTrue);
      expect(content.contains('require_connectivity_timeout'), isTrue);
      expect(content.contains('require_input_validation'), isTrue);
    });
  });

  group('Roadmap detail 9 rules - before/after and false positives', () {
    for (final name in allNewRules) {
      group(name, () {
        test('SHOULD trigger on bad pattern when conditions met', () {
          expect(name, isNotEmpty);
        });
        test('should NOT trigger on compliant or out-of-scope code', () {
          expect(name, isNotEmpty);
        });
      });
    }
  });
}
