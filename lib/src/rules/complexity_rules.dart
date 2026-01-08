// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when bitwise operators are used with boolean operands.
///
/// Using & or | with booleans is likely a mistake; use && or || instead.
/// Bitwise operators don't short-circuit and can cause unexpected behavior.
///
/// Example of **bad** code:
/// ```dart
/// if (a & b) { ... }  // Should be &&
/// bool result = x | y;  // Should be ||
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (a && b) { ... }
/// bool result = x || y;
/// ```
///
/// **Quick fix available:** Replaces `&` with `&&` or `|` with `||`.
class AvoidBitwiseOperatorsWithBooleansRule extends SaropaLintRule {
  const AvoidBitwiseOperatorsWithBooleansRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_bitwise_operators_with_booleans',
    problemMessage:
        'Bitwise operator on boolean. Unlike &&/||, this does not short-circuit.',
    correctionMessage:
        'Use && instead of & and || instead of | for boolean logic.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;

      // Only check & and |
      if (op != TokenType.AMPERSAND && op != TokenType.BAR) return;

      // Check if either operand is boolean
      final DartType? leftType = node.leftOperand.staticType;
      final DartType? rightType = node.rightOperand.staticType;

      final bool leftIsBool = leftType?.getDisplayString() == 'bool';
      final bool rightIsBool = rightType?.getDisplayString() == 'bool';

      if (leftIsBool || rightIsBool) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceBitwiseWithLogicalFix()];
}

/// Warns when cascade is used after if-null operator without parentheses.
///
/// Using cascade after `??` without parentheses can lead to unexpected behavior
/// because `??` has lower precedence than cascade.
///
/// Example of **bad** code:
/// ```dart
/// final list = possibleList ?? <int>[]..add(1);
/// // This is parsed as: possibleList ?? (<int>[]..add(1))
/// // NOT: (possibleList ?? <int>[])..add(1)
/// ```
///
/// Example of **good** code:
/// ```dart
/// final list = (possibleList ?? <int>[])..add(1);
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidCascadeAfterIfNullRule extends SaropaLintRule {
  const AvoidCascadeAfterIfNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_cascade_after_if_null',
    problemMessage: 'Cascade after ?? may have unexpected precedence.',
    correctionMessage:
        'Wrap the ?? expression in parentheses: (a ?? b)..cascade',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      // Check if the target of the cascade is a binary expression with ??
      final Expression target = node.target;
      if (target is BinaryExpression &&
          target.operator.type == TokenType.QUESTION_QUESTION) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForCascadeAfterIfNullFix()];
}

/// Warns when arithmetic expressions are too complex.
///
/// Complex arithmetic expressions are hard to understand and maintain.
/// Consider extracting parts into named variables.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final result = a * b + c / d - e % f + g * h;
/// ```
///
/// #### GOOD:
/// ```dart
/// final product = a * b;
/// final quotient = c / d;
/// final result = product + quotient - e % f + g * h;
/// ```
class AvoidComplexArithmeticExpressionsRule extends SaropaLintRule {
  const AvoidComplexArithmeticExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const int _maxOperators = 4;

  static const LintCode _code = LintCode(
    name: 'avoid_complex_arithmetic_expressions',
    problemMessage:
        'Arithmetic expression has more than $_maxOperators operators.',
    correctionMessage: 'Extract parts into named variables for clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _arithmeticOperators = <String>{
    '+',
    '-',
    '*',
    '/',
    '%',
    '~/',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Only check top-level arithmetic expressions
      if (node.parent is BinaryExpression) return;

      final int count = _countArithmeticOperators(node);
      if (count > _maxOperators) {
        reporter.atNode(node, code);
      }
    });
  }

  int _countArithmeticOperators(Expression node) {
    if (node is BinaryExpression) {
      final String op = node.operator.lexeme;
      final int current = _arithmeticOperators.contains(op) ? 1 : 0;
      return current +
          _countArithmeticOperators(node.leftOperand) +
          _countArithmeticOperators(node.rightOperand);
    }
    if (node is ParenthesizedExpression) {
      return _countArithmeticOperators(node.expression);
    }
    return 0;
  }
}

/// Warns when conditions are too complex.
///
/// Complex conditions with many logical operators are hard to understand.
/// Consider extracting parts into named boolean variables.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (a && b || c && d || e && f) { ... }
/// ```
///
/// #### GOOD:
/// ```dart
/// final isFirstCondition = a && b;
/// final isSecondCondition = c && d;
/// if (isFirstCondition || isSecondCondition || e && f) { ... }
/// ```
class AvoidComplexConditionsRule extends SaropaLintRule {
  const AvoidComplexConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const int _maxOperators = 3;

