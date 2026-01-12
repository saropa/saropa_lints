// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when an assignment is used inside a condition.
///
/// Example of **bad** code:
/// ```dart
/// if (x = 5) { }
/// while (y = getValue()) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// x = 5;
/// if (x != 0) { }
/// ```
class AvoidAssignmentsAsConditionsRule extends SaropaLintRule {
  const AvoidAssignmentsAsConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_assignments_as_conditions',
    problemMessage:
        '[avoid_assignments_as_conditions] Assignment in condition. Likely meant == comparison, not = assignment.',
    correctionMessage:
        'Use == for comparison, or move assignment before the condition.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if statements
    context.registry.addIfStatement((IfStatement node) {
      _checkCondition(node.expression, reporter);
    });

    // Check while statements
    context.registry.addWhileStatement((WhileStatement node) {
      _checkCondition(node.condition, reporter);
    });

    // Check do-while statements
    context.registry.addDoStatement((DoStatement node) {
      _checkCondition(node.condition, reporter);
    });

    // Check for statements (ForStatement uses forLoopParts)
    context.registry.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is ForParts) {
        final Expression? condition = parts.condition;
        if (condition != null) {
          _checkCondition(condition, reporter);
        }
      }
    });

    // Check ternary expressions
    context.registry.addConditionalExpression((ConditionalExpression node) {
      _checkCondition(node.condition, reporter);
    });
  }

  void _checkCondition(
      Expression condition, SaropaDiagnosticReporter reporter) {
    if (condition is AssignmentExpression) {
      reporter.atNode(condition, code);
    }
    // Check for parenthesized assignment
    if (condition is ParenthesizedExpression) {
      if (condition.expression is AssignmentExpression) {
        reporter.atNode(condition, code);
      }
    }
  }
}

/// Warns when nested if statements can be collapsed into one.
///
/// Nested if statements without else clauses can often be combined
/// using && for cleaner code.
///
/// Example of **bad** code:
/// ```dart
/// if (a) {
///   if (b) {
///     doSomething();
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (a && b) {
///   doSomething();
/// }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for refactoring.
class AvoidCollapsibleIfRule extends SaropaLintRule {
  const AvoidCollapsibleIfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_collapsible_if',
    problemMessage:
        '[avoid_collapsible_if] Nested if without else. Extra nesting reduces readability.',
    correctionMessage: 'Combine into single if: if (a && b) { ... }.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Skip if has else clause
      if (node.elseStatement != null) return;

      // Check if the then body is a single if statement
      final Statement thenStmt = node.thenStatement;

      IfStatement? innerIf;
      if (thenStmt is IfStatement) {
        innerIf = thenStmt;
      } else if (thenStmt is Block && thenStmt.statements.length == 1) {
        final Statement single = thenStmt.statements.first;
        if (single is IfStatement) {
          innerIf = single;
        }
      }

      if (innerIf == null) return;

      // Skip if inner if has else clause
      if (innerIf.elseStatement != null) return;

      // Report collapsible if
      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForCollapsibleIfFix()];
}

class _AddHackForCollapsibleIfFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment to collapse if statements',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: collapse nested if using && operator\n    ',
        );
      });
    });
  }
}

/// Warns when boolean literals are used in conditions.
///
/// Example of **bad** code:
/// ```dart
/// if (x == true) { }
/// if (y || false) { }
/// if (z && true) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (x) { }
/// if (y) { }
/// if (z) { }
/// ```
///
/// **Quick fix available:** Simplifies `x == true` to `x`, `x == false` to `!x`, etc.
class AvoidConditionsWithBooleanLiteralsRule extends SaropaLintRule {
  const AvoidConditionsWithBooleanLiteralsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_conditions_with_boolean_literals',
    problemMessage:
        '[avoid_conditions_with_boolean_literals] Avoid comparing with boolean literals or using them in logical expressions.',
    correctionMessage:
        'Use the boolean expression directly: x instead of x == true.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBinaryExpression((BinaryExpression node) {
      final TokenType operator = node.operator.type;

      // Check for x == true, x == false, x != true, x != false
      if (operator == TokenType.EQ_EQ || operator == TokenType.BANG_EQ) {
        if (node.leftOperand is BooleanLiteral ||
            node.rightOperand is BooleanLiteral) {
          reporter.atNode(node, code);
        }
      }

      // Check for x || true, x || false, x && true, x && false
      if (operator == TokenType.BAR_BAR ||
          operator == TokenType.AMPERSAND_AMPERSAND) {
        if (node.leftOperand is BooleanLiteral ||
            node.rightOperand is BooleanLiteral) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_SimplifyBooleanComparisonFix()];
}

class _SimplifyBooleanComparisonFix extends DartFix {
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

      final TokenType operator = node.operator.type;
      String? replacement;

      // Handle x == true, x == false, x != true, x != false
      if (operator == TokenType.EQ_EQ || operator == TokenType.BANG_EQ) {
        final bool isEquals = operator == TokenType.EQ_EQ;

        if (node.rightOperand is BooleanLiteral) {
          final bool literalValue = (node.rightOperand as BooleanLiteral).value;
          final String expr = node.leftOperand.toSource();
          // x == true -> x, x == false -> !x, x != true -> !x, x != false -> x
          if (isEquals == literalValue) {
            replacement = expr;
          } else {
            replacement = '!$expr';
          }
        } else if (node.leftOperand is BooleanLiteral) {
          final bool literalValue = (node.leftOperand as BooleanLiteral).value;
          final String expr = node.rightOperand.toSource();
          if (isEquals == literalValue) {
            replacement = expr;
          } else {
            replacement = '!$expr';
          }
        }
      }

