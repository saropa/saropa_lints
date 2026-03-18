// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate mixin from with clause.
class DeleteDuplicateMixinFix extends SaropaFixProducer {
  DeleteDuplicateMixinFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.deleteDuplicateMixinFix',
    50,
    'Remove duplicate mixin',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final mixinType = node is NamedType
        ? node
        : node.thisOrAncestorOfType<NamedType>();
    if (mixinType == null) return;

    final withClause = mixinType.parent;
    if (withClause is! WithClause) return;

    final types = withClause.mixinTypes;
    final idx = types.indexOf(mixinType);
    if (idx < 0) return;

    final content = unitResult.content;
    int start = mixinType.offset;
    int end = mixinType.end;

    // Include preceding comma and whitespace so we don't leave ", "
    if (idx > 0) {
      final prev = types[idx - 1];
      start = prev.end;
      while (start < content.length &&
          (content[start] == ' ' || content[start] == ',')) {
        start++;
      }
      start = prev.end; // From end of previous to start of this (includes ", ")
    } else if (idx < types.length - 1) {
      // First of several: delete this and following ", "
      while (end < content.length &&
          (content[end] == ' ' || content[end] == ',')) {
        end++;
      }
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(start, end - start));
    });
  }
}
