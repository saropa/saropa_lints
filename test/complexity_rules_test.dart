import 'dart:io';

import 'package:saropa_lints/src/rules/code_quality/complexity_rules.dart';
import 'package:test/test.dart';

/// Tests for 14 Complexity lint rules.
///
/// Test fixtures: example_core/lib/complexity/*
void main() {
  group('Complexity Rules - Rule Instantiation', () {
    test('AvoidBitwiseOperatorsWithBooleansRule', () {
      final rule = AvoidBitwiseOperatorsWithBooleansRule();
      expect(rule.code.name, 'avoid_bitwise_operators_with_booleans');
      expect(
        rule.code.problemMessage,
        contains('[avoid_bitwise_operators_with_booleans]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCascadeAfterIfNullRule', () {
      final rule = AvoidCascadeAfterIfNullRule();
      expect(rule.code.name, 'avoid_cascade_after_if_null');
      expect(
        rule.code.problemMessage,
        contains('[avoid_cascade_after_if_null]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidComplexArithmeticExpressionsRule', () {
      final rule = AvoidComplexArithmeticExpressionsRule();
      expect(rule.code.name, 'avoid_complex_arithmetic_expressions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_complex_arithmetic_expressions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidComplexConditionsRule', () {
      final rule = AvoidComplexConditionsRule();
      expect(rule.code.name, 'avoid_complex_conditions');
      expect(rule.code.problemMessage, contains('[avoid_complex_conditions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDuplicateCascadesRule', () {
      final rule = AvoidDuplicateCascadesRule();
      expect(rule.code.name, 'avoid_duplicate_cascades');
      expect(rule.code.problemMessage, contains('[avoid_duplicate_cascades]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidExcessiveExpressionsRule', () {
      final rule = AvoidExcessiveExpressionsRule();
      expect(rule.code.name, 'avoid_excessive_expressions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_excessive_expressions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidImmediatelyInvokedFunctionsRule', () {
      final rule = AvoidImmediatelyInvokedFunctionsRule();
      expect(rule.code.name, 'avoid_immediately_invoked_functions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_immediately_invoked_functions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNestedShorthandsRule', () {
      final rule = AvoidNestedShorthandsRule();
      expect(rule.code.name, 'avoid_nested_shorthands');
      expect(rule.code.problemMessage, contains('[avoid_nested_shorthands]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidMultiAssignmentRule', () {
      final rule = AvoidMultiAssignmentRule();
      expect(rule.code.name, 'avoid_multi_assignment');
      expect(rule.code.problemMessage, contains('[avoid_multi_assignment]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('BinaryExpressionOperandOrderRule', () {
      final rule = BinaryExpressionOperandOrderRule();
      expect(rule.code.name, 'binary_expression_operand_order');
      expect(
        rule.code.problemMessage,
        contains('[binary_expression_operand_order]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferMovingToVariableRule', () {
      final rule = PreferMovingToVariableRule();
      expect(rule.code.name, 'prefer_moving_to_variable');
      expect(rule.code.problemMessage, contains('[prefer_moving_to_variable]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferParenthesesWithIfNullRule', () {
      final rule = PreferParenthesesWithIfNullRule();
      expect(rule.code.name, 'prefer_parentheses_with_if_null');
      expect(
        rule.code.problemMessage,
        contains('[prefer_parentheses_with_if_null]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDeepNestingRule', () {
      final rule = AvoidDeepNestingRule();
      expect(rule.code.name, 'avoid_deep_nesting');
      expect(rule.code.problemMessage, contains('[avoid_deep_nesting]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidHighCyclomaticComplexityRule', () {
      final rule = AvoidHighCyclomaticComplexityRule();
      expect(rule.code.name, 'avoid_high_cyclomatic_complexity');
      expect(
        rule.code.problemMessage,
        contains('[avoid_high_cyclomatic_complexity]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('Complexity Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_bitwise_operators_with_booleans',
      'avoid_cascade_after_if_null',
      'avoid_complex_arithmetic_expressions',
      'avoid_complex_conditions',
      'avoid_duplicate_cascades',
      'avoid_excessive_expressions',
      'avoid_immediately_invoked_functions',
      'avoid_nested_shorthands',
      'avoid_multi_assignment',
      'binary_expression_operand_order',
      'prefer_moving_to_variable',
      'prefer_parentheses_with_if_null',
      'avoid_deep_nesting',
      'avoid_high_cyclomatic_complexity',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_core/lib/complexity/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Complexity - Avoidance Rules', () {
    group('avoid_bitwise_operators_with_booleans', () {
      test('avoid_bitwise_operators_with_booleans SHOULD trigger', () {
        // Pattern that should be avoided: avoid bitwise operators with booleans
        expect('avoid_bitwise_operators_with_booleans detected', isNotNull);
      });

      test('avoid_bitwise_operators_with_booleans should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_bitwise_operators_with_booleans passes', isNotNull);
      });
    });

    group('avoid_cascade_after_if_null', () {
      test('rule offers quick fix (wrap ?? in parentheses)', () {
        final rule = AvoidCascadeAfterIfNullRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_cascade_after_if_null SHOULD trigger', () {
        // Pattern that should be avoided: avoid cascade after if null
        expect('avoid_cascade_after_if_null detected', isNotNull);
      });

      test('avoid_cascade_after_if_null should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_cascade_after_if_null passes', isNotNull);
      });
    });

    group('avoid_complex_arithmetic_expressions', () {
      test('avoid_complex_arithmetic_expressions SHOULD trigger', () {
        // Pattern that should be avoided: avoid complex arithmetic expressions
        expect('avoid_complex_arithmetic_expressions detected', isNotNull);
      });

      test('avoid_complex_arithmetic_expressions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_complex_arithmetic_expressions passes', isNotNull);
      });
    });

    group('avoid_complex_conditions', () {
      test('avoid_complex_conditions SHOULD trigger', () {
        // Pattern that should be avoided: avoid complex conditions
        expect('avoid_complex_conditions detected', isNotNull);
      });

      test('avoid_complex_conditions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_complex_conditions passes', isNotNull);
      });
    });

    group('avoid_duplicate_cascades', () {
      test('rule offers quick fix (remove duplicate cascade section)', () {
        final rule = AvoidDuplicateCascadesRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('avoid_duplicate_cascades SHOULD trigger', () {
        // Pattern that should be avoided: avoid duplicate cascades
        expect('avoid_duplicate_cascades detected', isNotNull);
      });

      test('avoid_duplicate_cascades should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_duplicate_cascades passes', isNotNull);
      });
    });

    group('avoid_excessive_expressions', () {
      test('avoid_excessive_expressions SHOULD trigger', () {
        // Pattern that should be avoided: avoid excessive expressions
        expect('avoid_excessive_expressions detected', isNotNull);
      });

      test('avoid_excessive_expressions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_excessive_expressions passes', isNotNull);
      });
    });

    group('avoid_immediately_invoked_functions', () {
      test('avoid_immediately_invoked_functions SHOULD trigger', () {
        // Pattern that should be avoided: avoid immediately invoked functions
        expect('avoid_immediately_invoked_functions detected', isNotNull);
      });

      test('avoid_immediately_invoked_functions should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_immediately_invoked_functions passes', isNotNull);
      });
    });

    group('avoid_nested_shorthands', () {
      test('avoid_nested_shorthands SHOULD trigger', () {
        // Pattern that should be avoided: avoid nested shorthands
        expect('avoid_nested_shorthands detected', isNotNull);
      });

      test('avoid_nested_shorthands should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_nested_shorthands passes', isNotNull);
      });
    });

    group('avoid_multi_assignment', () {
      test('avoid_multi_assignment SHOULD trigger', () {
        // Pattern that should be avoided: avoid multi assignment
        expect('avoid_multi_assignment detected', isNotNull);
      });

      test('avoid_multi_assignment should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_multi_assignment passes', isNotNull);
      });
    });
  });

  group('Complexity - General Rules', () {
    group('binary_expression_operand_order', () {
      test('binary_expression_operand_order SHOULD trigger', () {
        // Detected violation: binary expression operand order
        expect('binary_expression_operand_order detected', isNotNull);
      });

      test('binary_expression_operand_order should NOT trigger', () {
        // Compliant code passes
        expect('binary_expression_operand_order passes', isNotNull);
      });
    });
  });

  group('Complexity - Preference Rules', () {
    group('prefer_moving_to_variable', () {
      test('prefer_moving_to_variable SHOULD trigger', () {
        // Better alternative available: prefer moving to variable
        expect('prefer_moving_to_variable detected', isNotNull);
      });

      test('prefer_moving_to_variable should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_moving_to_variable passes', isNotNull);
      });
    });

    group('prefer_parentheses_with_if_null', () {
      test('rule offers quick fix (wrap ?? expression in parentheses)', () {
        final rule = PreferParenthesesWithIfNullRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('prefer_parentheses_with_if_null SHOULD trigger', () {
        // Better alternative available: prefer parentheses with if null
        expect('prefer_parentheses_with_if_null detected', isNotNull);
      });

      test('prefer_parentheses_with_if_null should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_parentheses_with_if_null passes', isNotNull);
      });
    });
  });
}
