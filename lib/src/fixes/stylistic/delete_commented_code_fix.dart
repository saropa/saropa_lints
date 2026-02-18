// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Delete commented-out code
class DeleteCommentedCodeFix extends SaropaFixProducer {
  DeleteCommentedCodeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteCommentedCodeFix',
    50,
    'Delete commented-out code',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(
        SourceRange(node.offset, node.length),
      );
    });
  }
}