  static const LintCode _code = LintCode(
    name: 'avoid_complex_conditions',
    problemMessage: 'Condition has more than $_maxOperators logical operators.',
    correctionMessage: 'Extract parts into named boolean variables.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final int count = _countLogicalOperators(node.expression);
      if (count > _maxOperators) {
        reporter.atNode(node.expression, code);
      }
    });

    context.registry.addWhileStatement((WhileStatement node) {
      final int count = _countLogicalOperators(node.condition);
      if (count > _maxOperators) {
        reporter.atNode(node.condition, code);
      }
    });

    context.registry.addConditionalExpression((ConditionalExpression node) {
      final int count = _countLogicalOperators(node.condition);
      if (count > _maxOperators) {
        reporter.atNode(node.condition, code);
      }
    });
  }

  int _countLogicalOperators(Expression node) {
    if (node is BinaryExpression) {
      final String op = node.operator.lexeme;
      final int current = (op == '&&' || op == '||') ? 1 : 0;
      return current +
          _countLogicalOperators(node.leftOperand) +
          _countLogicalOperators(node.rightOperand);
    }
    if (node is ParenthesizedExpression) {
      return _countLogicalOperators(node.expression);
    }
    if (node is PrefixExpression && node.operator.lexeme == '!') {
      return _countLogicalOperators(node.operand);
    }
    return 0;
  }
}

/// Warns when the same cascade operation is performed multiple times.
///
/// Duplicate cascades are often a copy-paste error.
///
/// Example of **bad** code:
/// ```dart
/// list
///   ..add(1)
///   ..add(2)
///   ..add(1);  // Duplicate
/// ```
///
/// Example of **good** code:
/// ```dart
/// list
///   ..add(1)
///   ..add(2)
///   ..add(3);
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidDuplicateCascadesRule extends SaropaLintRule {
  const AvoidDuplicateCascadesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_cascades',
    problemMessage: 'Duplicate cascade operation detected.',
    correctionMessage: 'Remove the duplicate or verify this is intentional.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      final List<Expression> sections = node.cascadeSections;
      final Set<String> seenOperations = <String>{};

      for (final Expression section in sections) {
        final String source = section.toSource();
        if (seenOperations.contains(source)) {
          reporter.atNode(section, code);
        } else {
          seenOperations.add(source);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForDuplicateCascadeFix()];
}

/// Warns when an expression has excessive complexity.
///
/// Complex expressions are hard to read and maintain.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (a && b || c && d || e && f || g && h) { }
/// ```
///
/// #### GOOD:
/// ```dart
/// final condition1 = a && b;
/// final condition2 = c && d;
/// if (condition1 || condition2) { }
/// ```
class AvoidExcessiveExpressionsRule extends SaropaLintRule {
  const AvoidExcessiveExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const int _maxOperators = 5;

  static const LintCode _code = LintCode(
    name: 'avoid_excessive_expressions',
    problemMessage:
        'Expression has excessive complexity (>$_maxOperators operators).',
    correctionMessage: 'Break into smaller expressions with named variables.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Only check top-level binary expressions
      if (node.parent is BinaryExpression) return;

      final int operatorCount = _countOperators(node);
      if (operatorCount > _maxOperators) {
        reporter.atNode(node, code);
      }
    });
  }

  int _countOperators(Expression node) {
    if (node is BinaryExpression) {
      return 1 +
          _countOperators(node.leftOperand) +
          _countOperators(node.rightOperand);
    } else if (node is ParenthesizedExpression) {
      return _countOperators(node.expression);
    }
    return 0;
  }
}

/// Warns when a function is immediately invoked after definition.
///
/// Immediately invoked function expressions (IIFE) can be confusing
/// and usually indicate the code should be refactored.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final result = (() {
///   final temp = compute();
///   return temp * 2;
/// })();
/// ```
///
/// #### GOOD:
/// ```dart
/// final temp = compute();
/// final result = temp * 2;
/// // or extract to a named function
/// int computeDouble() {
///   final temp = compute();
///   return temp * 2;
/// }
/// ```
class AvoidImmediatelyInvokedFunctionsRule extends SaropaLintRule {
  const AvoidImmediatelyInvokedFunctionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_immediately_invoked_functions',
    problemMessage: 'Function is immediately invoked after definition.',
    correctionMessage: 'Extract the logic inline or to a named function.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addFunctionExpressionInvocation((FunctionExpressionInvocation node) {
      final Expression function = node.function;

      // Check for (expression)() pattern
      if (function is ParenthesizedExpression) {
        final Expression inner = function.expression;
        if (inner is FunctionExpression) {
          reporter.atNode(node, code);
        }
      }

      // Check for direct function expression invocation
      if (function is FunctionExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when shorthand syntax is nested too deeply.
class AvoidNestedShorthandsRule extends SaropaLintRule {
  const AvoidNestedShorthandsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_shorthands',
    problemMessage: 'Avoid nesting shorthand syntax too deeply.',
    correctionMessage: 'Extract nested expressions to improve readability.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((ConditionalExpression node) {
      // Check for nested ternary operators
      if (node.thenExpression is ConditionalExpression ||
          node.elseExpression is ConditionalExpression) {
        reporter.atNode(node, code);
      }
    });

