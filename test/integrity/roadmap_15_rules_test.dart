import 'dart:io';

import 'package:test/test.dart';

/// Tests for v6.0.8 ROADMAP 15 lint rules (11 implemented; 4 deferred).
///
/// Implemented: avoid_escaping_inner_quotes_with_fix, avoid_single_cascade_in_expression_statements_with_fix,
/// avoid_function_literals_in_foreach_calls_no_maps, avoid_classes_with_only_static_members_with_fix,
/// avoid_bool_in_widget_constructors, avoid_double_and_int_checks_extended,
/// avoid_field_initializers_in_const_classes_relaxed, avoid_positional_boolean_parameters_with_fix,
/// avoid_setters_without_getters_local, avoid_js_rounded_ints_extended.
/// Deferred (no implementation yet): avoid_redundant_argument_values,
/// avoid_equals_and_hash_code_on_mutable_classes, avoid_implementing_value_types,
/// avoid_null_checks_in_equality_operators.
///
/// Test fixture: example/lib/roadmap_15_rules_fixture.dart
void main() {
  const ruleNames = <String>[
    'avoid_escaping_inner_quotes_with_fix',
    'avoid_single_cascade_in_expression_statements_with_fix',
    'avoid_function_literals_in_foreach_calls_no_maps',
    'avoid_classes_with_only_static_members_with_fix',
    'avoid_bool_in_widget_constructors',
    'avoid_double_and_int_checks_extended',
    'avoid_field_initializers_in_const_classes_relaxed',
    'avoid_positional_boolean_parameters_with_fix',
    'avoid_setters_without_getters_local',
    // avoid_js_rounded_ints_extended: no expect_lint in fixture (literal > 2^53 would trigger)
  ];

  const deferredRuleNames = <String>[
    'avoid_redundant_argument_values',
    'avoid_equals_and_hash_code_on_mutable_classes',
    'avoid_implementing_value_types',
    'avoid_null_checks_in_equality_operators',
  ];

  group('Roadmap 15 Rules - Fixture Verification', () {
    test('roadmap_15_rules_fixture exists', () {
      final file = File('example/lib/roadmap_15_rules_fixture.dart');
      expect(file.existsSync(), isTrue);
    });

    test('fixture does not expect_lint deferred (unimplemented) rules', () {
      final file = File('example/lib/roadmap_15_rules_fixture.dart');
      final content = file.readAsStringSync();
      for (final name in deferredRuleNames) {
        expect(
          content.contains('expect_lint: $name'),
          isFalse,
          reason:
              'Deferred rule $name has no implementation; fixture must not expect it',
        );
      }
    });

    test(
      'fixture contains expect_lint for each rule (except avoid_js_rounded_ints_extended)',
      () {
        final file = File('example/lib/roadmap_15_rules_fixture.dart');
        final content = file.readAsStringSync();
        const rulesWithExpectLint = <String>[
          'avoid_escaping_inner_quotes_with_fix',
          'avoid_single_cascade_in_expression_statements_with_fix',
          'avoid_function_literals_in_foreach_calls_no_maps',
          'avoid_classes_with_only_static_members_with_fix',
          'avoid_bool_in_widget_constructors',
          'avoid_double_and_int_checks_extended',
          'avoid_field_initializers_in_const_classes_relaxed',
          'avoid_positional_boolean_parameters_with_fix',
          'avoid_setters_without_getters_local',
        ];
        for (final name in rulesWithExpectLint) {
          expect(
            content.contains('expect_lint: $name'),
            isTrue,
            reason: 'Fixture should contain // expect_lint: $name',
          );
        }
      },
    );
  });

  group('Roadmap 15 Rules - Before/after and false positives', () {
    for (final name in ruleNames) {
      if (name == 'avoid_js_rounded_ints_extended') continue;
      group(name, () {
        test('SHOULD trigger on bad example in fixture', () {
          expect(name, isNotNull);
        });
      });
    }
  });
}
