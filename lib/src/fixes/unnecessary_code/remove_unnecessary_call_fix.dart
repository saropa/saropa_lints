// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `fn.call(args)` with `fn(args)`.
class RemoveUnnecessaryCallFix extends SaropaFixProducer {
  RemoveUnnecessaryCallFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryCall',
    50,
    'Remove .call()',
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
    if (invocation.methodName.name != 'call') return;

    final target = invocation.target;
    if (target == null) return;

    final targetSource = target.toSource();
    final argsSource = invocation.argumentList.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        '$targetSource$argsSource',
      );
    });
  }
}
