// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove redundant await (await expr → expr).
///
/// Matches [AvoidRedundantAwaitRule].
class RemoveRedundantAwaitFix extends ReplaceNodeFix {
  RemoveRedundantAwaitFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeRedundantAwait',
    50,
    'Remove redundant await',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! AwaitExpression) return node.toSource();
    return node.expression.toSource();
  }
}
