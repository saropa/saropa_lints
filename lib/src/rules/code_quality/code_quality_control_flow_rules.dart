// ignore_for_file: depend_on_referenced_packages, deprecated_member_use, always_specify_types

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

import '../../fixes/code_quality/replace_constant_condition_fix.dart';
import '../../fixes/control_flow/remove_duplicate_switch_case_fix.dart';
import '../../fixes/control_flow/flatten_redundant_nested_condition_fix.dart';
import '../../fixes/control_flow/remove_duplicate_pattern_case_fix.dart';
import '../../fixes/control_flow/remove_wildcard_or_default_case_fix.dart';
import '../../saropa_lint_rule.dart';

class AvoidComplexLoopConditionsRule extends SaropaLintRule {
  AvoidComplexLoopConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_complex_loop_conditions',
    '[avoid_complex_loop_conditions] Loop condition contains too many operators or nested expressions, making it difficult to reason about when the loop terminates. Complex conditions increase the risk of off-by-one errors and infinite loops that are hard to diagnose. {v4}',
    correctionMessage:
        'Extract the condition into a named boolean variable or a separate method with a descriptive name that communicates the loop termination intent.',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _maxOperators = 2;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addWhileStatement((WhileStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.addDoStatement((DoStatement node) {
      _checkCondition(node.condition, reporter);
    });

    context.addForStatement((ForStatement node) {
      final ForLoopParts parts = node.forLoopParts;
      if (parts is ForParts) {
        final Expression? condition = parts.condition;
        if (condition != null) {
          _checkCondition(condition, reporter);
        }
      }
    });
  }

  void _checkCondition(
    Expression condition,
    SaropaDiagnosticReporter reporter,
  ) {
    final int operatorCount = _countLogicalOperators(condition);
    if (operatorCount > _maxOperators) {
      reporter.atNode(condition);
    }
  }

  int _countLogicalOperators(Expression expr) {
    int count = 0;
    if (expr is BinaryExpression) {
      final TokenType op = expr.operator.type;
      if (op == TokenType.AMPERSAND_AMPERSAND || op == TokenType.BAR_BAR) {
        count++;
      }
      count += _countLogicalOperators(expr.leftOperand);
      count += _countLogicalOperators(expr.rightOperand);
    } else if (expr is ParenthesizedExpression) {
      count += _countLogicalOperators(expr.expression);
    }
    return count;
  }
}

/// Warns when both sides of a binary expression are constants.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (1 > 2) { }  // Always false
/// final x = 'a' + 'b';  // Should be 'ab'
/// ```
class AvoidConstantConditionsRule extends SaropaLintRule {
  AvoidConstantConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_constant_conditions',
    '[avoid_constant_conditions] Condition evaluates to a compile-time constant, making one branch unreachable dead code. This usually indicates a logic error where the condition was intended to be dynamic, or leftover debugging code that was never cleaned up. {v4}',
    correctionMessage:
        'Remove the condition and keep only the reachable branch, or replace the constant with the intended dynamic expression that varies at runtime.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final TokenType op = node.operator.type;

      // Only check comparison operators
      if (op != TokenType.EQ_EQ &&
          op != TokenType.BANG_EQ &&
          op != TokenType.LT &&
          op != TokenType.LT_EQ &&
          op != TokenType.GT &&
          op != TokenType.GT_EQ) {
        return;
      }

      // Check if both sides are literals
      if (_isConstant(node.leftOperand) && _isConstant(node.rightOperand)) {
        reporter.atNode(node);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceConstantConditionFix(context: context),
  ];

