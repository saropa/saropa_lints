// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace !!x with x (remove double negation).
///
/// Matches [PreferSimplerBooleanExpressionsRule] for the double-negation case.
class RemoveDoubleNegationFix extends SaropaFixProducer {
  RemoveDoubleNegationFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDoubleNegation',
    50,
    'Remove double negation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final prefix = node is PrefixExpression
        ? node
        : node.thisOrAncestorOfType<PrefixExpression>();
    if (prefix == null) return;

    if (prefix.operator.type != TokenType.BANG) return;
    final operand = prefix.operand.unParenthesized;
    if (operand is! PrefixExpression) return;
    if (operand.operator.type != TokenType.BANG) return;

    final replacement = operand.operand.toSource();
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(prefix.offset, prefix.length),
        replacement,
      );
    });
  }
}
