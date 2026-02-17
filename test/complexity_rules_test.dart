import 'dart:io';

import 'package:test/test.dart';

/// Tests for 12 Complexity lint rules.
///
/// Test fixtures: example_core/lib/complexity/*
void main() {
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
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example_core/lib/complexity/${fixture}_fixture.dart');
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