      if (replacement == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Simplify boolean comparison',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement!,
        );
      });
    });
  }
}

/// Warns when assert has a constant condition (always true or always false).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// assert(true);
/// assert(false);
/// assert(1 == 1);
/// ```
///
/// #### GOOD:
/// ```dart
/// assert(value != null);
/// assert(list.isNotEmpty);
/// ```
class AvoidConstantAssertConditionsRule extends SaropaLintRule {
  const AvoidConstantAssertConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_constant_assert_conditions',
    problemMessage:
        '[avoid_constant_assert_conditions] Assert has a constant condition that is always {0}.',
    correctionMessage:
        'Use a meaningful condition or remove the assert statement.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssertStatement((AssertStatement node) {
      final Expression condition = node.condition;

      if (condition is BooleanLiteral) {
        reporter.atNode(node, code);
        return;
      }

      // Check for constant binary expressions like 1 == 1
      if (condition is BinaryExpression) {
        final Expression left = condition.leftOperand;
        final Expression right = condition.rightOperand;

        // Check if both sides are the same literal
        if (_areSameLiteral(left, right)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _areSameLiteral(Expression left, Expression right) {
    if (left is IntegerLiteral && right is IntegerLiteral) {
      return left.value == right.value;
    }
    if (left is DoubleLiteral && right is DoubleLiteral) {
      return left.value == right.value;
    }
    if (left is SimpleStringLiteral && right is SimpleStringLiteral) {
      return left.value == right.value;
    }
    if (left is BooleanLiteral && right is BooleanLiteral) {
      return left.value == right.value;
    }
    return false;
  }
}

/// Warns when switch statement has a constant expression.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (true) { ... }
/// switch (1) { ... }
/// switch ('constant') { ... }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (variable) { ... }
/// switch (getValue()) { ... }
/// ```
class AvoidConstantSwitchesRule extends SaropaLintRule {
  const AvoidConstantSwitchesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_constant_switches',
    problemMessage:
        '[avoid_constant_switches] Switch expression is a constant value.',
    correctionMessage:
        'Use a variable or expression, or replace with if statement.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      if (_isConstantExpression(node.expression)) {
        reporter.atNode(node.expression, code);
      }
    });

    context.registry.addSwitchExpression((SwitchExpression node) {
      if (_isConstantExpression(node.expression)) {
        reporter.atNode(node.expression, code);
      }
    });
  }

  bool _isConstantExpression(Expression expr) {
    return expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is SimpleStringLiteral ||
        expr is NullLiteral;
  }
}

/// Warns when the continue statement is used.
///
/// Example of **bad** code:
/// ```dart
/// for (final item in items) {
///   if (item.isEmpty) continue;
///   process(item);
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// for (final item in items) {
///   if (item.isNotEmpty) {
///     process(item);
///   }
/// }
/// ```
class AvoidContinueRule extends SaropaLintRule {
  const AvoidContinueRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_continue',
    problemMessage: '[avoid_continue] Avoid using the continue statement.',
    correctionMessage: 'Restructure the loop logic to avoid continue.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addContinueStatement((ContinueStatement node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when switch case has duplicate conditions.
///
/// Duplicate case conditions are usually a copy-paste error.
///
/// Example of **bad** code:
/// ```dart
/// switch (value) {
///   case 1:
///     doSomething();
///     break;
///   case 1:  // Duplicate!
///     doSomethingElse();
///     break;
/// }
/// ```
class AvoidDuplicateSwitchCaseConditionsRule extends SaropaLintRule {
  const AvoidDuplicateSwitchCaseConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_duplicate_switch_case_conditions',
    problemMessage:
        '[avoid_duplicate_switch_case_conditions] Duplicate switch case condition detected.',
    correctionMessage: 'Remove the duplicate case or use a different value.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final Set<String> seenConditions = <String>{};

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase) {
          final String condition = member.expression.toSource();
          if (seenConditions.contains(condition)) {
            reporter.atNode(member.expression, code);
          } else {
            seenConditions.add(condition);
          }
        }
      }
    });

    context.registry.addSwitchExpression((SwitchExpression node) {
      final Set<String> seenConditions = <String>{};

      for (final SwitchExpressionCase switchCase in node.cases) {
        final String pattern = switchCase.guardedPattern.pattern.toSource();
        if (seenConditions.contains(pattern)) {
          reporter.atNode(switchCase.guardedPattern.pattern, code);
        } else {
          seenConditions.add(pattern);
        }
      }
    });
  }
}

/// Warns when an if statement has too many branches.
///
/// Example of **bad** code:
/// ```dart
/// if (a) { }
/// else if (b) { }
/// else if (c) { }
/// else if (d) { }
/// else if (e) { }
/// else { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (value) {
///   case a: ...
///   case b: ...
/// }
/// ```
class AvoidIfWithManyBranchesRule extends SaropaLintRule {
  const AvoidIfWithManyBranchesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_if_with_many_branches',
    problemMessage:
        '[avoid_if_with_many_branches] If statement has too many branches (max 4).',
    correctionMessage:
        'Consider using a switch statement or extracting to methods.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _maxBranches = 4;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only check top-level if statements (not else-if)
      // Check if this if is the else branch of another if
      final AstNode? parent = node.parent;
      if (parent is IfStatement && parent.elseStatement == node) return;

      int branches = 1;
      Statement? current = node.elseStatement;
      while (current is IfStatement) {
        branches++;
        current = current.elseStatement;
      }
      if (current != null) branches++; // final else

      if (branches > _maxBranches) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }
}

