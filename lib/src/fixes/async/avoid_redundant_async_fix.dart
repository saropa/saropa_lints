// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove async keyword
class AvoidRedundantAsyncFix extends SaropaFixProducer {
  AvoidRedundantAsyncFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.avoidRedundantAsyncFix',
    4000,
    'Remove async keyword',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is FunctionBody
        ? node
        : node.thisOrAncestorOfType<FunctionBody>();
    if (target == null) return;

    // Delete only the 'async' keyword, not the entire body
    final keyword = target.keyword;
    if (keyword == null || keyword.lexeme != 'async') return;

    await builder.addDartFileEdit(file, (builder) {
      // Delete 'async' plus trailing space
      builder.addDeletion(
        SourceRange(keyword.offset, keyword.length + 1),
      );
    });
  }
}
