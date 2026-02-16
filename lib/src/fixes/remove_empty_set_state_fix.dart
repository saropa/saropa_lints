// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../native/saropa_fix.dart';

/// Quick fix: remove an empty `setState(() {})` call.
///
/// Deletes the containing [ExpressionStatement] entirely since
/// the empty callback has no effect.
class RemoveEmptySetStateFix extends SaropaFixProducer {
  RemoveEmptySetStateFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeEmptySetState',
    50,
    'Remove empty setState call',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the containing ExpressionStatement to delete the whole line.
    final statement = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(statement.offset, statement.length));
    });
  }
}
