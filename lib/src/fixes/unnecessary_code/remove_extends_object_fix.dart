// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove extends Object
class RemoveExtendsObjectFix extends SaropaFixProducer {
  RemoveExtendsObjectFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeExtendsObjectFix',
    50,
    'Remove extends Object',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ClassDeclaration
        ? node
        : node.thisOrAncestorOfType<ClassDeclaration>();
    if (target == null) return;

    // Remove "extends Object" from class declaration
    final extendsClause = target.extendsClause;
    if (extendsClause == null) return;

    await builder.addDartFileEdit(file, (builder) {
      // Delete from before "extends" to end of the type name
      // Include leading space
      builder.addDeletion(
        SourceRange(extendsClause.offset - 1, extendsClause.length + 1),
      );
    });
  }
}
