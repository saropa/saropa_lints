// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../literal_context_utils.dart';
import '../saropa_lint_rule.dart';

/// Warns when digit separators are not grouped consistently.
///
/// Digit separators should group digits by 3 for readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final n = 10_00_000; // Inconsistent grouping
/// final m = 1_0000; // Inconsistent grouping
/// ```
///
/// #### GOOD:
/// ```dart
/// final n = 1_000_000; // Consistent groups of 3
/// final m = 10_000;
/// ```
class AvoidInconsistentDigitSeparatorsRule extends SaropaLintRule {
  const AvoidInconsistentDigitSeparatorsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_inconsistent_digit_separators',
    problemMessage:
        '[avoid_inconsistent_digit_separators] Digit separators are not grouped consistently.',
    correctionMessage: 'Use consistent groups of 3 digits.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      final String lexeme = node.literal.lexeme;
      if (!lexeme.contains('_')) return;

      // Skip hex, binary, octal
      if (lexeme.startsWith('0x') ||
          lexeme.startsWith('0X') ||
          lexeme.startsWith('0b') ||
          lexeme.startsWith('0B') ||
          lexeme.startsWith('0o') ||
          lexeme.startsWith('0O')) {
        return;
      }

      // Split by underscores and check group sizes
      final List<String> groups = lexeme.split('_');
      if (groups.length < 2) return;

