// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `list[list.length - 1]` with `list.last`.
class UseLastFix extends SaropaFixProducer {
  UseLastFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useLast',
    50,
    'Replace with .last',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final indexExpr = node is IndexExpression
        ? node
        : node.thisOrAncestorOfType<IndexExpression>();
    if (indexExpr == null) return;

    final target = indexExpr.target;
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(indexExpr.offset, indexExpr.length),
        '${target.toSource()}.last',
      );
    });
  }
}
