// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Wrap ?? expression in parentheses for precedence clarity.
///
/// Matches [PreferParenthesesWithIfNullRule].
class WrapIfNullExpressionInParensFix extends ReplaceNodeFix {
  WrapIfNullExpressionInParensFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapIfNullExpressionInParens',
    50,
    'Wrap ?? expression in parentheses',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    return '(${node.toSource()})';
  }
}
