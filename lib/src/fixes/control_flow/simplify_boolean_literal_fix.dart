// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Simplify `x || true` → `true`, `x && false` → `false`, etc.
class SimplifyBooleanLiteralFix extends SaropaFixProducer {
  SimplifyBooleanLiteralFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.simplifyBooleanLiteral',
    50,
    'Simplify boolean expression',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final binary = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (binary == null) return;

    final left = binary.leftOperand;
    final right = binary.rightOperand;
    final isOr = binary.operator.type == TokenType.BAR_BAR;

    final BooleanLiteral boolLiteral;
    final Expression otherExpr;

    if (left is BooleanLiteral) {
      boolLiteral = left;
      otherExpr = right;
    } else if (right is BooleanLiteral) {
      boolLiteral = right;
      otherExpr = left;
    } else {
      return;
    }

    // x || true  → true
    // x || false → x
    // x && true  → x
    // x && false → false
    final String replacement;
    if (isOr) {
      replacement = boolLiteral.value ? 'true' : otherExpr.toSource();
    } else {
      replacement = boolLiteral.value ? otherExpr.toSource() : 'false';
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(binary.offset, binary.length),
        replacement,
      );
    });
  }
}
