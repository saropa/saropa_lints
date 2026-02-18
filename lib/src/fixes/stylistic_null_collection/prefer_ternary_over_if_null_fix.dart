// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with ternary expression
class PreferTernaryOverIfNullFix extends SaropaFixProducer {
  PreferTernaryOverIfNullFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferTernaryOverIfNullFix',
    4000,
    'Replace with ternary expression',
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

    if (target.operator.lexeme != '??') return;

    final left = target.leftOperand.toSource();
    final right = target.rightOperand.toSource();
    final replacement = '$left != null ? $left : $right';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