  bool _isConstant(Expression expr) {
    return expr is IntegerLiteral ||
        expr is DoubleLiteral ||
        expr is BooleanLiteral ||
        expr is StringLiteral ||
        expr is NullLiteral;
  }
}

/// Warns when contradicting conditions are used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// if (x > 5 && x < 3) { }  // Always false
/// if (x == null && x.length > 0) { }  // Second part throws
/// ```
class AvoidWildcardCasesWithEnumsRule extends SaropaLintRule {
  AvoidWildcardCasesWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_wildcard_cases_with_enums',
    '[avoid_wildcard_cases_with_enums] Switch on an enum uses a default or wildcard case, suppressing exhaustiveness checking. When new enum values are added, the compiler will not flag this switch as incomplete, allowing the new case to silently fall into the default branch instead of being explicitly handled. {v5}',
    correctionMessage:
        'Remove the default/wildcard case and add explicit case clauses for every enum value so the compiler reports an error when new values are introduced.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      final Expression expression = node.expression;
      final DartType? type = expression.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!_looksLikeEnumType(typeName)) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveWildcardOrDefaultCaseFix(context: context),
  ];

  bool _looksLikeEnumType(String typeName) {
    if (typeName.isEmpty) return false;
    final String clean = typeName.replaceAll('?', '');
    if (clean == 'int' ||
        clean == 'String' ||
        clean == 'bool' ||
        clean == 'double' ||
        clean == 'Object' ||
        clean == 'dynamic') {
      return false;
    }
    return clean[0] == clean[0].toUpperCase() && !clean.contains('<');
  }
}

/// Warns when a function always returns the same value.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// int getValue(bool condition) {
///   if (condition) return 42;
///   return 42;  // Always returns 42
/// }
/// ```
class NoEqualNestedConditionsRule extends SaropaLintRule {
  NoEqualNestedConditionsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_equal_nested_conditions',
    '[no_equal_nested_conditions] Inner condition is identical to an enclosing outer condition. The nested check is always true at that point because the outer condition already guarantees it, making the inner branch redundant dead logic that adds nesting depth without any behavioral effect. {v4}',
    correctionMessage:
        'Remove the redundant nested condition and keep only the code inside it, since the outer condition already provides the same guarantee.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      final String outerCondition = node.expression.toSource();
      node.thenStatement.visitChildren(
        _NestedConditionChecker(outerCondition, reporter, _code),
      );
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        FlattenRedundantNestedConditionFix(context: context),
  ];
}

class _NestedConditionChecker extends RecursiveAstVisitor<void> {
  _NestedConditionChecker(this.outerCondition, this.reporter, this.code);

  final String outerCondition;
  final SaropaDiagnosticReporter reporter;
  final LintCode code;

  @override
  void visitIfStatement(IfStatement node) {
    final String innerCondition = node.expression.toSource();
    if (innerCondition == outerCondition) {
      reporter.atNode(node.expression, code);
    }
    super.visitIfStatement(node);
  }
}

/// Warns when switch cases have identical bodies.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// switch (x) {
///   case 1: return 'a';
///   case 2: return 'a';  // Same as case 1
/// }
/// ```
class NoEqualSwitchCaseRule extends SaropaLintRule {
  NoEqualSwitchCaseRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_equal_switch_case',
    '[no_equal_switch_case] Multiple switch cases contain identical body code. Duplicated case logic increases maintenance cost because changes must be applied to every copy, and missed updates cause inconsistent behavior across cases that are meant to be equivalent. {v4}',
    correctionMessage:
        'Combine the cases using comma-separated patterns (case a, b:) or extract the shared logic into a helper method referenced by each case.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      final List<String> caseBodies = <String>[];
      final List<SwitchMember> members = <SwitchMember>[];

      for (final SwitchMember member in node.members) {
        if (member is SwitchCase && member.statements.isNotEmpty) {
          final String body = member.statements
              .map((Statement s) => s.toSource())
              .join();
          caseBodies.add(body);
          members.add(member);
        }
      }

      final Set<String> seen = <String>{};
      for (int i = 0; i < caseBodies.length; i++) {
        if (seen.contains(caseBodies[i])) {
          reporter.atNode(members[i], code);
        }
        seen.add(caseBodies[i]);
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveDuplicateSwitchCaseFix(context: context),
  ];
}

