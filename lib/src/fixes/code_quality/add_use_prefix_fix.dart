// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add "use" prefix to Flutter Hooks function name.
///
/// Matches [PreferUsePrefixRule]. Renames e.g. myHook to useMyHook.
class AddUsePrefixFix extends SaropaFixProducer {
  AddUsePrefixFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addUsePrefix',
    50,
    'Add "use" prefix to function name',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final FunctionDeclaration? decl = node is FunctionDeclaration
        ? node
        : node.thisOrAncestorOfType<FunctionDeclaration>();
    if (decl == null) return;

    final String name = decl.name.lexeme;
    if (name.isEmpty) return;
    if (name.length == 1) {
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(
          SourceRange(decl.name.offset, decl.name.length),
          'use${name.toUpperCase()}',
        );
      });
      return;
    }
    final String replacement =
        'use${name[0].toUpperCase()}${name.substring(1)}';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(decl.name.offset, decl.name.length),
        replacement,
      );
    });
  }
}
