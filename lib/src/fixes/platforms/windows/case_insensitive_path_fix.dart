// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Add .toLowerCase() to both sides
class CaseInsensitivePathFix extends SaropaFixProducer {
  CaseInsensitivePathFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.caseInsensitivePathFix',
    4000,
    'Add .toLowerCase() to both sides',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (target == null) return;

    final left = target.leftOperand.toSource();
    final right = target.rightOperand.toSource();
    final op = target.operator.lexeme;
    final replacement =
        '$left.toLowerCase() $op $right.toLowerCase()';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
