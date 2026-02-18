// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `.where((e) => e is T)` with `.whereType<T>()`.
class PreferWhereTypeFix extends SaropaFixProducer {
  PreferWhereTypeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferWhereType',
    50,
    'Replace with whereType<T>()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    if (invocation.methodName.name != 'where') return;

    final args = invocation.argumentList.arguments;
    if (args.length != 1) return;

    final arg = args.first;
    if (arg is! FunctionExpression) return;

    final body = arg.body;
    if (body is! ExpressionFunctionBody) return;

    final expr = body.expression;
    if (expr is! IsExpression) return;

    final typeName = expr.type.toSource();
    final target = invocation.target;
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        '${target.toSource()}.whereType<$typeName>()',
      );
    });
  }
}
