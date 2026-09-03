// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Move doc comment after all annotations.
///
/// Matches [PreferDocCommentAfterAnnotationsRule]. Relocates a `///` doc
/// comment that appears before annotations to immediately after the last
/// annotation on the same declaration.
class MoveDocCommentAfterAnnotationsFix extends SaropaFixProducer {
  MoveDocCommentAfterAnnotationsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.moveDocCommentAfterAnnotations',
    50,
    'Move doc comment after annotations',
  );

  @override
  FixKind get fixKind => _fixKind;

  /// Bulk-applicable: all doc comments in the file get moved at once.
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossFiles;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the AnnotatedNode whose doc comment is before annotations.
    final annotated = node.thisOrAncestorOfType<AnnotatedNode>();
    if (annotated == null) return;

    final Comment? doc = annotated.documentationComment;
    if (doc == null) return;
    if (annotated.metadata.isEmpty) return;

    final Annotation firstAnnotation = annotated.metadata.first;

    // This fix only applies when the doc comment is BEFORE annotations.
    if (doc.offset >= firstAnnotation.offset) return;

    final content = unitResult.content;
    final lineInfo = unitResult.lineInfo;

    // Delete the doc comment's full line(s) from its current position.
    final deletion = lineBoundaryRange(doc);

    // Extract the raw doc comment text for reinsertion.
    final String docText = content.substring(doc.offset, doc.end);

    // Insert after the last annotation, right before the declaration keyword.
    final lastAnnotation = annotated.metadata.last;

    // Match the indentation of the last annotation for the reinserted doc.
    final String indent = getLineIndent(lastAnnotation);

    // Insert point: start of the line after the last annotation.
    final lastAnnotLine =
        lineInfo.getLocation(lastAnnotation.end - 1).lineNumber - 1;
    final int insertOffset = (lastAnnotLine + 1) < lineInfo.lineCount
        ? lineInfo.getOffsetOfLine(lastAnnotLine + 1)
        : content.length;

    await builder.addDartFileEdit(file, (b) {
      // Delete the doc comment from above the annotations.
      b.addDeletion(deletion);

      // Insert the doc comment after the last annotation, with the
      // annotation's indentation and a trailing newline.
      b.addSimpleInsertion(
        insertOffset,
        '$indent$docText\n',
      );
    });
  }
}
