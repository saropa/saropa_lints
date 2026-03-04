// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace redundant null check with constant (x == null → false, x != null → true when x is non-nullable).
///
/// Matches [AvoidRedundantNullCheckRule].
class ReplaceRedundantNullCheckFix extends ReplaceNodeFix {
  ReplaceRedundantNullCheckFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceRedundantNullCheck',
    50,
    'Replace redundant null check with constant',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! BinaryExpression) return node.toSource();
    final op = node.operator.lexeme;
    if (op == '==') {
      return 'false'; // x == null is always false when x is non-nullable
    }
    if (op == '!=') {
      return 'true'; // x != null is always true when x is non-nullable
    }
    return node.toSource();
  }
}