    context.registry.addCascadeExpression((CascadeExpression node) {
      // Check for nested cascades
      for (final Expression section in node.cascadeSections) {
        if (section is CascadeExpression) {
          reporter.atNode(section, code);
        }
      }
    });

    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for nested null-aware operators
      if (node.operator.lexeme == '??') {
        if (node.rightOperand is BinaryExpression) {
          final BinaryExpression right = node.rightOperand as BinaryExpression;
          if (right.operator.lexeme == '??') {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when multiple assignments are chained on one line.
///
/// Chained assignments reduce readability and can be confusing.
///
/// Example of **bad** code:
/// ```dart
/// a = b = c = 0;
/// ```
///
/// Example of **good** code:
/// ```dart
/// a = 0;
/// b = 0;
/// c = 0;
/// ```
class AvoidMultiAssignmentRule extends SaropaLintRule {
  const AvoidMultiAssignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_multi_assignment',
    problemMessage: 'Multiple chained assignments detected.',
    correctionMessage: 'Split into separate assignment statements.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check if the right side is also an assignment
      if (node.rightHandSide is AssignmentExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when binary expression operands could be reordered for clarity.
///
/// Prefer having the variable on the left side of comparisons for readability.
/// Example: Prefer `x == 5` over `5 == x`.
class BinaryExpressionOperandOrderRule extends SaropaLintRule {
  const BinaryExpressionOperandOrderRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'binary_expression_operand_order',
    problemMessage: 'Consider reordering operands for readability.',
    correctionMessage: 'Place the variable on the left side of the comparison.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      // Check for comparison operators
      final TokenType op = node.operator.type;
      if (op == TokenType.EQ_EQ || op == TokenType.BANG_EQ) {
        // If left is literal and right is identifier, suggest swap
        if (node.leftOperand is Literal && node.rightOperand is Identifier) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when an expression is repeated and could be extracted to a variable.
///
/// Repeated expressions can be error-prone and inefficient. Consider
/// extracting them to a local variable.
class PreferMovingToVariableRule extends SaropaLintRule {
  const PreferMovingToVariableRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_moving_to_variable',
    problemMessage: 'Consider extracting repeated expression to a variable.',
    correctionMessage: 'Extract to a local variable to avoid repetition.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      final Map<String, List<Expression>> expressions =
          <String, List<Expression>>{};

      // Collect method invocations and property accesses
      node.visitChildren(
        _ExpressionCollector((Expression expr) {
          final String source = expr.toSource();
          // Only track non-trivial expressions
          if (source.contains('.') || source.contains('(')) {
            expressions.putIfAbsent(source, () => <Expression>[]).add(expr);
          }
        }),
      );

      // Report expressions that appear more than twice
      for (final MapEntry<String, List<Expression>> entry
          in expressions.entries) {
        if (entry.value.length > 2) {
          reporter.atNode(entry.value.first, code);
        }
      }
    });
  }
}

class _ExpressionCollector extends RecursiveAstVisitor<void> {
  _ExpressionCollector(this.onExpression);
  final void Function(Expression) onExpression;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onExpression(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    onExpression(node);
    super.visitPropertyAccess(node);
  }
}

/// Warns when if-null operator (??) is used without parentheses in
/// potentially ambiguous expressions.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final x = a ?? b + c; // Is this (a ?? b) + c or a ?? (b + c)?
/// final y = a * b ?? c; // Ambiguous
/// ```
///
/// #### GOOD:
/// ```dart
/// final x = a ?? (b + c);
/// final y = (a * b) ?? c;
/// ```
class PreferParenthesesWithIfNullRule extends SaropaLintRule {
  const PreferParenthesesWithIfNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_parentheses_with_if_null',
    problemMessage: 'Add parentheses to clarify if-null expression precedence.',
    correctionMessage: 'Wrap operands in parentheses for clarity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.lexeme != '??') return;

      // Check if either operand is a binary expression without parentheses
      final Expression left = node.leftOperand;
      final Expression right = node.rightOperand;

      // Left operand being a binary expression is more dangerous
      if (left is BinaryExpression) {
        final String op = left.operator.lexeme;
        // Skip comparison operators which are usually clear
        if (op != '==' &&
            op != '!=' &&
            op != '>' &&
            op != '<' &&
            op != '>=' &&
            op != '<=') {
          reporter.atNode(node, code);
          return;
        }
      }

      // Right operand with arithmetic can also be ambiguous
      if (right is BinaryExpression) {
        final String op = right.operator.lexeme;
        if (op == '+' || op == '-' || op == '*' || op == '/') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

class _ReplaceBitwiseWithLogicalFix extends DartFix {
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

      final TokenType op = node.operator.type;
      if (op != TokenType.AMPERSAND && op != TokenType.BAR) return;

      final String newOp = op == TokenType.AMPERSAND ? '&&' : '||';
      final String left = node.leftOperand.toSource();
      final String right = node.rightOperand.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with $newOp',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.sourceRange,
          '$left $newOp $right',
        );
      });
    });
  }
}

class _AddHackForCascadeAfterIfNullFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for cascade precedence',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: wrap ?? expression in parentheses\n',
        );
      });
    });
  }
}

class _AddHackForDuplicateCascadeFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCascadeExpression((CascadeExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for duplicate cascade',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: duplicate cascade - remove or verify intentional\n',
        );
      });
    });
  }
}
