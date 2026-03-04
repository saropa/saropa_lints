// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove the late keyword from a declaration.
///
/// Matches [AvoidLateKeywordRule].
class RemoveLateKeywordFix extends SaropaFixProducer {
  RemoveLateKeywordFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeLateKeyword',
    50,
    'Remove late keyword',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    Token? lateToken;
    if (node is VariableDeclaration) {
      final parent = node.parent;
      if (parent is VariableDeclarationList) {
        lateToken = parent.lateKeyword;
      }
    } else if (node is FieldDeclaration) {
      lateToken = node.fields.lateKeyword;
    } else {
      final decl = node.thisOrAncestorOfType<VariableDeclaration>();
      final parentList = decl?.parent;
      if (parentList is VariableDeclarationList) {
        lateToken = parentList.lateKeyword;
      } else {
        final field = node.thisOrAncestorOfType<FieldDeclaration>();
        if (field != null) lateToken = field.fields.lateKeyword;
      }
    }
    if (lateToken == null) return;

    int offset = lateToken.offset;
    int length = lateToken.length;
    final content = unitResult.content;
    if (offset + length < content.length && content[offset + length] == ' ') {
      length++;
    }

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(offset, length));
    });
  }
}
