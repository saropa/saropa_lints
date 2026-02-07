// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidEqualExpressionsRule extends SaropaLintRule {
  const AvoidEqualExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_equal_expressions',
    problemMessage:
        '[avoid_equal_expressions] Both sides of the binary expression are identical, meaning the comparison always produces the same result (true for ==, false for >, <). This is almost always a copy-paste bug where the developer intended to compare two different values, and the redundant comparison masks the real logic error in the code.',
    correctionMessage:
        'Replace one side of the expression with the intended comparison target to fix the copy-paste error.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForEqualExpressionsFix()];
}

class _AddHackForEqualExpressionsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for identical expressions',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: both sides are identical - fix one side\n',
        );
      });
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
///
/// **Quick fix available:** Transforms `!(a == b)` to `a != b`.
class AvoidNegationsInEqualityChecksRule extends SaropaLintRule {
  const AvoidNegationsInEqualityChecksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_negations_in_equality_checks',
    problemMessage:
        '[avoid_negations_in_equality_checks] Equality check is wrapped in a negation operator !(a == b) instead of using the direct != operator. The negated form adds unnecessary cognitive overhead, increases nesting depth, and is harder to scan during code review. The != operator expresses the same intent more clearly and concisely.',
    correctionMessage:
        'Replace !(a == b) with a != b for direct and readable inequality checking. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_UseNotEqualsFix()];
}

class _UseNotEqualsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.operator.lexeme != '!') return;

      final Expression operand = node.operand;
      if (operand is! ParenthesizedExpression) return;

      final Expression inner = operand.expression;
      if (inner is! BinaryExpression) return;
      if (inner.operator.lexeme != '==') return;

      final String left = inner.leftOperand.toSource();
      final String right = inner.rightOperand.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with !=',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$left != $right',
        );
      });
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
class AvoidSelfAssignmentRule extends SaropaLintRule {
  const AvoidSelfAssignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_self_assignment',
    problemMessage:
        '[avoid_self_assignment] Variable is assigned to itself (x = x), which has no effect and indicates a copy-paste error or incomplete refactor. The assignment executes at runtime but produces no state change, wasting CPU cycles and obscuring the developer\'s actual intent. This dead code makes maintenance harder because readers must determine whether the assignment was intentional.',
    correctionMessage:
        'Remove the self-assignment entirely, or replace the right-hand side with the intended source value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForSelfAssignmentFix()];
}

class _AddHackForSelfAssignmentFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for self-assignment',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: self-assignment - remove or assign different value\n',
        );
      });
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
class AvoidSelfCompareRule extends SaropaLintRule {
  const AvoidSelfCompareRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_self_compare',
    problemMessage:
        '[avoid_self_compare] Variable is compared to itself (x == x, x > x, etc.), which always produces a constant result (true for ==, false for inequality operators) unless the value is NaN. This is almost always a copy-paste bug where the developer intended to compare two distinct values, and the redundant comparison hides the real logic error in the code.',
    correctionMessage:
        'Use .isNaN for NaN detection, or replace one operand with the intended comparison target.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForSelfCompareFix()];
}

class _AddHackForSelfCompareFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for self-compare',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: comparing to itself - use .isNaN or compare different values\n',
        );
      });
    });
  }
}

/// Warns when compareTo is used for equality instead of ==.
///
/// **Quick fix available:** Transforms `a.compareTo(b) == 0` to `a == b`.
class AvoidUnnecessaryCompareToRule extends SaropaLintRule {
  const AvoidUnnecessaryCompareToRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_compare_to',
    problemMessage:
        '[avoid_unnecessary_compare_to] Using compareTo() == 0 for equality checking is unnecessarily verbose when the == operator expresses the same comparison directly. The compareTo method is designed for ordering (less than, greater than), and using it for equality adds cognitive overhead, increases code length, and obscures the developer\'s intent of a simple equality check.',
    correctionMessage:
        'Replace compareTo(x) == 0 with == x, and compareTo(x) != 0 with != x for clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
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

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseDirectEqualityFix()];
}

class _UseDirectEqualityFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String op = node.operator.lexeme;
      if (op != '==' && op != '!=') return;

      MethodInvocation? compareToCall;

      if (node.leftOperand is MethodInvocation &&
          node.rightOperand is IntegerLiteral) {
        compareToCall = node.leftOperand as MethodInvocation;
      } else if (node.rightOperand is MethodInvocation &&
          node.leftOperand is IntegerLiteral) {
        compareToCall = node.rightOperand as MethodInvocation;
      }

      if (compareToCall == null) return;
      if (compareToCall.methodName.name != 'compareTo') return;
      if (compareToCall.argumentList.arguments.isEmpty) return;

      final Expression? target = compareToCall.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      final String argSource =
          compareToCall.argumentList.arguments.first.toSource();
      final String newOp = op == '==' ? '==' : '!=';

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with $newOp',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$targetSource $newOp $argSource',
        );
      });
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
class NoEqualArgumentsRule extends SaropaLintRule {
  const NoEqualArgumentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_arguments',
    problemMessage:
        '[no_equal_arguments] The same identifier is passed as multiple positional arguments to a function call, which typically indicates a copy-paste error where distinct values were intended (e.g., setPosition(x, x) instead of setPosition(x, y)). This silent bug produces incorrect behavior that passes compilation but yields wrong results at runtime.',
    correctionMessage:
        'Verify whether duplicate arguments are intentional, and replace with the intended distinct values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForEqualArgumentsFix()];
}

class _AddHackForEqualArgumentsFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleIdentifier((SimpleIdentifier node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for duplicate argument',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: duplicate argument - check if intentional */ ',
        );
      });
    });
  }
}

// =============================================================================
// DateTime Comparison Rules
// =============================================================================

/// Warns when DateTime values are compared using == or !=.
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
  const AvoidDatetimeComparisonWithoutPrecisionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_datetime_comparison_without_precision',
    problemMessage:
        '[avoid_datetime_comparison_without_precision] Direct equality comparison (== or !=) on DateTime objects is unreliable because two timestamps representing the same logical moment almost never share identical microsecond values. Network latency, clock drift, serialization rounding, and independent construction all introduce sub-second differences that cause equality checks to silently fail, leading to missed cache hits, duplicate entries, and incorrect conditional logic.',
    correctionMessage:
        'Use DateTime.difference().abs() < Duration(threshold) with an appropriate precision, or use isAtSameMomentAs() for UTC-normalized comparison.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
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
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UseDateTimeDifferenceFix()];
}

class _UseDateTimeDifferenceFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String left = node.leftOperand.toSource();
      final String right = node.rightOperand.toSource();
      final bool isEqual = node.operator.type == TokenType.EQ_EQ;

      final String replacement = isEqual
          ? '$left.difference($right).abs() < const Duration(seconds: 1)'
          : '$left.difference($right).abs() >= const Duration(seconds: 1)';

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with difference threshold comparison',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
    });
  }
}
