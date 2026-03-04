// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';
import 'add_digit_separators_fix.dart';

/// Quick fix: Normalize digit separators to consistent grouping (e.g. 10_00_000 → 1_000_000).
///
/// Matches [AvoidInconsistentDigitSeparatorsRule].
class NormalizeDigitSeparatorsFix extends ReplaceNodeFix {
  NormalizeDigitSeparatorsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.normalizeDigitSeparators',
    50,
    'Normalize digit separator grouping',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! IntegerLiteral) return node.toSource();
    final lexeme = node.literal.lexeme;
    final normalized = AddDigitSeparatorsFix.addSeparatorsForNormalize(lexeme);
    if (normalized == lexeme) return node.toSource();
    return normalized;
  }
}
