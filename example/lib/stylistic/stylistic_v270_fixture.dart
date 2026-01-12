// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: avoid_unnecessary_containers, unused_element
// ignore_for_file: dead_code, unreachable_from_main
// ignore_for_file: unnecessary_null_comparison, dead_null_aware_expression

/// Fixture file for stylistic rules added in v2.7.0.
/// These are opinionated rules not included in any tier by default.

// =============================================================================
// NULL & COLLECTION STYLE RULES
// =============================================================================

class NullCollectionExamples {
  // --- prefer_if_null_operator / prefer_ternary_over_if_null ---

  // BAD: Ternary null check (prefer_if_null_operator)
  // expect_lint: prefer_if_null_operator
  String getTernaryNull(String? value) {
    return value != null ? value : 'default';
  }

  // GOOD: Using ?? operator
  String getIfNull(String? value) {
    return value ?? 'default';
  }

  // --- prefer_null_aware_assignment / prefer_explicit_null_assignment ---

  void nullAwareAssignment() {
    String? name;

    // BAD: Explicit null check assignment (prefer_null_aware_assignment)
    // expect_lint: prefer_null_aware_assignment
    if (name == null) {
      name = 'default';
    }

    // GOOD: ??= operator
    name ??= 'default';
  }

  // --- prefer_spread_operator / prefer_add_all_over_spread ---

  void spreadOperator() {
    final list1 = [1, 2, 3];
    final list2 = [4, 5, 6];

    // BAD: Using addAll (prefer_spread_operator)
    // expect_lint: prefer_spread_operator
    final combined1 = <int>[];
    combined1.addAll(list1);
    combined1.addAll(list2);

    // GOOD: Using spread
    final combined2 = [...list1, ...list2];
  }

  // --- prefer_collection_literals / prefer_constructor_over_literal ---

  void collectionLiterals() {
    // BAD: Constructor call (prefer_collection_literals)
    // expect_lint: prefer_collection_literals
    final list1 = List<int>.empty(growable: true);

    // GOOD: Literal syntax
    final list2 = <int>[];
    final map = <String, int>{};
    final set = <int>{};
  }

  // --- prefer_cascade_notation / prefer_separate_calls_over_cascade ---

  void cascadeNotation() {
    final buffer = StringBuffer();

    // BAD: Separate calls (prefer_cascade_notation)
    // expect_lint: prefer_cascade_notation
    buffer.write('Hello');
    buffer.write(' ');
    buffer.write('World');

    // GOOD: Cascade notation
    StringBuffer()
      ..write('Hello')
      ..write(' ')
      ..write('World');
  }
}

// =============================================================================
// CONTROL FLOW STYLE RULES
// =============================================================================

class ControlFlowExamples {
  // --- prefer_early_return / prefer_single_exit_point ---

  // BAD: Nested if (prefer_early_return)
  // expect_lint: prefer_early_return
  String processNestedIf(String? input) {
    if (input != null) {
      if (input.isNotEmpty) {
        if (input.length > 3) {
          return input.toUpperCase();
        }
      }
    }
    return '';
  }

  // GOOD: Early return
  String processEarlyReturn(String? input) {
    if (input == null) return '';
    if (input.isEmpty) return '';
    if (input.length <= 3) return '';
    return input.toUpperCase();
  }

  // --- prefer_ternary_over_if_else / prefer_if_else_over_ternary ---

  // BAD: if-else for simple assignment (prefer_ternary_over_if_else)
  // expect_lint: prefer_ternary_over_if_else
  String getStatusIfElse(bool isActive) {
    if (isActive) {
      return 'Active';
    } else {
      return 'Inactive';
    }
  }

  // GOOD: Ternary
  String getStatusTernary(bool isActive) {
    return isActive ? 'Active' : 'Inactive';
  }

  // --- prefer_switch_expression / prefer_switch_statement_over_expression ---

  // BAD: Switch statement (prefer_switch_expression)
  // expect_lint: prefer_switch_expression
  String getDayNameStatement(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      default:
        return 'Unknown';
    }
  }

  // GOOD: Switch expression
  String getDayNameExpression(int day) => switch (day) {
    1 => 'Monday',
    2 => 'Tuesday',
    _ => 'Unknown',
  };
}

// =============================================================================
// WHITESPACE & CONSTRUCTOR STYLE RULES
// =============================================================================

// --- prefer_blank_line_before_return ---

// BAD: No blank line before return (prefer_blank_line_before_return)
// expect_lint: prefer_blank_line_before_return
int calculateNoBlankLine(int a, int b) {
  final sum = a + b;
  final product = a * b;
  return sum + product;
}

// GOOD: Blank line before return
int calculateWithBlankLine(int a, int b) {
  final sum = a + b;
  final product = a * b;

  return sum + product;
}

// --- prefer_trailing_commas / prefer_no_trailing_commas ---

class TrailingCommaExample {
  // BAD: No trailing comma (prefer_trailing_commas)
  // expect_lint: prefer_trailing_commas
  void noTrailingComma(
    String name,
    int age,
    bool isActive
  ) {}

  // GOOD: Trailing comma
  void withTrailingComma(
    String name,
    int age,
    bool isActive,
  ) {}
}

// --- prefer_super_parameters / prefer_explicit_super_calls ---

class Animal {
  final String name;
  Animal(this.name);
}

// BAD: Explicit super call (prefer_super_parameters)
// expect_lint: prefer_super_parameters
class Dog extends Animal {
  final String breed;
  Dog(String name, this.breed) : super(name);
}

// GOOD: Super parameter
class Cat extends Animal {
  final String breed;
  Cat(super.name, this.breed);
}

