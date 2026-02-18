// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add await to handle navigation result
class AddAwaitToNavigatorPushFix extends SaropaFixProducer {
  AddAwaitToNavigatorPushFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addAwaitToNavigatorPushFix',
    50,
    'Add await to handle navigation result',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, 'await ');
    });
  }
}
