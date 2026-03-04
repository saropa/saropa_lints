// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace constant condition with its result (true/false).
///
/// Matches [AvoidConstantConditionsRule].
class ReplaceConstantConditionFix extends ReplaceNodeFix {
  ReplaceConstantConditionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceConstantCondition',
    50,
    'Replace constant condition with result',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! BinaryExpression) return node.toSource();
    final left = node.leftOperand;
    final right = node.rightOperand;
    final op = node.operator.type;
    final result = _evaluate(left, right, op);
    if (result == null) return node.toSource();
    return result ? 'true' : 'false';
  }

  bool? _evaluate(Expression left, Expression right, TokenType op) {
    if (op == TokenType.EQ_EQ) return _equal(left, right);
    if (op == TokenType.BANG_EQ) {
      final eq = _equal(left, right);
      return eq == null ? null : !eq;
    }
    final cmp = _compare(left, right);
    if (cmp == null) return null;
    switch (op) {
      case TokenType.LT:
        return cmp < 0;
      case TokenType.LT_EQ:
        return cmp <= 0;
      case TokenType.GT:
        return cmp > 0;
      case TokenType.GT_EQ:
        return cmp >= 0;
      default:
        return null;
    }
  }

  bool? _equal(Expression left, Expression right) {
    if (left is NullLiteral && right is NullLiteral) return true;
    if (left is BooleanLiteral && right is BooleanLiteral) {
      return left.value == right.value;
    }
    final cmp = _compare(left, right);
    return cmp == null ? null : cmp == 0;
  }

  int? _compare(Expression left, Expression right) {
    if (left is IntegerLiteral && right is IntegerLiteral) {
      final a = int.tryParse(left.literal.lexeme.replaceAll('_', ''));
      final b = int.tryParse(right.literal.lexeme.replaceAll('_', ''));
      if (a != null && b != null) return a.compareTo(b);
    }
    if (left is DoubleLiteral && right is DoubleLiteral) {
      final a = double.tryParse(left.literal.lexeme.replaceAll('_', ''));
      final b = double.tryParse(right.literal.lexeme.replaceAll('_', ''));
      if (a != null && b != null) return a.compareTo(b);
    }
    if (left is StringLiteral && right is StringLiteral) {
      return left.toSource().compareTo(right.toSource());
    }
    if (left is NullLiteral && right is NullLiteral) return 0;
    final leftSrc = left.toSource();
    final rightSrc = right.toSource();
    return leftSrc == rightSrc ? 0 : null;
  }
}
