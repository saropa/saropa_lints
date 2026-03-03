// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add ignore comment for empty block (documented suppression).
///
/// Matches the rule's correctionMessage: use `// ignore: no_empty_block` to
/// suppress and document why the block is empty.
class AddNoEmptyBlockIgnoreFix extends SaropaFixProducer {
  AddNoEmptyBlockIgnoreFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addNoEmptyBlockIgnoreFix',
    50,
    'Add // ignore: no_empty_block',
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
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, ' // ignore: no_empty_block');
    });
  }
}
