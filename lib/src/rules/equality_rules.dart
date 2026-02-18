// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../saropa_lint_rule.dart';
import '../fixes/equality/use_date_time_difference_fix.dart';
import '../fixes/equality/use_direct_equality_fix.dart';
import '../fixes/equality/use_not_equals_fix.dart';

/// Warns when comparing an expression to itself (x == x).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidEqualExpressionsRule extends SaropaLintRule {
  AvoidEqualExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_equal_expressions',
    '[avoid_equal_expressions] Both sides of the binary expression are identical, meaning the comparison always produces the same result (true for ==, false for >, <). This is almost always a copy-paste bug where the developer intended to compare two different values, and the redundant comparison masks the real logic error in the code. {v5}',
    correctionMessage:
        'Replace one side of the expression with the intended comparison target to fix the copy-paste error.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Skip != as it might be intentional for NaN checks
      if (node.operator.type == TokenType.BANG_EQ) return;

      final String leftSource = node.leftOperand.toSource();
      final String rightSource = node.rightOperand.toSource();

      if (leftSource == rightSource) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when negation is used in equality checks.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
///
/// **Quick fix available:** Transforms `!(a == b)` to `a != b`.
class AvoidNegationsInEqualityChecksRule extends SaropaLintRule {
  AvoidNegationsInEqualityChecksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_negations_in_equality_checks',
    '[avoid_negations_in_equality_checks] Equality check is wrapped in a negation operator !(a == b) instead of using the direct != operator. The negated form adds unnecessary cognitive overhead, increases nesting depth, and is harder to scan during code review. The != operator expresses the same intent more clearly and concisely. {v4}',
    correctionMessage:
        'Replace !(a == b) with a != b for direct and readable inequality checking. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixExpression((PrefixExpression node) {
      if (node.operator.lexeme != '!') return;

      final Expression operand = node.operand;

      // Check for !(a == b)
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression && inner.operator.lexeme == '==') {
          reporter.atNode(node);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            UseNotEqualsFix(context: context),
      ];
}

/// Warns when a variable is assigned to itself.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
class AvoidSelfAssignmentRule extends SaropaLintRule {
  AvoidSelfAssignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_self_assignment',
    '[avoid_self_assignment] Variable is assigned to itself (x = x), which has no effect and indicates a copy-paste error or incomplete refactor. The assignment executes at runtime but produces no state change, wasting CPU cycles and obscuring the developer\'s actual intent. This dead code makes maintenance harder because readers must determine whether the assignment was intentional. {v5}',
    correctionMessage:
        'Remove the self-assignment entirely, or replace the right-hand side with the intended source value.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAssignmentExpression((AssignmentExpression node) {
      // Only check simple assignments (not +=, -=, etc.)
      if (node.operator.type != TokenType.EQ) return;

      final String leftSource = node.leftHandSide.toSource();
      final String rightSource = node.rightHandSide.toSource();

