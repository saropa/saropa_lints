// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Wrap the unawaited Future expression in `unawaited(...)`.
///
/// Applies to `avoid_unawaited_future` violations. Replaces the whole
/// expression statement with `unawaited(expression);` so errors are
/// explicitly acknowledged as fire-and-forget. Caller must have
/// `dart:async` imported for `unawaited`.
class WrapInUnawaitedFix extends SaropaFixProducer {
  WrapInUnawaitedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapInUnawaited',
    80,
    'Wrap in unawaited()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final statement = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    // Do not wrap if already unawaited(...)
    final expr = statement.expression;
    if (expr is MethodInvocation && expr.methodName.name == 'unawaited') {
      return;
    }

    final indent = getLineIndent(statement);
    final newSource = '${indent}unawaited(${expr.toSource()});';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(statement.offset, statement.length),
        newSource,
      );
    });
  }
}
