// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../../saropa_lint_rule.dart';

/// Flags a sub-expression that appears more than once within a single
/// `&&`/`||` chain, e.g. `status == Status.open || status == Status.open`.
///
/// Since: v14.4.0 | Updated: v14.4.0 | Rule version: v1
///
/// This is distinct from `no_equal_conditions`, which catches duplicate
/// *whole conditions* repeated across `if`/`else if` branches. This rule
/// instead catches the narrower and more common typo of repeating the same
/// comparison twice inside a single boolean expression tree -- almost
/// always a copy-paste mistake where a different variable or value was
/// intended for the second occurrence, or dead code that can be deleted.
///
/// **BAD:**
/// ```dart
/// bool isEditable(Status status) {
///   return status == Status.open || status == Status.open; // duplicate
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// bool isEditable(Status status) {
///   return status == Status.open || status == Status.draft;
/// }
/// ```
class DuplicateValueRule extends SaropaLintRule {
  DuplicateValueRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'reliability'};

  @override
  RuleCost get cost => RuleCost.medium;

  // Cheap pre-filter: a file with neither logical operator cannot possibly
  // contain a duplicated operand inside a &&/|| chain, so skip parsing it.
  @override
  Set<String> get requiredPatterns => const {'&&', '||'};

  static const LintCode _code = LintCode(
    'duplicate_value',
    '[duplicate_value] The same sub-expression appears more than once '
        'within this &&/|| chain. A repeated comparison is always '
        'redundant: it either has no effect on the result and can be '
        'deleted, or it is a copy-paste mistake where a different '
        'variable, field, or value was meant for the second occurrence. '
        '{v1}',
    correctionMessage:
        'Remove the duplicate clause, or correct it if a different '
        'comparison was intended.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      final TokenType operatorType = node.operator.type;
      if (operatorType != TokenType.AMPERSAND_AMPERSAND &&
          operatorType != TokenType.BAR_BAR) {
        return;
      }

      // Only evaluate the root of a same-operator chain. Nested
      // binary expressions using the identical operator are visited
      // again by the outer AST walk, so skip them here to avoid
      // reporting the same duplicate pair once per nesting level.
      final AstNode? parent = node.parent;
      if (parent is BinaryExpression && parent.operator.type == operatorType) {
        return;
      }

      final List<Expression> operands = <Expression>[];
      _collectOperands(node, operatorType, operands);

      // Compare full-expression source text (never a substring/`.contains()`
      // check per project doctrine) so formatting differences (`a==1` vs
      // `a == 1`) don't evade detection while unrelated expressions that
      // merely share a fragment are never falsely matched.
      final Set<String> seen = <String>{};
      for (final Expression operand in operands) {
        final String source = operand.toSource();
        if (seen.contains(source)) {
          reporter.atNode(operand);
        } else {
          seen.add(source);
        }
      }
    });
  }

  /// Flattens a chain of the same `&&`/`||` operator into its leaf operands.
  ///
  /// Only descends into a nested [BinaryExpression] when it uses the exact
  /// same operator as the chain being flattened. A mixed-operator
  /// expression such as `a && b || a && b` is therefore treated as two
  /// opaque `&&` operands of the outer `||`, rather than incorrectly
  /// merged into a single flat list -- this avoids misreporting operator
  /// precedence groups as duplicated scalar values.
  void _collectOperands(
    Expression expr,
    TokenType operatorType,
    List<Expression> out,
  ) {
    if (expr is BinaryExpression && expr.operator.type == operatorType) {
      _collectOperands(expr.leftOperand, operatorType, out);
      _collectOperands(expr.rightOperand, operatorType, out);
    } else {
      out.add(expr);
    }
  }
}