/// Warns when isEmpty/isNotEmpty is used after where().
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// list.where((e) => e > 5).isEmpty;
/// ```
///
/// Example of **good** code:
/// ```dart
/// !list.any((e) => e > 5);
/// ```
class AvoidDuplicatePatternsRule extends SaropaLintRule {
  AvoidDuplicatePatternsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_duplicate_patterns',
    '[avoid_duplicate_patterns] Same pattern appears multiple times in a switch or if-case chain. Duplicate patterns mean the second occurrence is unreachable dead code because the first match always wins, indicating a copy-paste error or incomplete refactoring. {v4}',
    correctionMessage:
        'Remove the duplicate pattern clause, or if different handling is intended, adjust the pattern to be distinct so both branches are reachable.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchExpression((SwitchExpression node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchExpressionCase caseClause in node.cases) {
        final String patternSource = caseClause.guardedPattern.toSource();
        if (seenPatterns.contains(patternSource)) {
          reporter.atNode(caseClause.guardedPattern, code);
        } else {
          seenPatterns.add(patternSource);
        }
      }
    });

    context.addSwitchStatement((SwitchStatement node) {
      final Set<String> seenPatterns = <String>{};
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          final String patternSource = member.guardedPattern.toSource();
          if (seenPatterns.contains(patternSource)) {
            reporter.atNode(member.guardedPattern, code);
          } else {
            seenPatterns.add(patternSource);
          }
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveDuplicatePatternCaseFix(context: context),
  ];
}

/// Warns when an extension type contains another extension type.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Example of **bad** code:
/// ```dart
/// extension type Inner(int value) {}
/// extension type Outer(Inner inner) {}  // Nested extension type
/// ```
class AvoidWildcardCasesWithSealedClassesRule extends SaropaLintRule {
  AvoidWildcardCasesWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_wildcard_cases_with_sealed_classes',
    '[avoid_wildcard_cases_with_sealed_classes] Switch on a sealed class uses a default or wildcard case, suppressing exhaustiveness checking. When new subtypes are added to the sealed hierarchy, the compiler will not flag this switch as incomplete, allowing unhandled subtypes to silently fall through. {v4}',
    correctionMessage:
        'Remove the default/wildcard case and add explicit case clauses for every sealed subtype so the compiler reports an error when new subtypes are introduced.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member);
        }
      }
    });

    context.addSwitchExpression((SwitchExpression node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;

      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;

      for (final SwitchExpressionCase caseClause in node.cases) {
        final DartPattern pattern = caseClause.guardedPattern.pattern;
        if (pattern is WildcardPattern) {
          reporter.atNode(pattern);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveWildcardOrDefaultCaseFix(context: context),
  ];
}

/// Warns when switch on sealed types uses default or wildcard, defeating exhaustiveness.
///
/// Same logic as [AvoidWildcardCasesWithSealedClassesRule]; this rule is the
/// Essential-tier name so teams can enable exhaustiveness without the full
/// comprehensive set. Switch on a sealed type must list every subtype explicitly;
/// `default:` or `_` hides new subtypes and defeats compile-time checking.
///
/// **Bad:** `default: return 0;` or `_ => x` on a sealed selector.
/// **Good:** Explicit `case Circle():` / `case Square():` for every subtype.
///
/// Since: ROADMAP §4.1 Dart 3.x | Rule version: v1
class RequireExhaustiveSealedSwitchRule extends SaropaLintRule {
  RequireExhaustiveSealedSwitchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_exhaustive_sealed_switch',
    '[require_exhaustive_sealed_switch] Switch on a sealed class uses a default or wildcard case, suppressing exhaustiveness checking. Add explicit cases for every sealed subtype so the compiler reports an error when new subtypes are introduced. {v1}',
    correctionMessage:
        'Remove the default/wildcard case and add explicit case clauses for every sealed subtype.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;
      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;
      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) {
          reporter.atNode(member);
        }
      }
    });

    context.addSwitchExpression((SwitchExpression node) {
      final DartType? type = node.expression.staticType;
      if (type == null) return;
      final Element? element = type.element;
      if (element is! ClassElement) return;
      if (!element.isSealed) return;
      for (final SwitchExpressionCase caseClause in node.cases) {
        final DartPattern pattern = caseClause.guardedPattern.pattern;
        if (pattern is WildcardPattern) {
          reporter.atNode(pattern);
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveWildcardOrDefaultCaseFix(context: context),
  ];
}

/// Warns when switch expression cases have identical expressions.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// final result = switch (x) {
///   1 => 'one',
///   2 => 'one',  // Same as case 1
///   _ => 'other',
/// };
/// ```
class NoEqualSwitchExpressionCasesRule extends SaropaLintRule {
  NoEqualSwitchExpressionCasesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'no_equal_switch_expression_cases',
    '[no_equal_switch_expression_cases] Multiple switch expression cases produce identical result values. Duplicate results increase maintenance cost because changes must be applied to every copy, and they obscure whether the cases were truly intended to behave the same. {v4}',
    correctionMessage:
        'Combine the cases using comma-separated patterns (case a, b => result) or extract the shared value into a named constant.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchExpression((SwitchExpression node) {
      final Map<String, SwitchExpressionCase> seenExpressions =
          <String, SwitchExpressionCase>{};

      for (final SwitchExpressionCase caseClause in node.cases) {
        final String exprSource = caseClause.expression.toSource();

        if (seenExpressions.containsKey(exprSource)) {
          reporter.atNode(caseClause.expression, code);
        } else {
          seenExpressions[exprSource] = caseClause;
        }
      }
    });
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveDuplicateSwitchCaseFix(context: context),
  ];
}

