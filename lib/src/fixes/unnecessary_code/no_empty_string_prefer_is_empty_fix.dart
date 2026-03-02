// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace == '' / != '' with .isEmpty / .isNotEmpty.
class NoEmptyStringPreferIsEmptyFix extends SaropaFixProducer {
  NoEmptyStringPreferIsEmptyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.noEmptyStringPreferIsEmptyFix',
    50,
    'Use .isEmpty or .isNotEmpty',
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

    final op = binary.operator.type;
    if (op != TokenType.EQ_EQ && op != TokenType.BANG_EQ) return;

    final left = binary.leftOperand;
    final right = binary.rightOperand;
    final bool leftIsEmpty = left is SimpleStringLiteral && left.value.isEmpty;
    final bool rightIsEmpty =
        right is SimpleStringLiteral && right.value.isEmpty;
    if (!leftIsEmpty && !rightIsEmpty) return;

    final Expression target = leftIsEmpty ? right : left;
    final String targetSource = target.toSource();
    final String replacement = op == TokenType.EQ_EQ
        ? '$targetSource.isEmpty'
        : '$targetSource.isNotEmpty';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(binary.offset, binary.length),
        replacement,
      );
    });
  }
}
