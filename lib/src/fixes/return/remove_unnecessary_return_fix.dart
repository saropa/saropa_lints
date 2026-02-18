// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary return
class RemoveUnnecessaryReturnFix extends SaropaFixProducer {
  RemoveUnnecessaryReturnFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryReturnFix',
    50,
    'Remove unnecessary return',
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
      builder.addDeletion(SourceRange(target.offset, target.length));
    });
  }
}