/// Prefer switch expression over switch statement when all cases are simple
/// return/assignment (value mapping).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// **Exempt:** Does not flag switches where any case has multiple statements,
/// control flow (if/for/while/try/do) inside a case, or non-exhaustive switches
/// with code after the switch.
///
/// **Bad:** Switch statement with only return/assignment per case.
/// **Good:** Switch expression with same mapping.
class PreferSwitchExpressionRule extends SaropaLintRule {
  PreferSwitchExpressionRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_switch_expression',
    '[prefer_switch_expression] Switch statement with only return/assignment detected. Using statement syntax for simple value mapping adds unnecessary boilerplate (break statements, case keywords) and makes the code more verbose and harder to scan. {v5}',
    correctionMessage:
        'Replace with a switch expression that directly produces the mapped value. Switch expressions are more concise, cannot forget break statements, and guarantee exhaustiveness checking, reducing bugs and improving readability.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchStatement((SwitchStatement node) {
      // Check if all cases are simple assignments or returns
      bool allSimpleAssignments = true;
      String? targetVariable;
      bool allReturns = true;
      bool hasDefault = false;

      for (final SwitchMember member in node.members) {
        if (member is SwitchDefault) hasDefault = true;

        final List<Statement> statements = member is SwitchCase
            ? member.statements
            : (member is SwitchDefault ? member.statements : const []);

        // Empty statements = fall-through, skip without invalidating flags
        if (statements.isEmpty) continue;

        // Filter out break statements
        final List<Statement> meaningful = statements
            .where((s) => s is! BreakStatement)
            .toList();
        if (meaningful.isEmpty) continue;

        // If any case has multiple meaningful statements, it's complex
        if (meaningful.length > 1) {
          allSimpleAssignments = false;
          allReturns = false;
          continue;
        }

        final Statement? stmtOrNull = meaningful.firstOrNull;
        if (stmtOrNull == null) continue;
        final Statement stmt = stmtOrNull;

        // If any case contains control flow, not a simple mapping
        if (stmt is IfStatement ||
            stmt is ForStatement ||
            stmt is WhileStatement ||
            stmt is TryStatement ||
            stmt is DoStatement) {
          allSimpleAssignments = false;
          allReturns = false;
          continue;
        }

        if (stmt is ExpressionStatement) {
          final Expression expr = stmt.expression;
          if (expr is AssignmentExpression) {
            final Expression left = expr.leftHandSide;
            if (left is SimpleIdentifier) {
              if (targetVariable == null) {
                targetVariable = left.name;
              } else if (targetVariable != left.name) {
                allSimpleAssignments = false;
              }
            } else {
              allSimpleAssignments = false;
            }
          } else {
            allSimpleAssignments = false;
          }
          allReturns = false;
        } else if (stmt is ReturnStatement) {
          allSimpleAssignments = false;
        } else {
          allSimpleAssignments = false;
          allReturns = false;
        }
      }

