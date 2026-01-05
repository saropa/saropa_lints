// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when comparing an expression to itself (x == x).
///
/// Comparing something to itself is usually a bug, except for NaN checks.
///
/// Example of **bad** code:
/// ```dart
/// if (value == value) {}  // Always true (unless NaN)
/// if (list.length > list.length) {}  // Always false
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (value == expectedValue) {}
/// // For NaN checks:
/// if (value != value) {}  // This is intentional for NaN detection
/// ```
class AvoidEqualExpressionsRule extends DartLintRule {
  const AvoidEqualExpressionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_equal_expressions',
    problemMessage: 'Both sides of the binary expression are identical.',
    correctionMessage: 'This is likely a bug. Use different expressions on each side.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Skip != as it might be intentional for NaN checks
      if (node.operator.type == TokenType.BANG_EQ) return;

      final String leftSource = node.leftOperand.toSource();
      final String rightSource = node.rightOperand.toSource();

      if (leftSource == rightSource) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when negation is used in equality checks.
///
/// Using negation in equality can be harder to read.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (!(a == b)) { ... }
/// if (!list.contains(x)) { ... } // Sometimes ok
/// ```
///
/// #### GOOD:
/// ```dart
/// if (a != b) { ... }
/// ```
class AvoidNegationsInEqualityChecksRule extends DartLintRule {
  const AvoidNegationsInEqualityChecksRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_negations_in_equality_checks',
    problemMessage: 'Use != instead of negating == comparison.',
    correctionMessage: 'Replace !(a == b) with a != b.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.lexeme != '!') return;

      final Expression operand = node.operand;

      // Check for !(a == b)
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression && inner.operator.lexeme == '==') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when a variable is assigned to itself.
///
/// Example of **bad** code:
/// ```dart
/// x = x;
/// this.value = this.value;
/// ```
///
/// Example of **good** code:
/// ```dart
/// x = newValue;
/// this.value = other.value;
/// ```
class AvoidSelfAssignmentRule extends DartLintRule {
  const AvoidSelfAssignmentRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_self_assignment',
    problemMessage: 'Variable is assigned to itself.',
    correctionMessage: 'Remove the self-assignment or assign a different value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments (not +=, -=, etc.)
      if (node.operator.type != TokenType.EQ) return;

      final String leftSource = node.leftHandSide.toSource();
      final String rightSource = node.rightHandSide.toSource();

      if (leftSource == rightSource) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a variable is compared to itself.
///
/// Example of **bad** code:
/// ```dart
/// if (x == x) { }
/// if (y != y) { }  // Always false for non-NaN
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (x == y) { }
/// if (x.isNaN) { }  // Use isNaN to check for NaN
/// ```
class AvoidSelfCompareRule extends DartLintRule {
  const AvoidSelfCompareRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_self_compare',
    problemMessage: 'Variable is compared to itself.',
    correctionMessage: 'Use isNaN for NaN checks, or compare different values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final TokenType operator = node.operator.type;

      // Check comparison operators
      if (operator == TokenType.EQ_EQ ||
          operator == TokenType.BANG_EQ ||
          operator == TokenType.LT ||
          operator == TokenType.GT ||
          operator == TokenType.LT_EQ ||
          operator == TokenType.GT_EQ) {
        final String leftSource = node.leftOperand.toSource();
        final String rightSource = node.rightOperand.toSource();

        if (leftSource == rightSource) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when compareTo is used for equality instead of ==.
class AvoidUnnecessaryCompareToRule extends DartLintRule {
  const AvoidUnnecessaryCompareToRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_compare_to',
    problemMessage: 'Use == instead of compareTo() == 0.',
    correctionMessage: 'Replace compareTo(x) == 0 with == x.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final String op = node.operator.lexeme;
      if (op != '==' && op != '!=') return;

      // Check for: compareTo(x) == 0 or compareTo(x) != 0
      MethodInvocation? compareToCall;
      IntegerLiteral? zeroLiteral;

      if (node.leftOperand is MethodInvocation && node.rightOperand is IntegerLiteral) {
        compareToCall = node.leftOperand as MethodInvocation;
        zeroLiteral = node.rightOperand as IntegerLiteral;
      } else if (node.rightOperand is MethodInvocation && node.leftOperand is IntegerLiteral) {
        compareToCall = node.rightOperand as MethodInvocation;
        zeroLiteral = node.leftOperand as IntegerLiteral;
      }

      if (compareToCall == null || zeroLiteral == null) return;
      if (compareToCall.methodName.name != 'compareTo') return;
      if (zeroLiteral.value != 0) return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when the same argument value is passed multiple times.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// setPosition(x, x); // Same value twice
/// compare(value, value); // Comparing to itself
/// ```
///
/// #### GOOD:
/// ```dart
/// setPosition(x, y);
/// compare(value, otherValue);
/// ```
class NoEqualArgumentsRule extends DartLintRule {
  const NoEqualArgumentsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'no_equal_arguments',
    problemMessage: 'Same argument passed multiple times.',
    correctionMessage: 'Check if this is intentional or a copy-paste error.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addArgumentList((ArgumentList node) {
      final List<Expression> args = node.arguments.toList();
      if (args.length < 2) return;

      // Check positional arguments for duplicates
      final Set<String> seen = <String>{};
      for (final Expression arg in args) {
        // Skip named arguments for this check
        if (arg is NamedExpression) continue;

        // Skip numeric literals - it's common to have Alignment(0.7, 0.7),
        // Offset(10, 10), Size(100, 100), etc.
        if (arg is IntegerLiteral || arg is DoubleLiteral) continue;

        // Skip complex expressions, only check simple identifiers and literals
        String? argSource;
        if (arg is SimpleIdentifier) {
          argSource = arg.name;
        } else if (arg is BooleanLiteral) {
          argSource = arg.toSource();
        }

        if (argSource != null && argSource.isNotEmpty) {
          if (seen.contains(argSource)) {
            reporter.atNode(arg, code);
          }
          seen.add(argSource);
        }
      }
    });
  }
}
