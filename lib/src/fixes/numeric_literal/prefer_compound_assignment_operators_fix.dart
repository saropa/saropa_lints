// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Use compound assignment (e.g. x = x & y → x &= y).
///
/// Matches [PreferCompoundAssignmentOperatorsRule].
class PreferCompoundAssignmentOperatorsFix extends ReplaceNodeFix {
  PreferCompoundAssignmentOperatorsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferCompoundAssignmentOperators',
    50,
    'Use compound assignment operator',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! AssignmentExpression) return node.toSource();
    final rhs = node.rightHandSide;
    if (rhs is! BinaryExpression) return node.toSource();
    final op = rhs.operator.lexeme;
    final compound = _compoundOp(op);
    if (compound == null) return node.toSource();
    final left = node.leftHandSide.toSource();
    final right = rhs.rightOperand.toSource();
    return '$left $compound $right';
  }

  static String? _compoundOp(String op) {
    switch (op) {
      case '&':
        return '&=';
      case '|':
        return '|=';
      case '^':
        return '^=';
      case '<<':
        return '<<=';
      case '>>':
        return '>>=';
      default:
        return null;
    }
  }
}
