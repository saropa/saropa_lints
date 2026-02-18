// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import '../fixes/complexity/replace_bitwise_with_logical_fix.dart';
import '../saropa_lint_rule.dart';

/// Warns when bitwise operators are used with boolean operands.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidBitwiseOperatorsWithBooleansRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_bitwise_operators_with_booleans',
    '[avoid_bitwise_operators_with_booleans] Bitwise operator on boolean. Unlike &&/||, this does not short-circuit. Using & or | with booleans is likely a mistake; use && or || instead. Bitwise operators don\'t short-circuit and can cause unexpected behavior. {v4}',
    correctionMessage:
        'Use && instead of & and || instead of | for boolean logic. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;

      // Only check & and |
      if (op != TokenType.AMPERSAND && op != TokenType.BAR) return;

      // Check if either operand is boolean
      final DartType? leftType = node.leftOperand.staticType;
      final DartType? rightType = node.rightOperand.staticType;

      final bool leftIsBool = leftType?.getDisplayString() == 'bool';
      final bool rightIsBool = rightType?.getDisplayString() == 'bool';

      if (leftIsBool || rightIsBool) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            ReplaceBitwiseWithLogicalFix(context: context),
      ];
}

/// Warns when cascade is used after if-null operator without parentheses.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidCascadeAfterIfNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_cascade_after_if_null',
    '[avoid_cascade_after_if_null] Cascade after ?? may have unexpected precedence. Using cascade after ?? without parentheses can lead to unexpected behavior because ?? has lower precedence than cascade. {v5}',
    correctionMessage:
        'Wrap the ?? expression in parentheses: (a ?? b).cascade. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCascadeExpression((CascadeExpression node) {
      // Check if the target of the cascade is a binary expression with ??
      final Expression target = node.target;
      if (target is BinaryExpression &&
          target.operator.type == TokenType.QUESTION_QUESTION) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when arithmetic expressions are too complex.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidComplexArithmeticExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxOperators = 4;

  static const LintCode _code = LintCode(
    'avoid_complex_arithmetic_expressions',
    '[avoid_complex_arithmetic_expressions] Arithmetic expression has more than $_maxOperators operators. Complex arithmetic expressions are hard to understand and maintain. Extract parts into named variables. {v4}',
    correctionMessage:
        'Extract parts into named variables for clarity. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Only check top-level arithmetic expressions
      if (node.parent is BinaryExpression) return;

      final int count = _countArithmeticOperators(node);
      if (count > _maxOperators) {
        reporter.atNode(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
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
  AvoidComplexConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxOperators = 3;

  static const LintCode _code = LintCode(
    'avoid_complex_conditions',
    '[avoid_complex_conditions] Condition has more than $_maxOperators logical operators. Complex conditions with many logical operators are hard to understand. Extract parts into named boolean variables. {v3}',
    correctionMessage:
        'Extract parts into named boolean variables. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      final int count = _countLogicalOperators(node.expression);
      if (count > _maxOperators) {
        reporter.atNode(node.expression, code);
      }
    });

    context.addWhileStatement((WhileStatement node) {
      final int count = _countLogicalOperators(node.condition);
      if (count > _maxOperators) {
        reporter.atNode(node.condition, code);
      }
    });

    context.addConditionalExpression((ConditionalExpression node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidDuplicateCascadesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_cascades',
    '[avoid_duplicate_cascades] Duplicate cascade operation detected on the same target. Identical cascade members are likely copy-paste errors that produce redundant side effects and increase maintenance risk. {v4}',
    correctionMessage:
        'Remove the duplicate or verify this is intentional. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCascadeExpression((CascadeExpression node) {
      final List<Expression> sections = node.cascadeSections;
      final Set<String> seenOperations = <String>{};

      for (final Expression section in sections) {
        final String source = section.toSource();
        if (seenOperations.contains(source)) {
          reporter.atNode(section);
        } else {
          seenOperations.add(source);
        }
      }
    });
  }
}

