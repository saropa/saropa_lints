// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add a no-op comment inside an empty block.
///
/// Matches [NoEmptyBlockRule].
class NoEmptyBlockFix extends SaropaFixProducer {
  NoEmptyBlockFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.noEmptyBlock',
    50,
    'Add no-op comment to empty block',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final block = node is Block ? node : node.thisOrAncestorOfType<Block>();
    if (block == null || block.statements.isNotEmpty) return;

    final leftBracket = block.leftBracket;
    final insertOffset = leftBracket.end;
    const insertText = ' // no-op';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(insertOffset, 0),
        insertText,
      );
    });
  }
}