/// Warns when an inverted boolean check is used.
///
/// Example of **bad** code:
/// ```dart
/// if (!(a == b)) { }
/// if (!(a > b)) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (a != b) { }
/// if (a <= b) { }
/// ```
///
/// **Quick fix available:** Inverts the operator (e.g., `!(a > b)` → `a <= b`).
class AvoidInvertedBooleanChecksRule extends SaropaLintRule {
  const AvoidInvertedBooleanChecksRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_inverted_boolean_checks',
    problemMessage:
        '[avoid_inverted_boolean_checks] Inverted boolean check can be simplified.',
    correctionMessage: 'Use the opposite operator instead of negating.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;
      // Check for !(a == b), !(a != b), !(a > b), etc.
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression) {
          final TokenType op = inner.operator.type;
          if (op == TokenType.EQ_EQ ||
              op == TokenType.BANG_EQ ||
              op == TokenType.LT ||
              op == TokenType.GT ||
              op == TokenType.LT_EQ ||
              op == TokenType.GT_EQ) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_InvertOperatorFix()];
}

class _InvertOperatorFix extends DartFix {
  static const Map<TokenType, String> _oppositeOperators = <TokenType, String>{
    TokenType.EQ_EQ: '!=',
    TokenType.BANG_EQ: '==',
    TokenType.LT: '>=',
    TokenType.GT: '<=',
    TokenType.LT_EQ: '>',
    TokenType.GT_EQ: '<',
  };

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
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;
      if (operand is! ParenthesizedExpression) return;

      final Expression inner = operand.expression;
      if (inner is! BinaryExpression) return;

      final String? oppositeOp = _oppositeOperators[inner.operator.type];
      if (oppositeOp == null) return;

      final String left = inner.leftOperand.toSource();
      final String right = inner.rightOperand.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use $oppositeOp operator',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$left $oppositeOp $right',
        );
      });
    });
  }
}

/// Warns when a negated condition can be simplified.
///
/// Example of **bad** code:
/// ```dart
/// if (!list.isEmpty) { }
/// if (!condition == false) { }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (list.isNotEmpty) { }
/// if (condition) { }
/// ```
///
/// **Quick fix available:** Replaces `!x.isEmpty` with `x.isNotEmpty`.
class AvoidNegatedConditionsRule extends SaropaLintRule {
  const AvoidNegatedConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_negated_conditions',
    problemMessage:
        '[avoid_negated_conditions] Negated condition can be simplified.',
    correctionMessage: 'Use the positive form (isNotEmpty, != null, etc.).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const List<String> _negateableMethods = <String>[
    'isEmpty',
    'isEven',
    'isOdd',
    'isNaN',
    'isInfinite',
    'isNegative',
    'isFinite',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;
      // Check for !x.isEmpty -> x.isNotEmpty
      if (operand is PropertyAccess) {
        final String propertyName = operand.propertyName.name;
        if (_negateableMethods.contains(propertyName)) {
          reporter.atNode(node, code);
        }
      }
      // Check for !x.isEmpty on simple identifiers
      if (operand is PrefixedIdentifier) {
        final String propertyName = operand.identifier.name;
        if (_negateableMethods.contains(propertyName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_UsePositiveFormFix()];
}

class _UsePositiveFormFix extends DartFix {
  static const Map<String, String> _positiveAlternatives = <String, String>{
    'isEmpty': 'isNotEmpty',
    'isEven': 'isOdd',
    'isOdd': 'isEven',
  };

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
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;
      String? targetSource;
      String? propertyName;

      if (operand is PropertyAccess) {
        targetSource = operand.target?.toSource();
        propertyName = operand.propertyName.name;
      } else if (operand is PrefixedIdentifier) {
        targetSource = operand.prefix.name;
        propertyName = operand.identifier.name;
      }

      if (targetSource == null || propertyName == null) return;

      final String? positiveForm = _positiveAlternatives[propertyName];
      if (positiveForm == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Use $positiveForm',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '$targetSource.$positiveForm',
        );
      });
    });
  }
}

/// Warns when assignment is used inside another expression.
///
/// Nested assignments make code harder to read and can hide bugs.
/// Extract assignments to separate statements.
///
/// Example of **bad** code:
/// ```dart
/// if ((x = getValue()) != null) { ... }
/// list.add(y = compute());
/// ```
///
/// Example of **good** code:
/// ```dart
/// x = getValue();
/// if (x != null) { ... }
///
/// y = compute();
/// list.add(y);
/// ```
class AvoidNestedAssignmentsRule extends SaropaLintRule {
  const AvoidNestedAssignmentsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_assignments',
    problemMessage:
        '[avoid_nested_assignments] Avoid using assignment inside another expression.',
    correctionMessage: 'Extract the assignment to a separate statement.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssignmentExpression((AssignmentExpression node) {
      // Check if this assignment is nested inside another expression
      final AstNode? parent = node.parent;

      // Skip if parent is ExpressionStatement (standalone assignment)
      if (parent is ExpressionStatement) return;

      // Skip if parent is ForEachParts (for-in loop variable)
      if (parent is ForEachParts) return;

      // Skip if parent is VariableDeclaration
      if (parent is VariableDeclaration) return;

      // Report nested assignment
      reporter.atNode(node, code);
    });
  }
}

