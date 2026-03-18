// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove duplicate cascade section.
///
/// Matches [AvoidDuplicateCascadesRule]. Deletes the duplicate
/// cascade section including its ".." or "..?" prefix.
class RemoveDuplicateCascadeSectionFix extends SaropaFixProducer {
  RemoveDuplicateCascadeSectionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeDuplicateCascadeSection',
    50,
    'Remove duplicate cascade section',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final Expression? section = node is Expression
        ? node
        : node.thisOrAncestorOfType<Expression>();
    if (section == null) return;

    final CascadeExpression? cascade = section
        .thisOrAncestorOfType<CascadeExpression>();
    if (cascade == null) return;

    final content = unitResult.content;
    int start = section.offset;
    int end = section.end;

    // Include preceding ".." or "..?"
    if (start >= 2) {
      final before = content.substring(start - 2, start);
      if (before == '..') {
        start -= 2;
      } else if (start >= 3 && content.substring(start - 3, start) == '..?') {
        start -= 3;
      }
    }

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
