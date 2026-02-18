// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Move comment above directive
class MoveTrailingCommentFix extends SaropaFixProducer {
  MoveTrailingCommentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.moveTrailingCommentFix',
    4000,
    'Move comment above directive',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the directive (import/export) with trailing comment
    final directive = node is ImportDirective
        ? node as Directive
        : node is ExportDirective
            ? node as Directive
            : node.thisOrAncestorOfType<ImportDirective>() as Directive? ??
              node.thisOrAncestorOfType<ExportDirective>() as Directive?;
    if (directive == null) return;

    // Get the source and check for trailing comment
    final source = directive.toSource();
    final commentIdx = source.indexOf('//');
    if (commentIdx < 0) return;

    final comment = source.substring(commentIdx).trim();
    final directiveOnly = source.substring(0, commentIdx).trim();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(directive.offset, directive.length),
        '$comment\n$directiveOnly',
      );
    });
  }
}