      if (leftSource == rightSource) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a variable is compared to itself.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class AvoidSelfCompareRule extends SaropaLintRule {
  AvoidSelfCompareRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_self_compare',
    '[avoid_self_compare] Variable is compared to itself (x == x, x > x, etc.), which always produces a constant result (true for ==, false for inequality operators) unless the value is NaN. This is almost always a copy-paste bug where the developer intended to compare two distinct values, and the redundant comparison hides the real logic error in the code. {v4}',
    correctionMessage:
        'Use .isNaN for NaN detection, or replace one operand with the intended comparison target.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
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
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when compareTo is used for equality instead of ==.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// **Quick fix available:** Transforms `a.compareTo(b) == 0` to `a == b`.
class AvoidUnnecessaryCompareToRule extends SaropaLintRule {
  AvoidUnnecessaryCompareToRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_unnecessary_compare_to',
    '[avoid_unnecessary_compare_to] Using compareTo() == 0 for equality checking is unnecessarily verbose when the == operator expresses the same comparison directly. The compareTo method is designed for ordering (less than, greater than), and using it for equality adds cognitive overhead, increases code length, and obscures the developer\'s intent of a simple equality check. {v4}',
    correctionMessage:
        'Replace compareTo(x) == 0 with == x, and compareTo(x) != 0 with != x for clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final String op = node.operator.lexeme;
      if (op != '==' && op != '!=') return;

      // Check for: compareTo(x) == 0 or compareTo(x) != 0
      MethodInvocation? compareToCall;
      IntegerLiteral? zeroLiteral;

      if (node.leftOperand is MethodInvocation &&
          node.rightOperand is IntegerLiteral) {
        compareToCall = node.leftOperand as MethodInvocation;
        zeroLiteral = node.rightOperand as IntegerLiteral;
      } else if (node.rightOperand is MethodInvocation &&
          node.leftOperand is IntegerLiteral) {
        compareToCall = node.rightOperand as MethodInvocation;
        zeroLiteral = node.leftOperand as IntegerLiteral;
      }

      if (compareToCall == null || zeroLiteral == null) return;
      if (compareToCall.methodName.name != 'compareTo') return;
      if (zeroLiteral.value != 0) return;

      reporter.atNode(node);
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            UseDirectEqualityFix(context: context),
      ];
}

/// Warns when the same argument value is passed multiple times.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
class NoEqualArgumentsRule extends SaropaLintRule {
  NoEqualArgumentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_equal_arguments',
    '[no_equal_arguments] The same identifier is passed as multiple positional arguments to a function call, which typically indicates a copy-paste error where distinct values were intended (e.g., setPosition(x, x) instead of setPosition(x, y)). This silent bug produces incorrect behavior that passes compilation but yields wrong results at runtime. {v4}',
    correctionMessage:
        'Verify whether duplicate arguments are intentional, and replace with the intended distinct values.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addArgumentList((ArgumentList node) {
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
            reporter.atNode(arg);
          }
          seen.add(argSource);
        }
      }
    });
  }
}

// =============================================================================
// DateTime Comparison Rules
// =============================================================================

/// Warns when DateTime values are compared using == or !=.
///
/// Since: v4.12.0 | Updated: v4.13.0 | Rule version: v2
///
/// DateTime equality checks fail due to microsecond differences between
/// timestamps that represent the "same" moment. Two DateTimes created
/// independently almost never have identical microsecond values.
///
/// **BAD:**
/// ```dart
/// if (startTime == endTime) { ... }
/// if (created != modified) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (startTime.difference(endTime).abs() < const Duration(seconds: 1)) { ... }
/// if (startTime.isAtSameMomentAs(endTime)) { ... }
/// ```
class AvoidDatetimeComparisonWithoutPrecisionRule extends SaropaLintRule {
  AvoidDatetimeComparisonWithoutPrecisionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            UseDateTimeDifferenceFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_datetime_comparison_without_precision',
    '[avoid_datetime_comparison_without_precision] Direct equality comparison (== or !=) on DateTime objects is unreliable because two timestamps representing the same logical moment almost never share identical microsecond values. Network latency, clock drift, serialization rounding, and independent construction all introduce sub-second differences that cause equality checks to silently fail, leading to missed cache hits, duplicate entries, and incorrect conditional logic. {v2}',
    correctionMessage:
        'Use DateTime.difference().abs() < Duration(threshold) with an appropriate precision, or use isAtSameMomentAs() for UTC-normalized comparison.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;
      if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

      final leftType = node.leftOperand.staticType;
      final rightType = node.rightOperand.staticType;

      // Check if both sides are DateTime
      final bool leftIsDateTime =
          leftType != null && leftType.getDisplayString() == 'DateTime';
      final bool rightIsDateTime =
          rightType != null && rightType.getDisplayString() == 'DateTime';

      if (leftIsDateTime && rightIsDateTime) {
        reporter.atNode(node);
      }
    });
  }
}