      // First group can be any size, rest should be 3
      for (int i = 1; i < groups.length; i++) {
        if (groups[i].length != 3) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    context.registry.addDoubleLiteral((DoubleLiteral node) {
      final String lexeme = node.literal.lexeme;
      if (!lexeme.contains('_')) return;

      // Check the integer part before the decimal point
      final int dotIndex = lexeme.indexOf('.');
      if (dotIndex == -1) return;

      final String intPart = lexeme.substring(0, dotIndex);
      if (!intPart.contains('_')) return;

      final List<String> groups = intPart.split('_');
      if (groups.length < 2) return;

      for (int i = 1; i < groups.length; i++) {
        if (groups[i].length != 3) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when digit separators are used unnecessarily.
///
/// Digit separators should improve readability, not hinder it.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final value = 1_0; // Too few digits
/// final amount = 1_2_3; // Inconsistent grouping
/// ```
///
/// #### GOOD:
/// ```dart
/// final value = 10;
/// final amount = 1_000_000;
/// ```
class AvoidUnnecessaryDigitSeparatorsRule extends SaropaLintRule {
  const AvoidUnnecessaryDigitSeparatorsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_digit_separators',
    problemMessage:
        '[avoid_unnecessary_digit_separators] Unnecessary or poorly placed digit separator.',
    correctionMessage:
        'Use digit separators consistently for large numbers only.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      final String lexeme = node.literal.lexeme;
      if (!lexeme.contains('_')) return;

      // Check for problems with separators
      final List<String> parts = lexeme.split('_');

      // Check for too few digits between separators
      for (int i = 1; i < parts.length; i++) {
        final String part = parts[i];
        // After first separator, groups should be consistent (typically 3)
        if (part.length < 2) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Check if number is too small to need separators
      final String withoutSeparators = lexeme.replaceAll('_', '');
      if (withoutSeparators.length < 4) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when double literals don't follow a consistent format.
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Double literals should be formatted consistently, e.g., always include
/// a digit before the decimal point (0.5 instead of .5).
class DoubleLiteralFormatRule extends SaropaLintRule {
  const DoubleLiteralFormatRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'double_literal_format',
    problemMessage:
        '[double_literal_format] Formatting double literals in a specific way (e.g., 1.0 vs 1.) is a stylistic preference. All forms represent the same value with no performance difference. Enable via the stylistic tier.',
    correctionMessage: 'Include leading zero before decimal point (e.g., 0.5).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addDoubleLiteral((DoubleLiteral node) {
      final String lexeme = node.literal.lexeme;
      // Check for missing leading zero
      if (lexeme.startsWith('.')) {
        reporter.atNode(node, code);
      }
      // Check for trailing decimal without digits
      if (lexeme.endsWith('.')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when magic numbers are used instead of named constants.
///
/// Magic numbers make code harder to understand and maintain. Use named
/// constants to give meaning to numeric values.
class NoMagicNumberRule extends SaropaLintRule {
  const NoMagicNumberRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_magic_number',
    problemMessage:
        '[no_magic_number] Unexplained numeric literal makes the code harder to understand, maintain, and update consistently. '
        'When the same value appears in multiple locations, a typo in one creates a subtle bug. Readers cannot determine whether the number represents a timeout, a threshold, a count, or an index without surrounding context.',
    correctionMessage:
        'Extract the number to a named constant (e.g., static const maxRetries = 3) that communicates its purpose. '
        'Group related constants in a dedicated class or file so they can be updated in one place and are discoverable by other developers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // Numbers that are commonly used and don't need constants
  static const Set<int> _allowedInts = <int>{-1, 0, 1, 2};
  static const List<double> _allowedDoubles = <double>[0.0, 1.0, 0.5];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      if (_shouldReportInt(node, node.value)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addDoubleLiteral((DoubleLiteral node) {
      if (_shouldReportDouble(node, node.value)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _shouldReportInt(Literal node, int? value) {
    if (value == null) return false;
    if (_allowedInts.contains(value)) return false;
    return !isLiteralInConstContext(node);
  }

  bool _shouldReportDouble(Literal node, double value) {
    if (_allowedDoubles.contains(value)) return false;
    return !isLiteralInConstContext(node);
  }
}

/// Warns when string literals are used directly (magic strings).
///
/// Magic strings make code harder to maintain. Use constants instead.
///
/// Example of **bad** code:
/// ```dart
/// if (status == 'active') {}
/// print('Error: Something went wrong');
/// ```
///
/// Example of **good** code:
/// ```dart
/// const kStatusActive = 'active';
/// if (status == kStatusActive) {}
///
/// const kErrorMessage = 'Error: Something went wrong';
/// print(kErrorMessage);
/// ```
class NoMagicStringRule extends SaropaLintRule {
  const NoMagicStringRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_magic_string',
    problemMessage:
        '[no_magic_string] Unexplained string literal makes the code harder to understand, maintain, and update consistently. '
        'Duplicate string values across the codebase lead to inconsistencies when one occurrence is updated but others are missed, causing hard-to-trace bugs in routing, API calls, or status checks.',
    correctionMessage:
        'Extract the string to a named constant (e.g., static const kStatusActive = \'active\') that communicates its purpose. '
        'Group related constants in a dedicated class or file so they can be updated in one place and are discoverable by other developers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Strings that are commonly acceptable as literals
  static const Set<String> _allowedStrings = <String>{
    '',
    ' ',
    ', ',
    ': ',
    '.',
    '...',
    '-',
    '_',
    '/',
    '\\',
    '\n',
    '\t',
    '\r',
    '0',
    '1',
    'true',
    'false',
    'null',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      // Skip allowed common strings
      if (_allowedStrings.contains(node.value)) return;

      // Skip very short strings (1-2 chars)
      if (node.value.length <= 2) return;

      // Skip if in const context
      if (isLiteralInConstContext(node)) return;

      // Skip if in annotation
      if (isInAnnotation(node)) return;

      // Skip if in import/export
      if (isInImportOrExport(node)) return;

      // Skip interpolated strings (they're usually intentional)
      if (node.parent is StringInterpolation) return;

      // Skip regex patterns
      if (isStringUsedAsRegexPattern(node)) return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when x = x + 1 could be x += 1 (or similar).
///
/// Compound assignment operators are more concise.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// x = x + 1;
/// y = y - 5;
/// z = z * 2;
/// ```
///
/// #### GOOD:
/// ```dart
/// x += 1;
/// y -= 5;
/// z *= 2;
/// ```
class PreferAdditionSubtractionAssignmentsRule extends SaropaLintRule {
  const PreferAdditionSubtractionAssignmentsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_addition_subtraction_assignments',
    problemMessage:
        '[prefer_addition_subtraction_assignments] Use compound assignment operator.',
    correctionMessage: 'Replace with +=, -=, *=, /=, etc.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _compoundableOperators = <String>{
    '+',
    '-',
    '*',
    '/',
    '%',
    '~/',
    '&',
    '|',
    '^',
    '<<',
    '>>',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments (=)
      if (node.operator.lexeme != '=') return;

      final Expression lhs = node.leftHandSide;
      final Expression rhs = node.rightHandSide;

      // RHS must be a binary expression
      if (rhs is! BinaryExpression) return;

      final String op = rhs.operator.lexeme;
      if (!_compoundableOperators.contains(op)) return;

      // Check if LHS matches one operand of the binary expression
      final String lhsSource = lhs.toSource();
      final String leftSource = rhs.leftOperand.toSource();

      if (lhsSource == leftSource) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when binary operators can be simplified to compound assignment.
///
/// Similar to PreferAdditionSubtractionAssignmentsRule but focuses on
/// less common operators.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// x = x & mask;
/// y = y | flag;
/// ```
///
/// #### GOOD:
/// ```dart
/// x &= mask;
/// y |= flag;
/// ```
class PreferCompoundAssignmentOperatorsRule extends SaropaLintRule {
  const PreferCompoundAssignmentOperatorsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_compound_assignment_operators',
    problemMessage:
        '[prefer_compound_assignment_operators] Use compound assignment operator.',
    correctionMessage: 'Replace with compound assignment (e.g., &=, |=, ^=).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments
      if (node.operator.lexeme != '=') return;

      final Expression rhs = node.rightHandSide;
      if (rhs is! BinaryExpression) return;

      // Check if LHS equals left operand of binary expression
      final String lhsSource = node.leftHandSide.toSource();
      final String rhsLeftSource = rhs.leftOperand.toSource();

      if (lhsSource == rhsLeftSource) {
        // Already covered by PreferAdditionSubtractionAssignmentsRule
        // for +, -, *, /, %, so only check bitwise here
        final String op = rhs.operator.lexeme;
        if (op == '&' || op == '|' || op == '^' || op == '<<' || op == '>>') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when large numbers don't use digit separators.
///
/// Digit separators improve readability of large numbers.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final million = 1000000;
/// final bigNumber = 123456789;
/// ```
///
/// #### GOOD:
/// ```dart
/// final million = 1_000_000;
/// final bigNumber = 123_456_789;
/// ```
class PreferDigitSeparatorsRule extends SaropaLintRule {
  const PreferDigitSeparatorsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _threshold = 10000; // Numbers >= 10000 should use separators

  static const LintCode _code = LintCode(
    name: 'prefer_digit_separators',
    problemMessage:
        '[prefer_digit_separators] Large number should use digit separators.',
    correctionMessage: 'Add underscores to group digits (e.g., 1_000_000).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      final String lexeme = node.literal.lexeme;

      // Skip if already has separators
      if (lexeme.contains('_')) return;

      // Skip hex, binary, octal
      if (lexeme.startsWith('0x') ||
          lexeme.startsWith('0X') ||
          lexeme.startsWith('0b') ||
          lexeme.startsWith('0B') ||
          lexeme.startsWith('0o') ||
          lexeme.startsWith('0O')) {
        return;
      }

      final int? value = node.value;
      if (value != null && value >= _threshold) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDigitSeparatorsFix()];

  /// Formats a number with digit separators (groups of 3).
  static String formatWithSeparators(String lexeme) {
    // Handle negative numbers
    final bool isNegative = lexeme.startsWith('-');
    String digits = isNegative ? lexeme.substring(1) : lexeme;

    // Build result from right to left with groups of 3
    final StringBuffer result = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write('_');
      }
      result.write(digits[i]);
      count++;
    }

    final String reversed = result.toString().split('').reversed.join();
    return isNegative ? '-$reversed' : reversed;
  }
}

class _AddDigitSeparatorsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String lexeme = node.literal.lexeme;

      // Skip if already has separators or is non-decimal
      if (lexeme.contains('_')) return;
      if (lexeme.startsWith('0x') ||
          lexeme.startsWith('0X') ||
          lexeme.startsWith('0b') ||
          lexeme.startsWith('0B') ||
          lexeme.startsWith('0o') ||
          lexeme.startsWith('0O')) {
        return;
      }

      final String formatted =
          PreferDigitSeparatorsRule.formatWithSeparators(lexeme);

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add digit separators',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          formatted,
        );
      });
    });
  }
}

/// Warns when digit separators are used unnecessarily.
///
/// Digit separators in small numbers don't improve readability.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final n = 1_0; // Unnecessary separator
/// final m = 10_0; // Unnecessary separator
/// ```
///
/// #### GOOD:
/// ```dart
/// final n = 10; // No separator needed
/// final m = 1_000_000; // Separator improves readability
/// ```
class AvoidDigitSeparatorsRule extends SaropaLintRule {
  const AvoidDigitSeparatorsRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_digit_separators',
    problemMessage:
        '[avoid_digit_separators] Unnecessary digit separator in small number.',
    correctionMessage: 'Remove digit separators from small numbers.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minDigitsForSeparator = 5;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      final String lexeme = node.literal.lexeme;
      if (!lexeme.contains('_')) return;

      // Remove separators to count actual digits
      final String digitsOnly = lexeme.replaceAll('_', '');

      // Skip hex, binary, octal
      if (digitsOnly.startsWith('0x') ||
          digitsOnly.startsWith('0X') ||
          digitsOnly.startsWith('0b') ||
          digitsOnly.startsWith('0B') ||
          digitsOnly.startsWith('0o') ||
          digitsOnly.startsWith('0O')) {
        return;
      }

      if (digitsOnly.length < _minDigitsForSeparator) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when magic numbers are used in test files.
///
/// **Context**: This is the test-specific variant of `no_magic_number`, which
/// skips test files entirely (default `TestRelevance.never`). The production rule
/// enforces strict avoidance of magic numbers in application code, while this
/// rule provides appropriate, relaxed enforcement for test code.
///
/// **Rationale**: Test files legitimately use more literal values than
/// production code for:
/// - HTTP status codes (200, 404, 500) in API tests
/// - Small integers (0-5) for indexing and counting test cases
/// - Powers of 10 (10, 100, 1000) for threshold/boundary tests
/// - Common fractions (0.5, 1.0, 2.0) for mathematical assertions
///
/// However, meaningful domain values (like product prices, account balances,
/// or business thresholds) should still use named constants to make tests
/// self-documenting and maintainable.
///
/// **Allowed values**:
/// - Integers: -1, 0, 1, 2, 3, 4, 5, 10, 100, 200, 201, 204, 400, 401,
///   403, 404, 500, 503, 1000
/// - Doubles: -1.0, 0.0, 0.5, 1.0, 2.0, 10.0, 100.0
/// - All values in const contexts (const declarations, const constructors)
///
/// **Tier**: Comprehensive (optional, style enforcement)
/// **Severity**: INFO
/// **Performance**: Medium cost (addIntegerLiteral, addDoubleLiteral registries)
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// test('validates product price', () {
///   final product = Product(price: 29.99); // Magic number - domain value
///   expect(product.isValid, true);
/// });
///
/// test('processes batch', () {
///   final items = List.generate(137, (i) => Item()); // Magic number
///   processBatch(items);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('validates product price', () {
///   const validPrice = 29.99; // Named constant for clarity
///   final product = Product(price: validPrice);
///   expect(product.isValid, true);
/// });
///
/// test('processes batch', () {
///   const batchSize = 137; // Named constant explains purpose
///   final items = List.generate(batchSize, (i) => Item());
///   processBatch(items);
/// });
///
/// test('returns 404 for missing resource', () async {
///   final response = await client.get('/nonexistent');
///   expect(response.statusCode, 404); // OK: Common HTTP status code
/// });
///
/// test('handles empty list', () {
///   final result = process([]); // OK: Empty list
///   expect(result.length, 0); // OK: Allowed value
/// });
/// ```
///
/// ### Related Rules
///
/// - `no_magic_number` - Production code variant (skips test files)
/// - `no_magic_string` - Similar pattern for string literals
/// - `no_magic_string_in_tests` - Test-specific variant for strings
class NoMagicNumberInTestsRule extends SaropaLintRule {
  const NoMagicNumberInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'no_magic_number_in_tests',
    problemMessage:
        '[no_magic_number_in_tests] Unexplained numeric literal in test file obscures the purpose of expected values and assertions. '
        'When a test fails, readers cannot tell whether the number is an arbitrary fixture value, a meaningful boundary, or a calculated expected result, making failures harder to diagnose and fix.',
    correctionMessage:
        'Extract test values to named constants (e.g., const expectedCount = 42) that describe their role in the test. '
        'This makes assertions self-documenting, failures easier to diagnose, and test data easier to update when requirements change.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  // More relaxed allowed values for test files
  static const Set<int> _allowedInts = <int>{
    -1,
    0,
    1,
    2,
    3,
    4,
    5,
    10,
    100,
    200,
    201,
    204,
    400,
    401,
    403,
    404,
    500,
    503,
    1000,
  };
  static const List<double> _allowedDoubles = <double>[
    -1.0,
    0.0,
    0.5,
    1.0,
    2.0,
    10.0,
    100.0,
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      if (_shouldReportInt(node, node.value)) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addDoubleLiteral((DoubleLiteral node) {
      if (_shouldReportDouble(node, node.value)) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => [_NoMagicNumberInTestsFix()];

  bool _shouldReportInt(Literal node, int? value) {
    if (value == null) return false;
    if (_allowedInts.contains(value)) return false;
    return !isLiteralInConstContext(node);
  }

  bool _shouldReportDouble(Literal node, double value) {
    if (_allowedDoubles.contains(value)) return false;
    return !isLiteralInConstContext(node);
  }
}

class _NoMagicNumberInTestsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIntegerLiteral((IntegerLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final value = node.literal.lexeme;
      final constantName = _suggestConstantName(value);

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Extract to const $constantName',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the test function or test group containing this literal
        AstNode? current = node;
        while (current != null && current is! FunctionExpression) {
          current = current.parent;
        }

        if (current == null) return;

        // Insert constant declaration before the test function
        final insertPosition = current.offset;
        builder.addSimpleInsertion(
          insertPosition,
          'const $constantName = $value;\n  ',
        );

        // Replace the literal with the constant name
        builder.addSimpleReplacement(node.sourceRange, constantName);
      });
    });

    context.registry.addDoubleLiteral((DoubleLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final value = node.literal.lexeme;
      final constantName = _suggestConstantName(value);

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Extract to const $constantName',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the test function or test group containing this literal
        AstNode? current = node;
        while (current != null && current is! FunctionExpression) {
          current = current.parent;
        }

        if (current == null) return;

        // Insert constant declaration before the test function
        final insertPosition = current.offset;
        builder.addSimpleInsertion(
          insertPosition,
          'const $constantName = $value;\n  ',
        );

        // Replace the literal with the constant name
        builder.addSimpleReplacement(node.sourceRange, constantName);
      });
    });
  }

  String _suggestConstantName(String value) {
    // Remove underscores and dots for the name
    final cleaned = value.replaceAll('_', '').replaceAll('.', '');
    // Convert to camelCase name
    if (value.startsWith('-')) {
      return 'negativeValue$cleaned';
    } else if (value.contains('.')) {
      return 'testValue${cleaned.replaceAll('-', '')}';
    } else {
      return 'testValue$cleaned';
    }
  }
}

/// Warns when magic strings are used in test files.
///
/// **Context**: This is the test-specific variant of `no_magic_string`, which
/// skips test files entirely (default `TestRelevance.never`). The production rule
/// enforces strict avoidance of magic strings in application code, while this
/// rule provides appropriate, relaxed enforcement for test code.
///
/// **Rationale**: Test files legitimately use more literal strings than
/// production code for:
/// - Test descriptions (automatically allowed as first arg to test(), group())
/// - Common test data (hex strings, single letters, placeholder values)
/// - Simple assertions ('foo', 'bar', 'hello', 'world')
/// - Regex patterns (automatically detected via RegExp() constructor)
///
/// However, meaningful domain strings (like email addresses, URLs, API keys,
/// or business identifiers) should still use named constants to make tests
/// self-documenting and maintainable.
///
/// **Automatically allowed**:
/// - Test descriptions: `test('description', ...)` - first argument
/// - Regex patterns: `RegExp(r'\d+')` or `RegExp('pattern')`
/// - Import/export paths: `import 'foo.dart'`
/// - Annotations: `@Tag('integration')`
/// - Const contexts: `const name = 'value'`
/// - Interpolated strings: `'Result: $value'`
/// - Very short strings: 1-3 characters
///
/// **Allowed literal values**:
/// - Common punctuation: '', ' ', ', ', ': ', '.', '...', '-', '_', '/', '\'
/// - Single letters: 'a', 'b', 'c', 'x', 'y', 'z'
/// - Test placeholders: 'foo', 'bar', 'baz', 'test', 'example', 'hello', 'world'
/// - String representations: 'true', 'false', 'null', '0', '1'
///
/// **Tier**: Comprehensive (optional, style enforcement)
/// **Severity**: INFO
/// **Performance**: Medium cost (addSimpleStringLiteral registry)
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// test('validates email', () {
///   final user = User(email: 'user@example.com'); // Magic string
///   expect(user.isValid, true);
/// });
///
/// test('fetches from API', () async {
///   final data = await fetch('https://api.example.com/users'); // Magic URL
///   expect(data, isNotEmpty);
/// });
///
/// test('parses hex color', () {
///   final color = parseColor('7FfFfFfFfFfFfFfF'); // Magic hex string
///   expect(color.isValid, true);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('validates email', () {
///   const testEmail = 'user@example.com'; // Named constant for clarity
///   final user = User(email: testEmail);
///   expect(user.isValid, true);
/// });
///
/// test('fetches from API', () async {
///   const apiUrl = 'https://api.example.com/users'; // Named constant
///   final data = await fetch(apiUrl);
///   expect(data, isNotEmpty);
/// });
///
/// test('parses hex color', () {
///   const testHexString = '7FfFfFfFfFfFfFfF'; // Named constant
///   final color = parseColor(testHexString);
///   expect(color.isValid, true);
/// });
///
/// // Automatically allowed patterns:
/// test('validates empty string', () { // Test description - OK
///   final result = validate(''); // OK: Empty string
///   expect(result.errors, isEmpty);
/// });
///
/// test('matches regex pattern', () {
///   final regex = RegExp(r'\d+'); // OK: Regex pattern
///   expect(regex.hasMatch('123'), true);
/// });
///
/// test('handles simple values', () {
///   final result = process('x'); // OK: Single letter
///   expect(result.value, 'foo'); // OK: Common test placeholder
/// });
/// ```
///
/// ### Related Rules
///
/// - `no_magic_string` - Production code variant (skips test files)
/// - `no_magic_number` - Similar pattern for numeric literals
/// - `no_magic_number_in_tests` - Test-specific variant for numbers
class NoMagicStringInTestsRule extends SaropaLintRule {
  const NoMagicStringInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'no_magic_string_in_tests',
    problemMessage:
        '[no_magic_string_in_tests] Unexplained string literal in test file obscures the purpose of expected values and assertions. '
        'When a test fails, readers cannot tell whether the string is an arbitrary fixture, a meaningful expected output, or a format-specific value, making failures harder to diagnose.',
    correctionMessage:
        'Extract test strings to named constants (e.g., const expectedName = \'John Doe\') that describe their role in the test. '
        'This makes assertions self-documenting, failures easier to diagnose, and test data easier to update when requirements change.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// More relaxed allowed strings for test files
  static const Set<String> _allowedStrings = <String>{
    '',
    ' ',
    ', ',
    ': ',
    '.',
    '...',
    '-',
    '_',
    '/',
    '\\',
    '\n',
    '\t',
    '\r',
    '0',
    '1',
    'true',
    'false',
    'null',
    // Common test values
    'test',
    'Test',
    'example',
    'Example',
    'hello',
    'world',
    'foo',
    'bar',
    'baz',
    'a',
    'b',
    'c',
    'x',
    'y',
    'z',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      // Skip allowed common strings
      if (_allowedStrings.contains(node.value)) return;

      // Skip very short strings (1-3 chars) - more lenient for tests
      if (node.value.length <= 3) return;

      // Skip if in const context
      if (isLiteralInConstContext(node)) return;

      // Skip if in annotation
      if (isInAnnotation(node)) return;

      // Skip if in import/export
      if (isInImportOrExport(node)) return;

      // Skip interpolated strings
      if (node.parent is StringInterpolation) return;

      // Skip test descriptions (first argument to test(), group(), etc.)
      if (isTestDescription(node)) return;

      // Skip regex patterns
      if (isStringUsedAsRegexPattern(node)) return;

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => [_NoMagicStringInTestsFix()];
}

class _NoMagicStringInTestsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final value = node.literal.lexeme;
      final constantName = _suggestConstantName(node.value);

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Extract to const $constantName',
        priority: 80,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find the test function or test group containing this literal
        AstNode? current = node;
        while (current != null && current is! FunctionExpression) {
          current = current.parent;
        }

        if (current == null) return;

        // Insert constant declaration before the test function
        final insertPosition = current.offset;
        builder.addSimpleInsertion(
          insertPosition,
          'const $constantName = $value;\n  ',
        );

        // Replace the literal with the constant name
        builder.addSimpleReplacement(node.sourceRange, constantName);
      });
    });
  }

  String _suggestConstantName(String value) {
    // Generate a descriptive constant name from the string value
    if (value.isEmpty) return 'emptyString';
    if (value.length <= 3) return 'test${value.toUpperCase()}';

    // Try to make a meaningful name from the value
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ' ')
        .trim()
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(3) // Max 3 words
        .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
        .join('');

    if (cleaned.isEmpty) return 'testString';

    return 'test$cleaned';
  }
}
