// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove useMaterial3: false
class RemoveMaterial2FallbackFix extends SaropaFixProducer {
  RemoveMaterial2FallbackFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeMaterial2FallbackFix',
    50,
    'Remove useMaterial3: false',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is NamedExpression
        ? node
        : node.thisOrAncestorOfType<NamedExpression>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(target.offset, target.length));
    });
  }
}