// --- prefer_initializing_formals / prefer_explicit_field_assignment ---

// BAD: Explicit field assignment (prefer_initializing_formals)
// expect_lint: prefer_initializing_formals
class PersonExplicit {
  final String name;
  final int age;

  PersonExplicit(String name, int age)
      : name = name,
        age = age;
}

// GOOD: Initializing formals
class PersonFormals {
  final String name;
  final int age;

  PersonFormals(this.name, this.age);
}

// =============================================================================
// ERROR HANDLING STYLE RULES
// =============================================================================

class ErrorHandlingExamples {
  // --- prefer_rethrow / prefer_throw_over_rethrow ---

  // BAD: throw e (prefer_rethrow)
  // expect_lint: prefer_rethrow
  void throwExplicit() {
    try {
      throw Exception('Error');
    } catch (e) {
      throw e;
    }
  }

  // GOOD: rethrow
  void rethrowExample() {
    try {
      throw Exception('Error');
    } catch (e) {
      rethrow;
    }
  }

  // --- prefer_specific_exceptions / prefer_generic_exceptions ---

  // BAD: Generic Exception (prefer_specific_exceptions)
  // expect_lint: prefer_specific_exceptions
  void throwGeneric() {
    throw Exception('Something went wrong');
  }

  // GOOD: Specific exception
  void throwSpecific() {
    throw FormatException('Invalid format');
  }
}

// =============================================================================
// TESTING STYLE RULES
// =============================================================================

// Note: These would be in test files, shown here for documentation

void testExamples() {
  // --- prefer_aaa_test_structure / prefer_gwt_test_structure ---

  // BAD: No structure comments (prefer_aaa_test_structure)
  // expect_lint: prefer_aaa_test_structure
  // test('calculates sum', () {
  //   final calculator = Calculator();
  //   final result = calculator.add(2, 3);
  //   expect(result, equals(5));
  // });

  // GOOD: AAA structure
  // test('calculates sum', () {
  //   // Arrange
  //   final calculator = Calculator();
  //
  //   // Act
  //   final result = calculator.add(2, 3);
  //
  //   // Assert
  //   expect(result, equals(5));
  // });
}

// =============================================================================
// ADDITIONAL STYLE RULES
// =============================================================================

class AdditionalStyleExamples {
  // --- prefer_string_interpolation / prefer_string_concatenation ---

  // BAD: Concatenation (prefer_string_interpolation)
  // expect_lint: prefer_string_interpolation
  String getConcatenation(String name) {
    return 'Hello, ' + name + '!';
  }

  // GOOD: Interpolation
  String getInterpolation(String name) {
    return 'Hello, $name!';
  }

  // --- prefer_single_quotes / prefer_double_quotes ---

  // BAD: Double quotes (prefer_single_quotes)
  // expect_lint: prefer_single_quotes
  final doubleQuoted = "Hello";

  // GOOD: Single quotes
  final singleQuoted = 'Hello';
}

// --- prefer_fields_before_methods / prefer_methods_before_fields ---

// BAD: Methods before fields (prefer_fields_before_methods)
// expect_lint: prefer_fields_before_methods
class MethodsFirst {
  void greet() => print('Hello');

  final String name = 'John';
}

// GOOD: Fields before methods
class FieldsFirst {
  final String name = 'John';

  void greet() => print('Hello');
}

// --- prefer_static_members_first / prefer_instance_members_first ---

// BAD: Instance before static (prefer_static_members_first)
// expect_lint: prefer_static_members_first
class InstanceFirst {
  final String name = 'John';

  static const String defaultName = 'Unknown';
}

// GOOD: Static before instance
class StaticFirst {
  static const String defaultName = 'Unknown';

  final String name = 'John';
}

// --- prefer_public_members_first / prefer_private_members_first ---

// BAD: Private before public (prefer_public_members_first)
// expect_lint: prefer_public_members_first
class PrivateFirst {
  final String _id = '123';

  final String name = 'John';
}

// GOOD: Public before private
class PublicFirst {
  final String name = 'John';

  final String _id = '123';
}

// --- prefer_explicit_this ---

class ExplicitThisExample {
  String name;

  ExplicitThisExample(this.name);

  // BAD: Parameter shadows field (prefer_explicit_this)
  // expect_lint: prefer_explicit_this
  void updateName(String name) {
    this.name = name;
  }
}

// --- prefer_implicit_boolean_comparison / prefer_explicit_boolean_comparison ---

class BooleanComparisonExamples {
  // BAD: Explicit comparison (prefer_implicit_boolean_comparison)
  // expect_lint: prefer_implicit_boolean_comparison
  bool checkExplicit(bool isValid) {
    if (isValid == true) {
      return true;
    }
    return false;
  }

  // GOOD: Implicit comparison
  bool checkImplicit(bool isValid) {
    if (isValid) {
      return true;
    }
    return false;
  }

  // BAD: ?? false pattern (prefer_explicit_boolean_comparison)
  // expect_lint: prefer_explicit_boolean_comparison
  bool checkNullable(bool? isValid) {
    return isValid ?? false;
  }

  // GOOD: Explicit == true for nullable
  bool checkNullableExplicit(bool? isValid) {
    return isValid == true;
  }
}

// --- prefer_grouped_imports / prefer_flat_imports ---

// See import section at top of file for examples

// BAD (prefer_flat_imports): Blank lines between import groups
// import 'dart:async';
//
// import 'package:flutter/material.dart';
//
// import '../utils/helpers.dart';

// GOOD (prefer_flat_imports): No blank lines
// import 'dart:async';
// import 'package:flutter/material.dart';
// import '../utils/helpers.dart';