/// Warns when an expression has excessive complexity.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidExcessiveExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _maxOperators = 5;

  static const LintCode _code = LintCode(
    'avoid_excessive_expressions',
    '[avoid_excessive_expressions] Expression has excessive complexity (>$_maxOperators operators). Complex expressions are hard to read and maintain. This excessive complexity makes the code harder to understand, test, and maintain. {v4}',
    correctionMessage:
        'Break into smaller expressions with named variables. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Only check top-level binary expressions
      if (node.parent is BinaryExpression) return;

      final int operatorCount = _countOperators(node);
      if (operatorCount > _maxOperators) {
        reporter.atNode(node);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidImmediatelyInvokedFunctionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_immediately_invoked_functions',
    '[avoid_immediately_invoked_functions] Function is immediately invoked after definition. Immediately invoked function expressions (IIFE) can be confusing and usually indicate the code must be refactored. {v4}',
    correctionMessage:
        'Extract the logic inline or to a named function. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;

      // Check for (expression)() pattern
      if (function is ParenthesizedExpression) {
        final Expression inner = function.expression;
        if (inner is FunctionExpression) {
          reporter.atNode(node);
        }
      }

      // Check for direct function expression invocation
      if (function is FunctionExpression) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when shorthand syntax is nested too deeply.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
class AvoidNestedShorthandsRule extends SaropaLintRule {
  AvoidNestedShorthandsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nested_shorthands',
    '[avoid_nested_shorthands] Deeply nested shorthand syntax (e.g., cascades inside ternaries inside null-aware operators) reduces readability and makes expressions difficult to understand at a glance. Each nesting level multiplies cognitive load, increasing the risk of logic errors during code review and maintenance. {v5}',
    correctionMessage:
        'Extract nested expressions into named local variables or helper methods. Each intermediate value should have a descriptive name that communicates its purpose, making the overall logic easier to follow, test, and debug.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConditionalExpression((ConditionalExpression node) {
      // Check for nested ternary operators
      if (node.thenExpression is ConditionalExpression ||
          node.elseExpression is ConditionalExpression) {
        reporter.atNode(node);
      }
    });

    context.addCascadeExpression((CascadeExpression node) {
      // Check for nested cascades
      for (final Expression section in node.cascadeSections) {
        if (section is CascadeExpression) {
          reporter.atNode(section);
        }
      }
    });

    context.addBinaryExpression((BinaryExpression node) {
      // Check for nested null-aware operators
      if (node.operator.lexeme == '??') {
        if (node.rightOperand is BinaryExpression) {
          final BinaryExpression right = node.rightOperand as BinaryExpression;
          if (right.operator.lexeme == '??') {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when multiple assignments are chained on one line.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidMultiAssignmentRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_multi_assignment',
    '[avoid_multi_assignment] Multiple chained assignments detected. Chained assignments reduce readability and can be confusing. This excessive complexity makes the code harder to understand, test, and maintain. {v4}',
    correctionMessage:
        'Split into separate assignment statements. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAssignmentExpression((AssignmentExpression node) {
      // Check if the right side is also an assignment
      if (node.rightHandSide is AssignmentExpression) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when binary expression operands could be reordered for clarity.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Prefer having the variable on the left side of comparisons for readability.
/// Example: Prefer `x == 5` over `5 == x`.
class BinaryExpressionOperandOrderRule extends SaropaLintRule {
  BinaryExpressionOperandOrderRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    'binary_expression_operand_order',
    '[binary_expression_operand_order] Preferring a specific operand order in binary expressions is a stylistic convention. Both orderings produce equivalent compiled code. Enable via the stylistic tier. {v3}',
    correctionMessage:
        'Place the variable or expression on the left side and the constant on the right (e.g., "status == 200" instead of "200 == status") to match natural language order and improve readability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Check for comparison operators
      final TokenType op = node.operator.type;
      if (op == TokenType.EQ_EQ || op == TokenType.BANG_EQ) {
        // If left is literal and right is identifier, suggest swap
        if (node.leftOperand is Literal && node.rightOperand is Identifier) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when an expression is repeated and could be extracted to a variable.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Repeated expressions can be error-prone and inefficient. Consider
/// extracting them to a local variable.
class PreferMovingToVariableRule extends SaropaLintRule {
  PreferMovingToVariableRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_moving_to_variable',
    '[prefer_moving_to_variable] Expression repeated multiple times within the same scope. Repeated expressions waste CPU recalculating the same value, make code harder to maintain when the logic changes, and increase the chance of typos creating subtle bugs. {v4}',
    correctionMessage:
        'Extract the repeated expression into a descriptive local variable calculated once and reused. This improves performance, makes the code DRY (Don\'t Repeat Yourself), and ensures consistency if the expression value is used multiple times.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
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
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
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
  PreferParenthesesWithIfNullRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_parentheses_with_if_null',
    '[prefer_parentheses_with_if_null] Add parentheses to clarify if-null expression precedence. If-null operator (??) is used without parentheses in potentially ambiguous expressions. This excessive complexity makes the code harder to understand, test, and maintain. {v4}',
    correctionMessage:
        'Wrap operands in parentheses for clarity. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
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
          reporter.atNode(node);
          return;
        }
      }

      // Right operand with arithmetic can also be ambiguous
      if (right is BinaryExpression) {
        final String op = right.operator.lexeme;
        if (op == '+' || op == '-' || op == '*' || op == '/') {
          reporter.atNode(node);
        }
      }
    });
  }
}
