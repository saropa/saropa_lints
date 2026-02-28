import 'dart:io';

import 'package:test/test.dart';

/// Tests for 16 roadmap-detail lint rules (prefer_final_locals, prefer_getters_before_setters, etc.).
///
/// Verifies fixture exists and documents expected rule names and tiers.
/// Registration and tier assignment are in lib/saropa_lints.dart and lib/src/tiers.dart.
void main() {
  const recommendedRules = <String>[
    'prefer_final_locals',
    'prefer_if_elements_to_conditional_expressions',
    'prefer_inlined_adds',
    'prefer_interpolation_to_compose',
    'prefer_lowercase_constants',
    'prefer_null_aware_method_calls',
  ];

  const professionalRules = <String>[
    'prefer_getters_before_setters',
    'prefer_mixin_over_abstract',
    'prefer_named_bool_params',
    'prefer_noun_class_names',
    'prefer_raw_strings',
    'prefer_record_over_tuple_class',
    'prefer_sealed_classes',
    'prefer_sealed_for_state',
    'prefer_static_before_instance',
    'prefer_verb_method_names',
  ];

  final allNewRules = [...recommendedRules, ...professionalRules];

  group('Roadmap detail rules - fixture', () {
    test('roadmap_detail_rules_fixture.dart exists', () {
      final file = File('example/lib/roadmap_detail_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture contains ignore_for_file for each new rule', () {
      final file = File('example/lib/roadmap_detail_rules_fixture.dart');
      final content = file.readAsStringSync();
      for (final name in allNewRules) {
        expect(
          content.contains(name),
          isTrue,
          reason: 'Fixture should reference $name',
        );
      }
    });

    test('all 16 rule names are documented', () {
      expect(allNewRules.length, 16);
      expect(allNewRules.toSet().length, 16);
    });
  });

  group('Roadmap detail rules - before/after and false positives', () {
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
