// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Apply De Morgan's law — !(a && b) → !a || !b, !(a || b) → !a && !b.
///
/// Matches [PreferSimplerBooleanExpressionsRule] for the De Morgan case.
class SimplifyDeMorganFix extends SaropaFixProducer {
  SimplifyDeMorganFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.simplifyDeMorgan',
    50,
    'Apply De Morgan\'s law',
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
    if (operand is! ParenthesizedExpression) return;

    final inner = operand.expression;
    if (inner is! BinaryExpression) return;

    final op = inner.operator.type;
    final left = inner.leftOperand.toSource();
    final right = inner.rightOperand.toSource();

    final String replacement;
    if (op == TokenType.AMPERSAND_AMPERSAND) {
      replacement = '!$left || !$right';
    } else if (op == TokenType.BAR_BAR) {
      replacement = '!$left && !$right';
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(prefix.offset, prefix.length),
        replacement,
      );
    });
  }
}