/// Warns when conditional expressions (ternary operators) are nested.
///
/// Nested ternary operators can be hard to read. Consider using if-else
/// statements or extracting logic into separate methods.
class AvoidNestedConditionalExpressionsRule extends SaropaLintRule {
  const AvoidNestedConditionalExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_conditional_expressions',
    problemMessage:
        '[avoid_nested_conditional_expressions] Avoid nested conditional expressions.',
    correctionMessage: 'Use if-else statements or extract to a method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addConditionalExpression((ConditionalExpression node) {
      // Only report on the OUTERMOST conditional to avoid double reporting
      // Check if this conditional is nested inside another conditional
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is ConditionalExpression) {
          // This is an inner conditional - don't report, let outer one report
          return;
        }
        // Stop at statement level
        if (parent is Statement || parent is Declaration) break;
        parent = parent.parent;
      }

      // Now check if this outermost conditional has nested conditionals
      if (node.thenExpression is ConditionalExpression ||
          node.elseExpression is ConditionalExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when switch statements are nested.
///
/// Example of **bad** code:
/// ```dart
/// switch (a) {
///   case 1:
///     switch (b) {  // Nested switch
///       case 2: break;
///     }
/// }
/// ```
class AvoidNestedSwitchesRule extends SaropaLintRule {
  const AvoidNestedSwitchesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_switches',
    problemMessage: '[avoid_nested_switches] Avoid nested switch statements.',
    correctionMessage: 'Extract the inner switch to a separate method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      // Check if this switch is inside another switch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is SwitchStatement) {
          reporter.atToken(node.switchKeyword, code);
          return;
        }
        // Stop at function boundaries
        if (current is FunctionBody ||
            current is FunctionExpression ||
            current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when a switch expression is nested inside another switch.
///
/// Nested switch expressions are hard to read. Consider extracting
/// the inner switch to a separate function.
///
/// Example of **bad** code:
/// ```dart
/// final result = switch (a) {
///   1 => switch (b) {  // Nested switch
///     true => 'yes',
///     false => 'no',
///   },
///   _ => 'other',
/// };
/// ```
///
/// Example of **good** code:
/// ```dart
/// String getInnerResult(bool b) => switch (b) {
///   true => 'yes',
///   false => 'no',
/// };
/// final result = switch (a) {
///   1 => getInnerResult(b),
///   _ => 'other',
/// };
/// ```
class AvoidNestedSwitchExpressionsRule extends SaropaLintRule {
  const AvoidNestedSwitchExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_switch_expressions',
    problemMessage:
        '[avoid_nested_switch_expressions] Avoid nested switch expressions.',
    correctionMessage: 'Extract the inner switch to a separate function.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchExpression((SwitchExpression node) {
      // Check if this switch is inside another switch expression
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is SwitchExpression) {
          reporter.atNode(node, code);
          return;
        }
        // Stop at function boundaries
        if (parent is FunctionExpression ||
            parent is MethodDeclaration ||
            parent is FunctionDeclaration) {
          return;
        }
        parent = parent.parent;
      }
    });
  }
}

/// Warns when try statements are nested.
///
/// Example of **bad** code:
/// ```dart
/// try {
///   try {
///     // nested try
///   } catch (e) { }
/// } catch (e) { }
/// ```
class AvoidNestedTryRule extends SaropaLintRule {
  const AvoidNestedTryRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_try',
    problemMessage: '[avoid_nested_try] Avoid nested try statements.',
    correctionMessage: 'Extract the inner try to a separate method.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      // Check if this try is inside another try
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) {
          reporter.atToken(node.tryKeyword, code);
          return;
        }
        // Stop at function boundaries
        if (current is FunctionBody ||
            current is FunctionExpression ||
            current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when else is redundant after a return/throw/continue/break.
///
/// Example of **bad** code:
/// ```dart
/// if (condition) {
///   return 1;
/// } else {
///   return 2;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (condition) {
///   return 1;
/// }
/// return 2;
/// ```
class AvoidRedundantElseRule extends SaropaLintRule {
  const AvoidRedundantElseRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_else',
    problemMessage:
        '[avoid_redundant_else] Else is redundant after return/throw/break/continue.',
    correctionMessage: 'Remove the else clause and un-indent the code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      // Check if then branch ends with return/throw/break/continue
      if (_endsWithAbruptCompletion(node.thenStatement)) {
        reporter.atToken(node.elseKeyword!, code);
      }
    });
  }

  bool _endsWithAbruptCompletion(Statement statement) {
    if (statement is ReturnStatement ||
        statement is BreakStatement ||
        statement is ContinueStatement) {
      return true;
    }

    // Check for throw expression statement
    if (statement is ExpressionStatement &&
        statement.expression is ThrowExpression) {
      return true;
    }

    if (statement is Block && statement.statements.isNotEmpty) {
      return _endsWithAbruptCompletion(statement.statements.last);
    }

    return false;
  }
}

/// Warns when break or continue is unconditionally executed.
///
/// An unconditional break/continue at the start of a loop body means
/// the loop will never execute more than once, which is likely a bug.
///
/// Example of **bad** code:
/// ```dart
/// for (var item in items) {
///   break;  // Loop never iterates
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// for (var item in items) {
///   if (item == target) break;
///   process(item);
/// }
/// ```
class AvoidUnconditionalBreakRule extends SaropaLintRule {
  const AvoidUnconditionalBreakRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unconditional_break',
    problemMessage:
        '[avoid_unconditional_break] Unconditional break/continue makes loop execute at most once.',
    correctionMessage:
        'Add a condition before break/continue or remove the loop.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check for loops
    context.registry.addForStatement((ForStatement node) {
      _checkLoopBody(node.body, reporter);
    });

    context.registry
        .addForEachPartsWithDeclaration((ForEachPartsWithDeclaration node) {
      // The body is in the parent ForStatement
    });

    context.registry.addWhileStatement((WhileStatement node) {
      _checkLoopBody(node.body, reporter);
    });