      // Non-exhaustive switch with code after it is not expression-convertible
      if (!hasDefault && allReturns) {
        final AstNode? parent = node.parent;
        if (parent is Block) {
          final int idx = parent.statements.indexOf(node);
          if (idx >= 0 && idx < parent.statements.length - 1) {
            allReturns = false;
          }
        }
      }

      // Report if it's a good candidate for switch expression
      if ((allSimpleAssignments && targetVariable != null) || allReturns) {
        reporter.atToken(node.switchKeyword, code);
      }
    });
  }
}

/// Warns when if-else chains on enum values could use a switch.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// if (status == Status.active) {
///   // ...
/// } else if (status == Status.pending) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (status) {
///   case Status.active: // ...
///   case Status.pending: // ...
/// }
/// ```
class PreferSwitchWithEnumsRule extends SaropaLintRule {
  PreferSwitchWithEnumsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_switch_with_enums',
    '[prefer_switch_with_enums] Enum compared using if-else chain instead of switch statement. Without exhaustiveness checking, adding new enum values will not trigger compile errors in this code location, allowing silent bugs where new cases are unhandled. {v4}',
    correctionMessage:
        'Replace the if-else chain with a switch statement over the enum. The compiler will verify all enum values are handled and flag warnings when you add new enum cases, preventing missed implementations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition compares an enum
      final Expression condition = node.expression;
      if (condition is! BinaryExpression) return;
      if (condition.operator.type != TokenType.EQ_EQ) return;

      // Check if comparing against enum value
      final Expression left = condition.leftOperand;
      final Expression right = condition.rightOperand;

      bool isEnumComparison = false;
      SimpleIdentifier? enumVariable;

      if (_isEnumValue(right)) {
        if (left is SimpleIdentifier) {
          enumVariable = left;
          isEnumComparison = true;
        }
      } else if (_isEnumValue(left)) {
        if (right is SimpleIdentifier) {
          enumVariable = right;
          isEnumComparison = true;
        }
      }

      if (!isEnumComparison || enumVariable == null) return;

      // Count else-if branches comparing same variable
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is BinaryExpression &&
            elseCondition.operator.type == TokenType.EQ_EQ) {
          final Expression elseLeft = elseCondition.leftOperand;
          final Expression elseRight = elseCondition.rightOperand;

          if ((elseLeft is SimpleIdentifier &&
                  elseLeft.name == enumVariable.name) ||
              (elseRight is SimpleIdentifier &&
                  elseRight.name == enumVariable.name)) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 3+ branches
      if (branchCount >= 3) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }

  bool _isEnumValue(Expression expr) {
    if (expr is PrefixedIdentifier) {
      // Check if it looks like EnumType.value
      final String prefix = expr.prefix.name;
      if (prefix.isNotEmpty && prefix[0] == prefix[0].toUpperCase()) {
        return true;
      }
    } else if (expr is PropertyAccess) {
      final Expression? target = expr.target;
      if (target is SimpleIdentifier) {
        final String name = target.name;
        if (name.isNotEmpty && name[0] == name[0].toUpperCase()) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Warns when if-else chains on sealed class could use exhaustive switch.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// if (result is Success) {
///   // ...
/// } else if (result is Error) {
///   // ...
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// switch (result) {
///   case Success(): // ...
///   case Error(): // ...
/// }
/// ```
class PreferSwitchWithSealedClassesRule extends SaropaLintRule {
  PreferSwitchWithSealedClassesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_switch_with_sealed_classes',
    '[prefer_switch_with_sealed_classes] Sealed class handled with if-else or type checks instead of switch. Missing exhaustiveness verification allows unhandled subtypes to silently pass through, causing runtime errors or incorrect behavior when new subtypes are added. {v5}',
    correctionMessage:
        'Replace with a switch statement using pattern matching on the sealed class subtypes. The compiler enforces that all possible subtypes are handled, preventing bugs when the sealed class hierarchy grows.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((IfStatement node) {
      // Only check if statements with else-if chains
      if (node.elseStatement == null) return;

      // Check if condition is a type check
      final Expression condition = node.expression;
      if (condition is! IsExpression) return;

      final Expression target = condition.expression;
      if (target is! SimpleIdentifier) return;

      final String variableName = target.name;

      // Count type check branches
      int branchCount = 1;
      Statement? elseStmt = node.elseStatement;

      while (elseStmt is IfStatement) {
        final Expression elseCondition = elseStmt.expression;
        if (elseCondition is IsExpression) {
          final Expression elseTarget = elseCondition.expression;
          if (elseTarget is SimpleIdentifier &&
              elseTarget.name == variableName) {
            branchCount++;
          }
        }
        elseStmt = elseStmt.elseStatement;
      }

      // Report if there are 2+ type check branches
      if (branchCount >= 2) {
        reporter.atToken(node.ifKeyword, code);
      }
    });
  }
}

