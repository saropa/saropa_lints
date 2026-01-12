// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

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
/// Double literals should be formatted consistently, e.g., always include
/// a digit before the decimal point (0.5 instead of .5).
class DoubleLiteralFormatRule extends SaropaLintRule {
  const DoubleLiteralFormatRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'double_literal_format',
    problemMessage:
        '[double_literal_format] Use consistent double literal format.',
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
    problemMessage: '[no_magic_number] Avoid magic numbers.',
    correctionMessage: 'Extract the number to a named constant.',
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
    return _notInConstContext(node);
  }

  bool _shouldReportDouble(Literal node, double value) {
    if (_allowedDoubles.contains(value)) return false;
    return _notInConstContext(node);
  }

  bool _notInConstContext(Literal node) {
    // Don't report in const contexts
    AstNode? parent = node.parent;
    while (parent != null) {
      if (parent is VariableDeclaration) {
        final AstNode? grandparent = parent.parent;
        if (grandparent is VariableDeclarationList) {
          if (grandparent.isConst) return false;
        }
      }
      // Check for const constructor calls
      if (parent is InstanceCreationExpression && parent.isConst) {
        return false;
      }
      parent = parent.parent;
    }
    return true;
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
    problemMessage: '[no_magic_string] Avoid using magic string literals.',
    correctionMessage: 'Extract the string to a named constant.',
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
      if (_isInConstContext(node)) return;

      // Skip if in annotation
      if (_isInAnnotation(node)) return;

      // Skip if in import/export
      if (_isInImportOrExport(node)) return;

      // Skip interpolated strings (they're usually intentional)
      if (node.parent is StringInterpolation) return;

      reporter.atNode(node, code);
    });
  }

  bool _isInConstContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is VariableDeclarationList && current.isConst) return true;
      if (current is InstanceCreationExpression && current.isConst) return true;
      if (current is ListLiteral && current.constKeyword != null) return true;
      if (current is SetOrMapLiteral && current.constKeyword != null) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInAnnotation(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is Annotation) return true;
      current = current.parent;
    }
    return false;
  }

  bool _isInImportOrExport(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ImportDirective || current is ExportDirective) return true;
      current = current.parent;
    }
    return false;
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