    context.registry.addDoStatement((DoStatement node) {
      _checkLoopBody(node.body, reporter);
    });
  }

  void _checkLoopBody(Statement body, SaropaDiagnosticReporter reporter) {
    // Get the first statement
    Statement? firstStatement;

    if (body is Block) {
      if (body.statements.isNotEmpty) {
        firstStatement = body.statements.first;
      }
    } else {
      firstStatement = body;
    }

    if (firstStatement == null) return;

    // Check if first statement is unconditional break/continue
    if (firstStatement is BreakStatement ||
        firstStatement is ContinueStatement) {
      reporter.atNode(firstStatement, code);
    }
  }
}

/// Warns when a condition is always true or always false.
///
/// Example of **bad** code:
/// ```dart
/// if (true) { }  // Always true
/// if (false) { }  // Always false
/// final x = condition ? value : value;  // Same value for both branches
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (someCondition) { }
/// ```
class AvoidUnnecessaryConditionalsRule extends SaropaLintRule {
  const AvoidUnnecessaryConditionalsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_conditionals',
    problemMessage:
        '[avoid_unnecessary_conditionals] Condition is unnecessary (always true or always false).',
    correctionMessage: 'Remove the conditional or fix the condition.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if statements with boolean literal conditions
    context.registry.addIfStatement((IfStatement node) {
      if (node.expression is BooleanLiteral) {
        reporter.atNode(node.expression, code);
      }
    });

    // Check while statements
    context.registry.addWhileStatement((WhileStatement node) {
      if (node.condition is BooleanLiteral) {
        final BooleanLiteral literal = node.condition as BooleanLiteral;
        // while(true) is often intentional, only flag while(false)
        if (!literal.value) {
          reporter.atNode(node.condition, code);
        }
      }
    });

    // Check ternary with same then/else (already covered by NoEqualThenElseRule)
    // but also check for boolean literal conditions
    context.registry.addConditionalExpression((ConditionalExpression node) {
      if (node.condition is BooleanLiteral) {
        reporter.atNode(node.condition, code);
      }
    });
  }
}

/// Warns when continue is redundant (at end of loop body).
///
/// A continue statement at the end of a loop body has no effect.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// for (final item in items) {
///   process(item);
///   continue; // Redundant
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// for (final item in items) {
///   process(item);
/// }
/// ```
///
/// **Quick fix available:** Comments out the unnecessary continue.
class AvoidUnnecessaryContinueRule extends SaropaLintRule {
  const AvoidUnnecessaryContinueRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_continue',
    problemMessage:
        '[avoid_unnecessary_continue] Redundant continue statement at end of loop body.',
    correctionMessage: 'Remove the continue statement.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addContinueStatement((ContinueStatement node) {
      // Check if this is the last statement in a block
      final AstNode? parent = node.parent;
      if (parent is! Block) return;

      final List<Statement> statements = parent.statements;
      if (statements.isEmpty || statements.last != node) return;

      // Check if the block is directly inside a loop
      final AstNode? blockParent = parent.parent;
      if (blockParent is ForStatement ||
          blockParent is WhileStatement ||
          blockParent is DoStatement ||
          blockParent is ForElement) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_CommentOutUnnecessaryContinueFix()];
}

class _CommentOutUnnecessaryContinueFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addContinueStatement((ContinueStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Comment out unnecessary continue',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          '// ${node.toSource()}',
        );
      });
    });
  }
}

/// Warns on patterns like if (condition) return true; return false;
class AvoidUnnecessaryIfRule extends SaropaLintRule {
  const AvoidUnnecessaryIfRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_if',
    problemMessage: '[avoid_unnecessary_if] Unnecessary if statement.',
    correctionMessage: 'Simplify by returning the condition directly.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Check for: if (x) return true; followed by return false;
      // Or: if (x) return false; followed by return true;
      if (node.elseStatement != null) return;

      final Statement thenStmt = node.thenStatement;
      ReturnStatement? thenReturn;

      if (thenStmt is ReturnStatement) {
        thenReturn = thenStmt;
      } else if (thenStmt is Block && thenStmt.statements.length == 1) {
        final Statement single = thenStmt.statements.first;
        if (single is ReturnStatement) {
          thenReturn = single;
        }
      }

      if (thenReturn == null) return;
      final Expression? thenExpr = thenReturn.expression;
      if (thenExpr is! BooleanLiteral) return;

      // Check if next statement is return with opposite boolean
      final AstNode? parent = node.parent;
      if (parent is! Block) return;

      final int idx = parent.statements.indexOf(node);
      if (idx < 0 || idx >= parent.statements.length - 1) return;

      final Statement nextStmt = parent.statements[idx + 1];
      if (nextStmt is! ReturnStatement) return;

      final Expression? nextExpr = nextStmt.expression;
      if (nextExpr is! BooleanLiteral) return;

      // Check they return opposite booleans
      if (thenExpr.value != nextExpr.value) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when the same condition appears multiple times in an if-else chain.
///
/// Duplicate conditions indicate dead code or logic errors.
///
/// Example of **bad** code:
/// ```dart
/// if (x > 5) {
///   doA();
/// } else if (x > 5) {  // Same condition!
///   doB();
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// if (x > 5) {
///   doA();
/// } else if (x > 10) {
///   doB();
/// }
/// ```
class NoEqualConditionsRule extends SaropaLintRule {
  const NoEqualConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_conditions',
    problemMessage:
        '[no_equal_conditions] Duplicate condition in if-else chain.',
    correctionMessage: 'This condition was already checked above.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Collect all conditions in the if-else chain
      final List<String> conditions = <String>[];
      final List<Expression> conditionNodes = <Expression>[];