/// Warns when test assertions could use more specific matchers.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// expect(list.length, equals(0));
/// expect(string.contains('x'), isTrue);
/// ```
///
/// Example of **good** code:
/// ```dart
/// expect(list, isEmpty);
/// expect(string, contains('x'));
/// ```
class PreferSpecificCasesFirstRule extends SaropaLintRule {
  PreferSpecificCasesFirstRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'maintainability'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_specific_cases_first',
    '[prefer_specific_cases_first] General switch case appears before a more specific case. In Dart, the first matching case wins, so a broad pattern placed early shadows narrower patterns below it, making those specific cases unreachable dead code. {v4}',
    correctionMessage:
        'Reorder the cases so more specific patterns appear first and general catch-all patterns appear last, ensuring every case is reachable.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance
  static final RegExp _typePattern = RegExp(r'^(\w+)');

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSwitchExpression((SwitchExpression node) {
      _checkCaseOrder(
        node.cases.map((SwitchExpressionCase c) => c.guardedPattern).toList(),
        reporter,
      );
    });

    context.addSwitchStatement((SwitchStatement node) {
      final List<GuardedPattern> patterns = <GuardedPattern>[];
      for (final SwitchMember member in node.members) {
        if (member is SwitchPatternCase) {
          patterns.add(member.guardedPattern);
        }
      }
      _checkCaseOrder(patterns, reporter);
    });
  }

  void _checkCaseOrder(
    List<GuardedPattern> patterns,
    SaropaDiagnosticReporter reporter,
  ) {
    for (int i = 0; i < patterns.length - 1; i++) {
      final GuardedPattern current = patterns[i];
      final GuardedPattern next = patterns[i + 1];

      // Check if current is a general pattern and next is more specific
      final bool currentHasGuard = current.whenClause != null;
      final bool nextHasGuard = next.whenClause != null;

      // If current has no guard but next has a guard with same base pattern,
      // the order might be wrong
      if (!currentHasGuard && nextHasGuard) {
        final String currentPattern = current.pattern.toSource();
        final String nextPattern = next.pattern.toSource();

        // Simple heuristic: same type pattern but one has a guard
        if (_sameBaseType(currentPattern, nextPattern)) {
          reporter.atNode(next);
        }
      }
    }
  }

  bool _sameBaseType(String pattern1, String pattern2) {
    // Extract base type from patterns like "int _" or "int x"
    final RegExpMatch? match1 = _typePattern.firstMatch(pattern1);
    final RegExpMatch? match2 = _typePattern.firstMatch(pattern2);

    if (match1 != null && match2 != null) {
      return match1.group(1) == match2.group(1);
    }
    return false;
  }
}

/// Warns when a property is accessed after destructuring provides it.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Example of **bad** code:
/// ```dart
/// final (x, y) = point;
/// print(point.x);  // Already have x from destructuring
/// ```
///
/// Example of **good** code:
/// ```dart
/// final (x, y) = point;
/// print(x);  // Use destructured variable
/// ```
