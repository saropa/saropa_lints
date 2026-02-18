// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Set autoPlay to false
class DisableAutoplayFix extends SaropaFixProducer {
  DisableAutoplayFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.disableAutoplayFix',
    50,
    'Set autoPlay to false',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is NamedExpression
        ? node
        : node.thisOrAncestorOfType<NamedExpression>();
    if (target == null) return;

    // Replace the value expression (true -> false)
    final expr = target.expression;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(expr.offset, expr.length),
        'false',
      );
    });
  }
}
