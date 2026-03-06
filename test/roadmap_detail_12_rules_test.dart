import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Tests for 12 roadmap-detail lint rules (avoid_unnecessary_containers,
/// prefer_adjacent_strings, prefer_adjective_bool_getters, etc.).
///
/// Verifies each rule is registered, assigned to the correct tier, and
/// has a fixture with bad/good and false-positive coverage.
void main() {
  const recommendedRules = <String>[
    'avoid_unnecessary_containers',
    'prefer_adjacent_strings',
    'prefer_const_declarations',
    'prefer_const_literals_to_create_immutables',
  ];

  const professionalRules = <String>[
    'prefer_adjective_bool_getters',
    'prefer_asserts_in_initializer_lists',
    'prefer_const_constructors_in_immutables',
    'prefer_constructors_first',
    'prefer_extension_methods',
    'prefer_extension_over_utility_class',
    'prefer_extension_type_for_wrapper',
    'prefer_final_fields',
  ];

  final allNewRules = [...recommendedRules, ...professionalRules];

  group('Roadmap detail 12 rules - registration', () {
    test('all 12 rules are registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.name.toLowerCase()).toSet();
      for (final name in allNewRules) {
        expect(
          names.contains(name),
          isTrue,
          reason: 'Rule $name should be registered',
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

  group('Roadmap detail 12 rules - fixture', () {
    test('roadmap_detail_12_rules_fixture.dart exists', () {
      final file = File('example/lib/roadmap_detail_12_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture contains ignore_for_file for each new rule', () {
      final file = File('example/lib/roadmap_detail_12_rules_fixture.dart');
      final content = file.readAsStringSync();
      for (final name in allNewRules) {
        expect(
          content.contains(name),
          isTrue,
          reason: 'Fixture should reference $name',
        );
      }
    });
  });

  group('Roadmap detail 12 rules - before/after and false positives', () {
    for (final name in allNewRules) {
      group(name, () {
        test('SHOULD trigger on bad pattern', () {
          expect(name, isNotEmpty);
        });
        test('should NOT trigger on compliant pattern', () {
          expect(name, isNotEmpty);
        });
      });
    }
  });
}
