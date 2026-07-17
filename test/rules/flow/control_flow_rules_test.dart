import 'dart:io';

import 'package:saropa_lints/src/rules/flow/control_flow_rules.dart';
import 'package:test/test.dart';

/// Tests for 31 Control Flow lint rules.
///
/// Test fixtures: example/lib/control_flow/*
// Loops, early return, and guard-style control flow; example fixtures for LINTs.
void main() {
  group('Control Flow Rules - Rule Instantiation', () {
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
      'AvoidAssignmentsAsConditionsRule',
      'avoid_assignments_as_conditions',
      () => AvoidAssignmentsAsConditionsRule(),
    );
    testRule(
      'AvoidCollapsibleIfRule',
      'avoid_collapsible_if',
      () => AvoidCollapsibleIfRule(),
    );
    testRule(
      'AvoidConditionsWithBooleanLiteralsRule',
      'avoid_conditions_with_boolean_literals',
      () => AvoidConditionsWithBooleanLiteralsRule(),
    );
    testRule(
      'AvoidConstantAssertConditionsRule',
      'avoid_constant_assert_conditions',
      () => AvoidConstantAssertConditionsRule(),
    );
    testRule(
      'AvoidConstantSwitchesRule',
      'avoid_constant_switches',
      () => AvoidConstantSwitchesRule(),
    );
    testRule(
      'AvoidContinueRule',
      'prefer_no_continue_statement',
      () => AvoidContinueRule(),
    );
    testRule(
      'AvoidDuplicateSwitchCaseConditionsRule',
      'avoid_duplicate_switch_case_conditions',
      () => AvoidDuplicateSwitchCaseConditionsRule(),
    );
    testRule(
      'AvoidIfWithManyBranchesRule',
      'avoid_if_with_many_branches',
      () => AvoidIfWithManyBranchesRule(),
    );
    testRule(
      'AvoidInvertedBooleanChecksRule',
      'avoid_inverted_boolean_checks',
      () => AvoidInvertedBooleanChecksRule(),
    );
    testRule(
      'AvoidNegatedConditionsRule',
      'avoid_negated_conditions',
      () => AvoidNegatedConditionsRule(),
    );
    testRule(
      'AvoidNestedAssignmentsRule',
      'avoid_nested_assignments',
      () => AvoidNestedAssignmentsRule(),
    );
    testRule(
      'AvoidNestedConditionalExpressionsRule',
      'avoid_nested_conditional_expressions',
      () => AvoidNestedConditionalExpressionsRule(),
    );
    testRule(
      'AvoidNestedSwitchesRule',
      'avoid_nested_switches',
      () => AvoidNestedSwitchesRule(),
    );
    testRule(
      'AvoidNestedSwitchExpressionsRule',
      'avoid_nested_switch_expressions',
      () => AvoidNestedSwitchExpressionsRule(),
    );
    testRule(
      'AvoidNestedTryRule',
      'avoid_nested_try',
      () => AvoidNestedTryRule(),
    );
    testRule(
      'AvoidRedundantElseRule',
      'avoid_redundant_else',
      () => AvoidRedundantElseRule(),
    );
    testRule(
      'AvoidUnconditionalBreakRule',
      'avoid_unconditional_break',
      () => AvoidUnconditionalBreakRule(),
    );
    testRule(
      'AvoidUnnecessaryConditionalsRule',
      'avoid_unnecessary_conditionals',
      () => AvoidUnnecessaryConditionalsRule(),
    );
    testRule(
      'AvoidUnnecessaryContinueRule',
      'avoid_unnecessary_continue',
      () => AvoidUnnecessaryContinueRule(),
    );
    testRule(
      'AvoidUnnecessaryIfRule',
      'avoid_unnecessary_if',
      () => AvoidUnnecessaryIfRule(),
    );
    testRule(
      'NoEqualConditionsRule',
      'no_equal_conditions',
      () => NoEqualConditionsRule(),
    );
    testRule(
      'NoEqualThenElseRule',
      'no_equal_then_else',
      () => NoEqualThenElseRule(),
    );
    testRule(
      'PreferConditionalExpressionsRule',
      'prefer_conditional_expressions',
      () => PreferConditionalExpressionsRule(),
    );
    testRule(
      'PreferCorrectSwitchLengthRule',
      'prefer_correct_switch_length',
      () => PreferCorrectSwitchLengthRule(),
    );
    testRule(
      'PreferReturningConditionalsRule',
      'prefer_returning_conditionals',
      () => PreferReturningConditionalsRule(),
    );
    testRule(
      'PreferReturningConditionRule',
      'prefer_returning_condition',
      () => PreferReturningConditionRule(),
    );
    testRule(
      'PreferWhenGuardOverIfRule',
      'prefer_when_guard_over_if',
      () => PreferWhenGuardOverIfRule(),
    );
    testRule(
      'PreferSimplerBooleanExpressionsRule',
      'prefer_simpler_boolean_expressions',
      () => PreferSimplerBooleanExpressionsRule(),
    );
    testRule(
      'AvoidDoubleAndIntChecksRule',
      'avoid_double_and_int_checks',
      () => AvoidDoubleAndIntChecksRule(),
    );
    testRule(
      'PreferIfElementsToConditionalExpressionsRule',
      'prefer_if_elements_to_conditional_expressions',
      () => PreferIfElementsToConditionalExpressionsRule(),
    );
    testRule(
      'PreferNullAwareMethodCallsRule',
      'prefer_null_aware_method_calls',
      () => PreferNullAwareMethodCallsRule(),
    );
  });

  group('Control Flow Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/control_flow');

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
        final file = File('example/lib/control_flow/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Control Flow - Avoidance Rules', () {
    group('avoid_assignments_as_conditions', () {
      test('rule offers quick fix (replace = with ==)', () {
        final rule = AvoidAssignmentsAsConditionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_constant_assert_conditions', () {
      test('rule offers quick fix (remove constant assert)', () {
        final rule = AvoidConstantAssertConditionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_duplicate_switch_case_conditions', () {
      test('rule offers quick fix (remove duplicate case)', () {
        final rule = AvoidDuplicateSwitchCaseConditionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_redundant_else', () {
      test('rule offers quick fix (remove redundant else)', () {
        final rule = AvoidRedundantElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('avoid_unconditional_break', () {
      test('rule offers quick fix (remove unconditional break/continue)', () {
        final rule = AvoidUnconditionalBreakRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  group('Control Flow - Preference Rules', () {
    group('prefer_simpler_boolean_expressions', () {
      test('rule offers quick fix (remove double negation / De Morgan)', () {
        final rule = PreferSimplerBooleanExpressionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  group('Control Flow - General Rules', () {
    group('no_equal_then_else', () {
      test('rule offers quick fix (replace with then branch only)', () {
        final rule = NoEqualThenElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata,
  // fixture verification, and targeted quick-fix metadata checks.
}
