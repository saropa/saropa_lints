// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: insert `if (!mounted) return;` before a `setState` call
/// inside a Timer or Future.delayed callback.
class AddMountedCheckFix extends SaropaFixProducer {
  AddMountedCheckFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addMountedCheck',
    50,
    'Add mounted check before setState',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the ExpressionStatement containing the setState call
    final statement = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    final indent = getLineIndent(statement);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        SourceRange(statement.offset, 0).offset,
        '${indent}if (!mounted) return;\n',
      );
    });
  }
}
