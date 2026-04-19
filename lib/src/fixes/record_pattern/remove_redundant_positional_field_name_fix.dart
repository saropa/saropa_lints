// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove redundant positional record field name (e.g. `$1`).
///
/// For `(int $1, String $2)` the rule reports at each name token; the fix
/// deletes the whitespace + name token so the annotation becomes
/// `(int, String)`.
class RemoveRedundantPositionalFieldNameFix extends SaropaFixProducer {
  RemoveRedundantPositionalFieldNameFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeRedundantPositionalFieldName',
    50,
    'Remove redundant positional field name',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // Locate the enclosing RecordTypeAnnotationPositionalField by walking up
    // the AST; the diagnostic is reported at the name Token but covering
    // node will be the nearest AST node (often a SimpleIdentifier or the
    // TypeAnnotation).
    final RecordTypeAnnotationPositionalField? field = node
        .thisOrAncestorOfType<RecordTypeAnnotationPositionalField>();
    if (field == null) return;

    final Token? nameToken = field.name;
    if (nameToken == null) return;

    // Delete from end of the type to end of the name token so the resulting
    // field is just the type (e.g. `int $1` → `int`).
    final TypeAnnotation type = field.type;
    final int start = type.end;
    final int end = nameToken.end;
    if (end <= start) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(start, end - start));
    });
  }
}
