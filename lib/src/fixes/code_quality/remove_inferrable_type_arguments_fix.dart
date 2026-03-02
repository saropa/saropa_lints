// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove inferrable type arguments from collection literal.
class RemoveInferrableTypeArgumentsFix extends SaropaFixProducer {
  RemoveInferrableTypeArgumentsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeInferrableTypeArgumentsFix',
    50,
    'Remove explicit type arguments',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final typeArgs = node is TypeArgumentList
        ? node
        : node.thisOrAncestorOfType<TypeArgumentList>();
    if (typeArgs == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(typeArgs.offset, typeArgs.length));
    });
  }
}