      IfStatement? current = node;
      while (current != null) {
        final String conditionSource = current.expression.toSource();
        conditions.add(conditionSource);
        conditionNodes.add(current.expression);

        final Statement? elseStmt = current.elseStatement;
        if (elseStmt is IfStatement) {
          current = elseStmt;
        } else {
          current = null;
        }
      }

      // Check for duplicates
      final Set<String> seen = <String>{};
      for (int i = 0; i < conditions.length; i++) {
        if (seen.contains(conditions[i])) {
          reporter.atNode(conditionNodes[i], code);
        }
        seen.add(conditions[i]);
      }
    });
  }
}

/// Warns when if and else branches have identical code.
///
/// Example of **bad** code:
/// ```dart
/// if (condition) {
///   doSomething();
/// } else {
///   doSomething();  // Same as if branch
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// doSomething();  // No need for the condition
/// ```
class NoEqualThenElseRule extends SaropaLintRule {
  const NoEqualThenElseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'no_equal_then_else',
    problemMessage:
        '[no_equal_then_else] If and else branches have identical code.',
    correctionMessage: 'Remove the condition and keep only the common code.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      // Compare the source code of both branches
      final String thenSource = node.thenStatement.toSource();
      final String elseSource = elseStatement.toSource();

      if (thenSource == elseSource) {
        reporter.atNode(node, code);
      }
    });

    // Also check conditional expressions (ternary)
    context.registry.addConditionalExpression((ConditionalExpression node) {
      final String thenSource = node.thenExpression.toSource();
      final String elseSource = node.elseExpression.toSource();

      if (thenSource == elseSource) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when an if-else could be simplified to a conditional expression.
///
/// Simple if-else statements that assign to the same variable or return
/// values can often be replaced with a ternary operator.
class PreferConditionalExpressionsRule extends SaropaLintRule {
  const PreferConditionalExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_conditional_expressions',
    problemMessage:
        '[prefer_conditional_expressions] Consider using a conditional expression.',
    correctionMessage: 'Use condition ? thenValue : elseValue.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Check if both branches are single return or assignment statements
      final Statement thenStatement = node.thenStatement;
      final Statement? elseStatement = node.elseStatement;

      if (elseStatement == null) return;

      // Check for simple return statements
      if (thenStatement is ReturnStatement &&
          elseStatement is ReturnStatement) {
        if (thenStatement.expression != null &&
            elseStatement.expression != null) {
          reporter.atNode(node, code);
        }
      }

      // Check for simple assignment to same variable
      if (thenStatement is ExpressionStatement &&
          elseStatement is ExpressionStatement) {
        final Expression thenExpr = thenStatement.expression;
        final Expression elseExpr = elseStatement.expression;

        if (thenExpr is AssignmentExpression &&
            elseExpr is AssignmentExpression) {
          if (thenExpr.leftHandSide.toSource() ==
              elseExpr.leftHandSide.toSource()) {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }
}

/// Warns when switch statements are too short or too long.
///
/// Very short switches might be better as if-else, very long ones
/// should be refactored.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (value) {
///   case 1:
///     return 'one';
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// if (value == 1) return 'one';
/// // OR for multiple cases:
/// switch (value) {
///   case 1: return 'one';
///   case 2: return 'two';
///   case 3: return 'three';
/// }
/// ```
class PreferCorrectSwitchLengthRule extends SaropaLintRule {
  const PreferCorrectSwitchLengthRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const int _minCases = 2;

  static const LintCode _code = LintCode(
    name: 'prefer_correct_switch_length',
    problemMessage:
        '[prefer_correct_switch_length] Switch statement has too few cases.',
    correctionMessage:
        'Consider using an if-else statement for $_minCases or fewer cases.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((SwitchStatement node) {
      final int caseCount = node.members.length;

      if (caseCount < _minCases) {
        reporter.atToken(node.switchKeyword, code);
      }
    });
  }
}

/// Warns when an if statement wraps the entire function body.
///
/// Early return patterns improve readability by reducing nesting.
///
/// Example of **bad** code:
/// ```dart
/// void process(String? value) {
///   if (value != null) {
///     // lots of code
///     doSomething(value);
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void process(String? value) {
///   if (value == null) return;
///   // lots of code
///   doSomething(value);
/// }
/// ```
class PreferEarlyReturnRule extends SaropaLintRule {
  const PreferEarlyReturnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_early_return',
    problemMessage:
        '[prefer_early_return] Consider using early return to reduce nesting.',
    correctionMessage:
        'Invert the condition and return early instead of wrapping the body.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunctionBody(node.body, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunctionBody(node.functionExpression.body, reporter);
    });
  }

  void _checkFunctionBody(
      FunctionBody body, SaropaDiagnosticReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    final NodeList<Statement> statements = block.statements;

    // Check if the only statement is an if without else
    if (statements.length != 1) return;

    final Statement stmt = statements.first;
    if (stmt is! IfStatement) return;

    // If there's an else clause, it's not a simple wrapper
    if (stmt.elseStatement != null) return;

    // Check if the if body has multiple statements or is substantial
    final Statement thenStmt = stmt.thenStatement;
    if (thenStmt is Block && thenStmt.statements.length >= 2) {
      reporter.atNode(stmt, code);
    }
  }
}

/// Warns when returning a conditional could be simplified.
///
/// Handles the pattern: `if (cond) return true; return false;`
/// For if-else patterns, see PreferReturningConditionRule.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// bool isValid(int x) {
///   if (x > 0) {
///     return true;
///   }
///   return false;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// bool isValid(int x) => x > 0;
/// ```
class PreferReturningConditionalsRule extends SaropaLintRule {
  const PreferReturningConditionalsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_returning_conditionals',
    problemMessage:
        '[prefer_returning_conditionals] Return the condition directly instead of true/false.',
    correctionMessage: 'Simplify by returning the condition expression.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Only handle pattern: if (cond) return true; return false;
      // Skip if-else patterns - handled by PreferReturningConditionRule
      if (node.elseStatement != null) return;

