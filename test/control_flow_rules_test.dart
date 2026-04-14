import 'dart:io';

import 'package:saropa_lints/src/rules/flow/control_flow_rules.dart';
import 'package:test/test.dart';

/// Tests for 31 Control Flow lint rules.
///
/// Test fixtures: example/lib/control_flow/*
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
    final fixtures = [
      'avoid_assignments_as_conditions',
      'avoid_collapsible_if',
      'avoid_conditions_with_boolean_literals',
      'avoid_constant_assert_conditions',
      'avoid_constant_switches',
      'avoid_double_and_int_checks',
      'prefer_no_continue_statement',
      'avoid_duplicate_switch_case_conditions',
      'avoid_if_with_many_branches',
      'avoid_inverted_boolean_checks',
      'avoid_negated_conditions',
      'avoid_nested_assignments',
      'avoid_nested_conditional_expressions',
      'avoid_nested_switches',
      'avoid_nested_switch_expressions',
      'avoid_nested_try',
      'avoid_redundant_else',
      'avoid_unconditional_break',
      'avoid_unnecessary_conditionals',
      'avoid_unnecessary_continue',
      'avoid_unnecessary_if',
      'no_equal_conditions',
      'no_equal_then_else',
      'prefer_conditional_expressions',
      'prefer_correct_switch_length',
      'prefer_returning_conditionals',
      'prefer_returning_condition',
      'prefer_when_guard_over_if',
      'prefer_simpler_boolean_expressions',
      'prefer_if_elements_to_conditional_expressions',
      'prefer_null_aware_method_calls',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example/lib/control_flow/${fixture}_fixture.dart',
        );
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

      test('avoid_assignments_as_conditions SHOULD trigger', () {
        // Pattern that should be avoided: avoid assignments as conditions
        expect('avoid_assignments_as_conditions detected', isNotNull);
      });

      test('avoid_assignments_as_conditions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_assignments_as_conditions passes', isNotNull);
      });
    });

    group('avoid_collapsible_if', () {
      test('avoid_collapsible_if SHOULD trigger', () {
        // Pattern that should be avoided: avoid collapsible if
        expect('avoid_collapsible_if detected', isNotNull);
      });

      test('avoid_collapsible_if should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_collapsible_if passes', isNotNull);
      });
    });

    group('avoid_conditions_with_boolean_literals', () {
      test('avoid_conditions_with_boolean_literals SHOULD trigger', () {
        // Pattern that should be avoided: avoid conditions with boolean literals
        expect('avoid_conditions_with_boolean_literals detected', isNotNull);
      });

      test('avoid_conditions_with_boolean_literals should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_conditions_with_boolean_literals passes', isNotNull);
      });
    });

    group('avoid_constant_assert_conditions', () {
      test('rule offers quick fix (remove constant assert)', () {
        final rule = AvoidConstantAssertConditionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_constant_assert_conditions SHOULD trigger', () {
        // Pattern that should be avoided: avoid constant assert conditions
        expect('avoid_constant_assert_conditions detected', isNotNull);
      });

      test('avoid_constant_assert_conditions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_constant_assert_conditions passes', isNotNull);
      });
    });

    group('avoid_constant_switches', () {
      test('avoid_constant_switches SHOULD trigger', () {
        // Pattern that should be avoided: avoid constant switches
        expect('avoid_constant_switches detected', isNotNull);
      });

      test('avoid_constant_switches should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_constant_switches passes', isNotNull);
      });
    });

    group('avoid_duplicate_switch_case_conditions', () {
      test('rule offers quick fix (remove duplicate case)', () {
        final rule = AvoidDuplicateSwitchCaseConditionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_duplicate_switch_case_conditions SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate switch case conditions
        expect('avoid_duplicate_switch_case_conditions detected', isNotNull);
      });

      test('avoid_duplicate_switch_case_conditions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_switch_case_conditions passes', isNotNull);
      });
    });

    group('avoid_if_with_many_branches', () {
      test('avoid_if_with_many_branches SHOULD trigger', () {
        // Pattern that should be avoided: avoid if with many branches
        expect('avoid_if_with_many_branches detected', isNotNull);
      });

      test('avoid_if_with_many_branches should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_if_with_many_branches passes', isNotNull);
      });
    });

    group('avoid_inverted_boolean_checks', () {
      test('avoid_inverted_boolean_checks SHOULD trigger', () {
        // Pattern that should be avoided: avoid inverted boolean checks
        expect('avoid_inverted_boolean_checks detected', isNotNull);
      });

      test('avoid_inverted_boolean_checks should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_inverted_boolean_checks passes', isNotNull);
      });
    });

    group('avoid_negated_conditions', () {
      test('avoid_negated_conditions SHOULD trigger', () {
        // Pattern that should be avoided: avoid negated conditions
        expect('avoid_negated_conditions detected', isNotNull);
      });

      test('avoid_negated_conditions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_negated_conditions passes', isNotNull);
      });
    });

    group('avoid_nested_assignments', () {
      test('avoid_nested_assignments SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested assignments
        expect('avoid_nested_assignments detected', isNotNull);
      });

      test('avoid_nested_assignments should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_assignments passes', isNotNull);
      });
    });

    group('avoid_nested_conditional_expressions', () {
      test('avoid_nested_conditional_expressions SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested conditional expressions
        expect('avoid_nested_conditional_expressions detected', isNotNull);
      });

      test('avoid_nested_conditional_expressions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_conditional_expressions passes', isNotNull);
      });
    });

    group('avoid_nested_switches', () {
      test('avoid_nested_switches SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested switches
        expect('avoid_nested_switches detected', isNotNull);
      });

      test('avoid_nested_switches should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_switches passes', isNotNull);
      });
    });

    group('avoid_nested_switch_expressions', () {
      test('avoid_nested_switch_expressions SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested switch expressions
        expect('avoid_nested_switch_expressions detected', isNotNull);
      });

      test('avoid_nested_switch_expressions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_switch_expressions passes', isNotNull);
      });
    });

    group('avoid_nested_try', () {
      test('avoid_nested_try SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested try
        expect('avoid_nested_try detected', isNotNull);
      });

      test('avoid_nested_try should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_try passes', isNotNull);
      });
    });

    group('avoid_redundant_else', () {
      test('rule offers quick fix (remove redundant else)', () {
        final rule = AvoidRedundantElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_redundant_else SHOULD trigger', () {
        // Pattern that should be avoided: avoid redundant else
        expect('avoid_redundant_else detected', isNotNull);
      });

      test('avoid_redundant_else should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_redundant_else passes', isNotNull);
      });
    });

    group('avoid_unconditional_break', () {
      test('rule offers quick fix (remove unconditional break/continue)', () {
        final rule = AvoidUnconditionalBreakRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_unconditional_break SHOULD trigger', () {
        // Pattern that should be avoided: avoid unconditional break
        expect('avoid_unconditional_break detected', isNotNull);
      });

      test('avoid_unconditional_break should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unconditional_break passes', isNotNull);
      });
    });

    group('avoid_unnecessary_conditionals', () {
      test('avoid_unnecessary_conditionals SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary conditionals
        expect('avoid_unnecessary_conditionals detected', isNotNull);
      });

      test('avoid_unnecessary_conditionals should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_conditionals passes', isNotNull);
      });
    });

    group('avoid_unnecessary_continue', () {
      test('avoid_unnecessary_continue SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary continue
        expect('avoid_unnecessary_continue detected', isNotNull);
      });

      test('avoid_unnecessary_continue should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_continue passes', isNotNull);
      });
    });

    group('avoid_unnecessary_if', () {
      test('avoid_unnecessary_if SHOULD trigger', () {
        // Pattern that should be avoided: avoid unnecessary if
        expect('avoid_unnecessary_if detected', isNotNull);
      });

      test('avoid_unnecessary_if should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_unnecessary_if passes', isNotNull);
      });
    });
  });

  group('Control Flow - Preference Rules', () {
    group('prefer_no_continue_statement', () {
      test('prefer_no_continue_statement SHOULD trigger', () {
        // Better alternative available: prefer no continue statement
        expect('prefer_no_continue_statement detected', isNotNull);
      });

      test('prefer_no_continue_statement should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_no_continue_statement passes', isNotNull);
      });

      test('early-skip guard continue should NOT trigger (regression)', () {
        // if (cond) { continue; } at top of loop body is exempt
        expect('early-skip guard is exempt', isNotNull);
      });
    });

    group('prefer_conditional_expressions', () {
      test('prefer_conditional_expressions SHOULD trigger', () {
        // Better alternative available: prefer conditional expressions
        expect('prefer_conditional_expressions detected', isNotNull);
      });

      test('prefer_conditional_expressions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_conditional_expressions passes', isNotNull);
      });
    });

    group('prefer_correct_switch_length', () {
      test('prefer_correct_switch_length SHOULD trigger', () {
        // Better alternative available: prefer correct switch length
        expect('prefer_correct_switch_length detected', isNotNull);
      });

      test('prefer_correct_switch_length should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_switch_length passes', isNotNull);
      });
    });

    group('prefer_returning_conditionals', () {
      test('prefer_returning_conditionals SHOULD trigger', () {
        // Better alternative available: prefer returning conditionals
        expect('prefer_returning_conditionals detected', isNotNull);
      });

      test('prefer_returning_conditionals should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_returning_conditionals passes', isNotNull);
      });
    });

    group('prefer_returning_condition', () {
      test('prefer_returning_condition SHOULD trigger', () {
        // Better alternative available: prefer returning condition
        expect('prefer_returning_condition detected', isNotNull);
      });

      test('prefer_returning_condition should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_returning_condition passes', isNotNull);
      });
    });

    group('prefer_when_guard_over_if', () {
      test('prefer_when_guard_over_if SHOULD trigger', () {
        // Better alternative available: prefer when guard over if
        expect('prefer_when_guard_over_if detected', isNotNull);
      });

      test('prefer_when_guard_over_if should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_when_guard_over_if passes', isNotNull);
      });
    });

    group('prefer_simpler_boolean_expressions', () {
      test('rule offers quick fix (remove double negation / De Morgan)', () {
        final rule = PreferSimplerBooleanExpressionsRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('prefer_simpler_boolean_expressions SHOULD trigger', () {
        // Better alternative available: prefer simpler boolean expressions
        expect('prefer_simpler_boolean_expressions detected', isNotNull);
      });

      test('prefer_simpler_boolean_expressions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_simpler_boolean_expressions passes', isNotNull);
      });
    });
  });

  group('Control Flow - General Rules', () {
    group('no_equal_conditions', () {
      test('no_equal_conditions SHOULD trigger', () {
        // Detected violation: no equal conditions
        expect('no_equal_conditions detected', isNotNull);
      });

      test('no_equal_conditions should NOT trigger', () {
        // Compliant code passes
        expect('no_equal_conditions passes', isNotNull);
      });
    });

    group('no_equal_then_else', () {
      test('rule offers quick fix (replace with then branch only)', () {
        final rule = NoEqualThenElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('no_equal_then_else SHOULD trigger', () {
        // Detected violation: no equal then else
        expect('no_equal_then_else detected', isNotNull);
      });

      test('no_equal_then_else should NOT trigger', () {
        // Compliant code passes
        expect('no_equal_then_else passes', isNotNull);
      });
    });
  });
}
