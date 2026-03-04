// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary digit separators from integer literal.
///
/// Matches [AvoidUnnecessaryDigitSeparatorsRule].
class RemoveUnnecessaryDigitSeparatorsFix extends ReplaceNodeFix {
  RemoveUnnecessaryDigitSeparatorsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryDigitSeparators',
    50,
    'Remove unnecessary digit separators',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! IntegerLiteral) return node.toSource();
    final lexeme = node.literal.lexeme;
    if (!lexeme.contains('_')) return node.toSource();
    return lexeme.replaceAll('_', '');
  }
}
