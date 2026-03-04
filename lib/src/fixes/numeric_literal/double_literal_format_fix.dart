// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Format double literal (leading zero, trailing digit).
///
/// Matches [DoubleLiteralFormatRule].
class DoubleLiteralFormatFix extends ReplaceNodeFix {
  DoubleLiteralFormatFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.doubleLiteralFormat',
    50,
    'Format double literal',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! DoubleLiteral) return node.toSource();
    String lexeme = node.literal.lexeme;
    if (lexeme.startsWith('.')) lexeme = '0$lexeme';
    if (lexeme.endsWith('.')) lexeme = '${lexeme}0';
    return lexeme;
  }
}
