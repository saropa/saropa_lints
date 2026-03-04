// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Split "return x..y..z;" into "x..y..z; return x;".
///
/// Matches [AvoidReturningCascadesRule].
class SplitReturnCascadeFix extends ReplaceNodeFix {
  SplitReturnCascadeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.splitReturnCascade',
    50,
    'Split cascade from return',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  AstNode? findTargetNode(AstNode node) {
    return node is ReturnStatement
        ? node
        : node.thisOrAncestorOfType<ReturnStatement>();
  }

  @override
  String computeReplacement(AstNode node) {
    if (node is! ReturnStatement) return node.toSource();

    final Expression? expression = node.expression;
    if (expression is! CascadeExpression) return node.toSource();

    final cascadeTarget = expression.target;
    final indent = getLineIndent(node);

    return '${expression.toSource()};\n${indent}return ${cascadeTarget.toSource()};';
  }
}
