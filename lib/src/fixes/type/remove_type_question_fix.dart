// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: drop the trailing `?` from a nullable type annotation, making it
/// non-nullable.
///
/// Matches `AvoidNullableParametersWithDefaultValuesRule`, which reports at the
/// parameter's [TypeAnnotation] when the parameter is nullable yet has a
/// non-null default value (the `?` is redundant — the default guarantees a
/// value). Deleting the single `?` character at the end of the annotation is
/// the minimal correct edit and works uniformly for named, generic, function,
/// and record type forms (all end with the `?` token).
class RemoveTypeQuestionFix extends SaropaFixProducer {
  RemoveTypeQuestionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeTypeQuestion',
    50,
    'Remove the redundant ?',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is TypeAnnotation
        ? node
        : node.thisOrAncestorOfType<TypeAnnotation>();
    if (target == null) return;

    final content = unitResult.content;
    final int end = target.end;
    // Only act when the annotation genuinely ends in `?`; otherwise the rule
    // pointed at something this fix can't safely edit.
    if (end <= 0 || end > content.length) return;
    if (content[end - 1] != '?') return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(end - 1, 1));
    });
  }
}
