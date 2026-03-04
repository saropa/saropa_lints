// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove null assertion (expr! → expr).
///
/// Matches [AvoidNullAssertionRule].
class RemoveNullAssertionFix extends ReplaceNodeFix {
  RemoveNullAssertionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeNullAssertion',
    50,
    'Remove null assertion operator',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! PostfixExpression) return node.toSource();
    if (node.operator.type != TokenType.BANG) return node.toSource();
    return node.operand.toSource();
  }
}
