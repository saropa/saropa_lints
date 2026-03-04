// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Swap operands so variable is on the left (e.g. 200 == status → status == 200).
///
/// Matches [BinaryExpressionOperandOrderRule].
class SwapBinaryOperandOrderFix extends ReplaceNodeFix {
  SwapBinaryOperandOrderFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.swapBinaryOperandOrder',
    50,
    'Swap operands (variable on left)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! BinaryExpression) return node.toSource();
    final left = node.leftOperand.toSource();
    final right = node.rightOperand.toSource();
    final op = node.operator.lexeme;
    return '$right $op $left';
  }
}
