// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: replace `'a' + 'b'` with adjacent strings `'a' 'b'`.
///
/// The rule reports at the outermost BinaryExpression where both operands
/// are pure string literals (SimpleStringLiteral or AdjacentStrings) joined
/// by `+`. This fix strips the `+` operators, leaving adjacent literals.
class PreferAdjacentStringsFix extends ReplaceNodeFix {
  PreferAdjacentStringsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferAdjacentStrings',
    50,
    'Replace + with adjacent string literals',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    // Collect all string literal parts from the binary expression chain
    final parts = <String>[];
    _collectParts(node, parts);
    // Join with a single space (adjacent string literal syntax)
    return parts.join(' ');
  }

  /// Recursively collects string literal source texts from a `+` chain.
  void _collectParts(AstNode node, List<String> parts) {
    if (node is BinaryExpression && node.operator.lexeme == '+') {
      _collectParts(node.leftOperand, parts);
      _collectParts(node.rightOperand, parts);
    } else {
      // Leaf: a SimpleStringLiteral or AdjacentStrings
      parts.add(node.toSource());
    }
  }
}