      final Statement thenStmt = node.thenStatement;

      // Check if then branch returns true
      if (!_returnsBoolLiteral(thenStmt, true)) return;

      // Check next statement after the if
      final AstNode? parent = node.parent;
      if (parent is! Block) return;

      final List<Statement> statements = parent.statements;
      final int index = statements.indexOf(node);
      if (index < 0 || index >= statements.length - 1) return;

      final Statement next = statements[index + 1];
      if (_returnsBoolLiteral(next, false)) {
        reporter.atToken(node.ifKeyword, code);
      }
    });

    // Also check ternary: return cond ? true : false;
    context.registry.addReturnStatement((ReturnStatement node) {
      final Expression? expr = node.expression;
      if (expr is! ConditionalExpression) return;

      final Expression thenExpr = expr.thenExpression;
      final Expression elseExpr = expr.elseExpression;

      if (thenExpr is BooleanLiteral &&
          thenExpr.value &&
          elseExpr is BooleanLiteral &&
          !elseExpr.value) {
        reporter.atNode(expr, code);
      }
    });
  }

  bool _returnsBoolLiteral(Statement stmt, bool value) {
    if (stmt is ReturnStatement) {
      final Expression? expr = stmt.expression;
      if (expr is BooleanLiteral) {
        return expr.value == value;
      }
    } else if (stmt is Block && stmt.statements.length == 1) {
      return _returnsBoolLiteral(stmt.statements.first, value);
    }
    return false;
  }
}

/// Warns when using `if (x) return true; else return false;` instead of `return x;`.
///
/// Example of **bad** code:
/// ```dart
/// bool isValid(int x) {
///   if (x > 0) {
///     return true;
///   } else {
///     return false;
///   }
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// bool isValid(int x) {
///   return x > 0;
/// }
/// ```
class PreferReturningConditionRule extends SaropaLintRule {
  const PreferReturningConditionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_returning_condition',
    problemMessage:
        '[prefer_returning_condition] Prefer returning the condition directly.',
    correctionMessage: 'Replace if-else with direct return of the condition.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addIfStatement((IfStatement node) {
      // Check for if-else pattern
      final Statement? elseStatement = node.elseStatement;
      if (elseStatement == null) return;

      // Get the return values from both branches
      final bool? thenReturnsBool = _returnsBoolLiteral(node.thenStatement);
      final bool? elseReturnsBool = _returnsBoolLiteral(elseStatement);

      if (thenReturnsBool == null || elseReturnsBool == null) return;

      // Check if one returns true and the other returns false
      if ((thenReturnsBool && !elseReturnsBool) ||
          (!thenReturnsBool && elseReturnsBool)) {
        reporter.atNode(node, code);
      }
    });
  }

  /// Returns true if the statement returns `true`, false if it returns `false`,
  /// null otherwise.
  bool? _returnsBoolLiteral(Statement statement) {
    ReturnStatement? returnStmt;

    if (statement is ReturnStatement) {
      returnStmt = statement;
    } else if (statement is Block && statement.statements.length == 1) {
      final Statement single = statement.statements.first;
      if (single is ReturnStatement) {
        returnStmt = single;
      }
    }

    if (returnStmt == null) return null;

    final Expression? expr = returnStmt.expression;
    if (expr is BooleanLiteral) {
      return expr.value;
    }

    return null;
  }
}

/// Warns when a switch case uses a nested if statement that could be a when guard.
///
/// Dart 3.0 introduced `when` guards for switch cases, which provide a cleaner
/// syntax for conditional case matching.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// switch (shape) {
///   case Circle(radius: var r):
///     if (r > 0) {
///       print('Positive radius');
///     }
///     break;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// switch (shape) {
///   case Circle(radius: var r) when r > 0:
///     print('Positive radius');
/// }
/// ```
class PreferWhenGuardOverIfRule extends SaropaLintRule {
  const PreferWhenGuardOverIfRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_when_guard_over_if',
    problemMessage:
        '[prefer_when_guard_over_if] Switch case with if statement could use a when guard.',
    correctionMessage:
        'Use "case pattern when condition:" instead of nested if.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchPatternCase((SwitchPatternCase node) {
      // Check if the case body is just an if statement (possibly in a block)
      final List<Statement> statements = node.statements;
      if (statements.isEmpty) return;

      Statement? firstStatement;
      if (statements.length == 1) {
        firstStatement = statements.first;
      } else if (statements.length == 2 && statements.last is BreakStatement) {
        // Allow if + break pattern
        firstStatement = statements.first;
      }

      if (firstStatement == null) return;

      // Check if it's an if statement or a block with just an if
      IfStatement? ifStmt;
      if (firstStatement is IfStatement) {
        ifStmt = firstStatement;
      } else if (firstStatement is Block &&
          firstStatement.statements.length == 1) {
        final Statement inner = firstStatement.statements.first;
        if (inner is IfStatement) {
          ifStmt = inner;
        }
      }

      if (ifStmt == null) return;

      // Check that the if statement doesn't already have a when guard on the case
      if (node.guardedPattern.whenClause != null) return;

      // Check that the if has no else branch (simpler to convert)
      if (ifStmt.elseStatement != null) return;

      // The if condition could be moved to a when guard
      reporter.atNode(ifStmt, code);
    });

    // Note: Traditional SwitchCase (`case 1:`) does NOT support when guards.
    // Only SwitchPatternCase (`case int n:`, `case Circle():`) supports when.
    // We intentionally do not flag traditional SwitchCase.
  }
}

