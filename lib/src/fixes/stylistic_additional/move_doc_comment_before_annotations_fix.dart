// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';
import '../../rules/stylistic/stylistic_additional_rules.dart';

/// Quick fix: Move doc comment before all annotations.
///
/// Matches [AlwaysPutDocCommentsBeforeAnnotationsRule]. Relocates a `///`
/// doc comment that appears after (or between) annotations to immediately
/// before the first annotation on the same declaration.
class MoveDocCommentBeforeAnnotationsFix extends SaropaFixProducer {
  MoveDocCommentBeforeAnnotationsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.moveDocCommentBeforeAnnotations',
    50,
    'Move doc comment before annotations',
  );

  @override
  FixKind get fixKind => _fixKind;

  /// Bulk-applicable: all misplaced doc comments in the file get moved at once.
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossFiles;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the AnnotatedNode that owns the misplaced doc comment.
    final annotated = node.thisOrAncestorOfType<AnnotatedNode>();
    if (annotated == null) return;

    // Use the shared detection function — single source of truth for
    // what constitutes a misplaced doc comment.
    if (findMisplacedDocComment(annotated) == null) return;

    // Safe to force-unwrap: findMisplacedDocComment only returns non-null
    // when doc and metadata are both present.
    final Comment doc = annotated.documentationComment!;
    final Annotation firstAnnotation = annotated.metadata.first;

    // Compute the deletion range covering the full line(s) of the doc.
    final deletion = lineBoundaryRange(doc);

    // Extract the raw doc comment text for reinsertion at the new location.
    final String docText = unitResult.content.substring(doc.offset, doc.end);

    // Match the indentation of the first annotation so the reinserted doc
    // comment aligns with the surrounding code.
    final String indent = getLineIndent(firstAnnotation);

    await builder.addDartFileEdit(file, (b) {
      // Delete the full line(s) occupied by the misplaced doc comment.
      b.addDeletion(deletion);

      // Insert the doc comment before the first annotation, with a trailing
      // newline so the annotation stays on its own line.
      b.addSimpleInsertion(firstAnnotation.offset, '$docText\n$indent');
    });
  }
}
