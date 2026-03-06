// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove leading underscore from exception class name.
///
/// Matches [PreferPublicExceptionClassesRule].
class RemoveLeadingUnderscoreFromExceptionClassFix extends SaropaFixProducer {
  RemoveLeadingUnderscoreFromExceptionClassFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeLeadingUnderscoreFromExceptionClass',
    50,
    'Remove leading underscore from class name',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final classDecl = node is ClassDeclaration
        ? node
        : node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    final name = classDecl.name.lexeme;
    if (!name.startsWith('_')) return;

    final newName = name.substring(1);
    final token = classDecl.name;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(token.offset, token.length), newName);
    });
  }
}