/// Warns when boolean expressions can be simplified using De Morgan's laws
/// or by removing double negation.
///
/// De Morgan's laws state:
/// - `!(a && b)` is equivalent to `!a || !b`
/// - `!(a || b)` is equivalent to `!a && !b`
///
/// This rule also detects double negation (`!!x`).
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// if (!(a && b)) { }  // Use !a || !b
/// if (!(a || b)) { }  // Use !a && !b
/// if (!!condition) { }  // Use condition
/// ```
///
/// #### GOOD:
/// ```dart
/// if (!a || !b) { }
/// if (!a && !b) { }
/// if (condition) { }
/// ```
///
/// **Quick fix available:** Applies De Morgan's law or removes double negation.
class PreferSimplerBooleanExpressionsRule extends SaropaLintRule {
  const PreferSimplerBooleanExpressionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_simpler_boolean_expressions',
    problemMessage:
        '[prefer_simpler_boolean_expressions] Boolean expression can be simplified.',
    correctionMessage:
        'Apply De Morgan\'s law or remove double negation for clearer code.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixExpression((PrefixExpression node) {
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;

      // Check for double negation: !!x
      if (operand is PrefixExpression &&
          operand.operator.type == TokenType.BANG) {
        reporter.atNode(node, _codeDoubleNegation);
        return;
      }

      // Check for De Morgan's law opportunities: !(a && b) or !(a || b)
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression) {
          final TokenType op = inner.operator.type;
          if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR) {
            // Check if both operands are simple enough that De Morgan's
            // would actually improve readability
            if (_isSimpleExpression(inner.leftOperand) &&
                _isSimpleExpression(inner.rightOperand)) {
              reporter.atNode(node, _codeDeMorgan);
            }
          }
        }
      }
    });
  }

  /// Check if an expression is simple enough that negating it is readable.
  /// We want to avoid suggesting De Morgan's for complex nested expressions.
  bool _isSimpleExpression(Expression expr) {
    // Simple identifiers, property accesses, method calls are OK
    if (expr is SimpleIdentifier ||
        expr is PrefixedIdentifier ||
        expr is PropertyAccess ||
        expr is MethodInvocation ||
        expr is BooleanLiteral ||
        expr is IndexExpression) {
      return true;
    }
    // Already negated expressions are OK
    if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
      return true;
    }
    // Simple comparisons are OK
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (op == TokenType.EQ_EQ ||
          op == TokenType.BANG_EQ ||
          op == TokenType.LT ||
          op == TokenType.GT ||
          op == TokenType.LT_EQ ||
          op == TokenType.GT_EQ) {
        return true;
      }
    }
    // Parenthesized simple expressions are OK
    if (expr is ParenthesizedExpression) {
      return _isSimpleExpression(expr.expression);
    }
    return false;
  }

  static const LintCode _codeDoubleNegation = LintCode(
    name: 'prefer_simpler_boolean_expressions',
    problemMessage: 'Double negation (!!x) can be simplified to x.',
    correctionMessage: 'Remove the double negation.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const LintCode _codeDeMorgan = LintCode(
    name: 'prefer_simpler_boolean_expressions',
    problemMessage:
        'Negated compound expression can be simplified using De Morgan\'s law.',
    correctionMessage: 'Use !(a && b) → !a || !b, or !(a || b) → !a && !b.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  List<Fix> getFixes() => <Fix>[_SimplifyBooleanExpressionFix()];
}

class _SimplifyBooleanExpressionFix extends DartFix {
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
      if (node.operator.type != TokenType.BANG) return;

      final Expression operand = node.operand;

      // Handle double negation: !!x -> x
      if (operand is PrefixExpression &&
          operand.operator.type == TokenType.BANG) {
        final String innerExpr = operand.operand.toSource();

        final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
          message: 'Remove double negation',
          priority: 1,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleReplacement(
            SourceRange(node.offset, node.length),
            innerExpr,
          );
        });
        return;
      }

      // Handle De Morgan's law: !(a && b) -> !a || !b, !(a || b) -> !a && !b
      if (operand is ParenthesizedExpression) {
        final Expression inner = operand.expression;
        if (inner is BinaryExpression) {
          final TokenType op = inner.operator.type;
          String? oppositeOp;
          if (op == TokenType.AMPERSAND_AMPERSAND) {
            oppositeOp = '||';
          } else if (op == TokenType.BAR_BAR) {
            oppositeOp = '&&';
          }

          if (oppositeOp == null) return;

          final String left = _negateExpression(inner.leftOperand);
          final String right = _negateExpression(inner.rightOperand);

          final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
            message: 'Apply De Morgan\'s law',
            priority: 1,
          );

          changeBuilder.addDartFileEdit((builder) {
            builder.addSimpleReplacement(
              SourceRange(node.offset, node.length),
              '$left $oppositeOp $right',
            );
          });
        }
      }
    });
  }

  /// Negate an expression, handling already-negated expressions.
  String _negateExpression(Expression expr) {
    // If already negated, remove the negation
    if (expr is PrefixExpression && expr.operator.type == TokenType.BANG) {
      return expr.operand.toSource();
    }
    // If it's a boolean literal, negate it directly
    if (expr is BooleanLiteral) {
      return expr.value ? 'false' : 'true';
    }
    // Otherwise, add negation
    final String source = expr.toSource();
    // Add parentheses if the expression is complex
    if (expr is BinaryExpression || expr is ConditionalExpression) {
      return '!($source)';
    }
    return '!$source';
  }
}
