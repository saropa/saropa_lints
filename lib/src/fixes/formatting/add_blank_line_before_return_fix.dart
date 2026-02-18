// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add blank line before return
class AddBlankLineBeforeReturnFix extends SaropaFixProducer {
  AddBlankLineBeforeReturnFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addBlankLineBeforeReturnFix',
    50,
    'Add blank line before return',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ReturnStatement
        ? node
        : node.thisOrAncestorOfType<ReturnStatement>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, '\n');
    });
  }
}
