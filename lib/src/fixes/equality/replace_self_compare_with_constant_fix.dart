// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace self-comparison with constant (x == x → true, x != x → false, etc.).
///
/// Matches [AvoidSelfCompareRule].
class ReplaceSelfCompareWithConstantFix extends ReplaceNodeFix {
  ReplaceSelfCompareWithConstantFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceSelfCompareWithConstant',
    50,
    'Replace self-comparison with constant',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! BinaryExpression) return node.toSource();
    final op = node.operator.type;
    if (op == TokenType.EQ_EQ) return 'true';
    if (op == TokenType.BANG_EQ ||
        op == TokenType.LT ||
        op == TokenType.GT ||
        op == TokenType.LT_EQ ||
        op == TokenType.GT_EQ) {
      return 'false';
    }
    return node.toSource();
  }
}
