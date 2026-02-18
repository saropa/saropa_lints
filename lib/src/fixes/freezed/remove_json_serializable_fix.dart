// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove @JsonSerializable()
class RemoveJsonSerializableFix extends SaropaFixProducer {
  RemoveJsonSerializableFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeJsonSerializableFix',
    4000,
    'Remove @JsonSerializable()',
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

    // Find and delete only the @JsonSerializable annotation
    for (final annotation in target.metadata) {
      if (annotation.name.name == 'JsonSerializable') {
        await builder.addDartFileEdit(file, (builder) {
          // Delete annotation plus trailing newline/whitespace
          final end = annotation.end;
          final contentAfter = unitResult.content.substring(end);
          final newlineIdx = contentAfter.indexOf('\n');
          final deleteLen = newlineIdx >= 0
              ? annotation.length + newlineIdx + 1
              : annotation.length;
          builder.addDeletion(SourceRange(annotation.offset, deleteLen));
        });
        return;
      }
    }
  }
}
