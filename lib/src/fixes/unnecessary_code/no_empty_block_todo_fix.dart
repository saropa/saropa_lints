// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Insert TODO comment in empty block.
class NoEmptyBlockTodoFix extends SaropaFixProducer {
  NoEmptyBlockTodoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.noEmptyBlockTodoFix',
    50,
    'Add TODO: implement',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final block = node is Block ? node : node.thisOrAncestorOfType<Block>();
    if (block == null || block.statements.isNotEmpty) return;

    final insertOffset = block.leftBracket.end;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, ' // TODO: implement');
    });
  }
}
