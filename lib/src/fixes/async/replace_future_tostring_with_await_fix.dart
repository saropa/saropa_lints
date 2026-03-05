// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace future.toString() with (await future).toString().
///
/// Matches [AvoidFutureToStringRule].
class ReplaceFutureToStringWithAwaitFix extends SaropaFixProducer {
  ReplaceFutureToStringWithAwaitFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceFutureToStringWithAwait',
    50,
    'Use (await future).toString()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    if (node is MethodInvocation) {
      if (node.methodName.name != 'toString') return;
      final Expression? target = node.target;
      if (target == null) return;
      final String replacement = '(await ${target.toSource()}).toString()';
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
      return;
    }

    if (node is InterpolationExpression) {
      final Expression expr = node.expression;
      final String replacement = '\${await ${expr.toSource()}}';
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(node.offset, node.length),
          replacement,
        );
      });
    }
  }
}
