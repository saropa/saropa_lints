// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace `cond ? true : false` with `cond`, `cond ? false : true` with `!(cond)`.
///
/// Matches [PreferReturningConditionalsRule].
class PreferReturningConditionalsFix extends ReplaceNodeFix {
  PreferReturningConditionalsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferReturningConditionals',
    50,
    'Return condition directly',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! ConditionalExpression) return node.toSource();
    final thenExpr = node.thenExpression;
    final elseExpr = node.elseExpression;
    if (thenExpr is! BooleanLiteral || elseExpr is! BooleanLiteral) {
      return node.toSource();
    }
    final cond = node.condition.toSource();
    if (thenExpr.value && !elseExpr.value) return cond;
    if (!thenExpr.value && elseExpr.value) return '!($cond)';
    return node.toSource();
  }
}
