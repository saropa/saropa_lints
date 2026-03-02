// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary inner block (replace with its statements).
class RemoveUnnecessaryBlockFix extends SaropaFixProducer {
  RemoveUnnecessaryBlockFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryBlockFix',
    50,
    'Remove unnecessary block',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final block = node is Block ? node : node.thisOrAncestorOfType<Block>();
    if (block == null || block.statements.isEmpty) return;

    final content = unitResult.content;
    final firstStmt = block.statements.first;
    final lastStmt = block.statements.last;
    int start = firstStmt.offset;
    int end = lastStmt.end;
    while (start > block.leftBracket.end &&
        _isWhitespace(content.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < content.length &&
        end < block.rightBracket.offset &&
        _isWhitespace(content.codeUnitAt(end))) {
      end++;
    }
    final replacement = content.substring(start, end);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(block.offset, block.length),
        replacement,
      );
    });
  }

  bool _isWhitespace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D;
}
