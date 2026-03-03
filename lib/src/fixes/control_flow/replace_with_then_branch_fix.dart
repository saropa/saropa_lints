// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace if/else with identical branches (or ternary) with the then branch only.
///
/// Matches [NoEqualThenElseRule].
///
/// **For developers:** [ReplaceNodeFix]; supports [IfStatement] and [ConditionalExpression].
class ReplaceWithThenBranchFix extends ReplaceNodeFix {
  ReplaceWithThenBranchFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWithThenBranchFix',
    50,
    'Replace with then branch only',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is IfStatement) {
      return node.thenStatement.toSource();
    }
    if (node is ConditionalExpression) {
      return node.thenExpression.toSource();
    }
    return node.toSource();
  }
}
