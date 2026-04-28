import 'dart:io';

import 'package:saropa_lints/src/rules/code_quality/complexity_rules.dart';
import 'package:test/test.dart';

/// Tests for 14 Complexity lint rules.
///
/// Test fixtures: example/lib/complexity/*
void main() {
  group('Complexity Rules - Rule Instantiation', () {
    test('AvoidBitwiseOperatorsWithBooleansRule', () {
      final rule = AvoidBitwiseOperatorsWithBooleansRule();
      expect(rule.code.lowerCaseName, 'avoid_bitwise_operators_with_booleans');
      expect(
        rule.code.problemMessage,
        contains('[avoid_bitwise_operators_with_booleans]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidCascadeAfterIfNullRule', () {
      final rule = AvoidCascadeAfterIfNullRule();
      expect(rule.code.lowerCaseName, 'avoid_cascade_after_if_null');
      expect(
        rule.code.problemMessage,
        contains('[avoid_cascade_after_if_null]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidComplexArithmeticExpressionsRule', () {
      final rule = AvoidComplexArithmeticExpressionsRule();
      expect(rule.code.lowerCaseName, 'avoid_complex_arithmetic_expressions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_complex_arithmetic_expressions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidComplexConditionsRule', () {
      final rule = AvoidComplexConditionsRule();
      expect(rule.code.lowerCaseName, 'avoid_complex_conditions');
      expect(rule.code.problemMessage, contains('[avoid_complex_conditions]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDuplicateCascadesRule', () {
      final rule = AvoidDuplicateCascadesRule();
      expect(rule.code.lowerCaseName, 'avoid_duplicate_cascades');
      expect(rule.code.problemMessage, contains('[avoid_duplicate_cascades]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidExcessiveExpressionsRule', () {
      final rule = AvoidExcessiveExpressionsRule();
      expect(rule.code.lowerCaseName, 'avoid_excessive_expressions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_excessive_expressions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidImmediatelyInvokedFunctionsRule', () {
      final rule = AvoidImmediatelyInvokedFunctionsRule();
      expect(rule.code.lowerCaseName, 'avoid_immediately_invoked_functions');
      expect(
        rule.code.problemMessage,
        contains('[avoid_immediately_invoked_functions]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidNestedShorthandsRule', () {
      final rule = AvoidNestedShorthandsRule();
      expect(rule.code.lowerCaseName, 'avoid_nested_shorthands');
      expect(rule.code.problemMessage, contains('[avoid_nested_shorthands]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidMultiAssignmentRule', () {
      final rule = AvoidMultiAssignmentRule();
      expect(rule.code.lowerCaseName, 'avoid_multi_assignment');
      expect(rule.code.problemMessage, contains('[avoid_multi_assignment]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('BinaryExpressionOperandOrderRule', () {
      final rule = BinaryExpressionOperandOrderRule();
      expect(rule.code.lowerCaseName, 'binary_expression_operand_order');
      expect(
        rule.code.problemMessage,
        contains('[binary_expression_operand_order]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferMovingToVariableRule', () {
      final rule = PreferMovingToVariableRule();
      expect(rule.code.lowerCaseName, 'prefer_moving_to_variable');
      expect(rule.code.problemMessage, contains('[prefer_moving_to_variable]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('PreferParenthesesWithIfNullRule', () {
      final rule = PreferParenthesesWithIfNullRule();
      expect(rule.code.lowerCaseName, 'prefer_parentheses_with_if_null');
      expect(
        rule.code.problemMessage,
        contains('[prefer_parentheses_with_if_null]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidDeepNestingRule', () {
      final rule = AvoidDeepNestingRule();
      expect(rule.code.lowerCaseName, 'avoid_deep_nesting');
      expect(rule.code.problemMessage, contains('[avoid_deep_nesting]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
    test('AvoidHighCyclomaticComplexityRule', () {
      final rule = AvoidHighCyclomaticComplexityRule();
      expect(rule.code.lowerCaseName, 'avoid_high_cyclomatic_complexity');
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
        final file = File('example/lib/complexity/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Complexity - Quick fix metadata', () {
    test('AvoidCascadeAfterIfNullRule exposes a fix', () {
      expect(AvoidCascadeAfterIfNullRule().fixGenerators, isNotEmpty);
    });

    test('AvoidDuplicateCascadesRule exposes a fix', () {
      expect(AvoidDuplicateCascadesRule().fixGenerators, isNotEmpty);
    });

    test('PreferParenthesesWithIfNullRule exposes a fix', () {
      expect(PreferParenthesesWithIfNullRule().fixGenerators, isNotEmpty);
    });
  });

  // Stub-only behavior tests removed; keep rule metadata and fixture checks.
}
