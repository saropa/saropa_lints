// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `where(...).firstOrNull` with `firstWhereOrNull(...)`.
class ReplaceWithWhereOrNullFix extends SaropaFixProducer {
  ReplaceWithWhereOrNullFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWithWhereOrNull',
    50,
    'Replace with firstWhereOrNull',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Pattern: collection.where(pred).firstOrNull
    final access = node is PropertyAccess
        ? node
        : node.thisOrAncestorOfType<PropertyAccess>();
    if (access == null) return;

    final whereCall = access.target;
    if (whereCall is! MethodInvocation) return;
    if (whereCall.methodName.name != 'where') return;

    final collection = whereCall.target;
    if (collection == null) return;

    final predicate = whereCall.argumentList.arguments.firstOrNull;
    if (predicate == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(access.offset, access.length),
        '${collection.toSource()}.firstWhereOrNull(${predicate.toSource()})',
      );
    });
  }
}
