// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `!(a == b)` with `a != b`.
class UseNotEqualsFix extends SaropaFixProducer {
  UseNotEqualsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useNotEquals',
    50,
    'Replace with != operator',
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

    final operand = prefix.operand.unParenthesized;
    if (operand is! BinaryExpression) return;

    final left = operand.leftOperand.toSource();
    final right = operand.rightOperand.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(prefix.offset, prefix.length),
        '$left != $right',
      );
    });
  }
}
