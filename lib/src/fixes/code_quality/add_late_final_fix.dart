// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Change `late` to `late final` for variables assigned only once.
///
/// Matches [PreferLateFinalRule].
class AddLateFinalFix extends SaropaFixProducer {
  AddLateFinalFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addLateFinal',
    50,
    'Change late to late final',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The rule reports atNode on the VariableDeclaration.
    // Navigate up to VariableDeclarationList to find the late keyword.
    Token? lateKeyword;
    if (node is VariableDeclaration) {
      final parent = node.parent;
      if (parent is VariableDeclarationList) {
        lateKeyword = parent.lateKeyword;
      }
    } else {
      final decl = node.thisOrAncestorOfType<VariableDeclaration>();
      final parentList = decl?.parent;
      if (parentList is VariableDeclarationList) {
        lateKeyword = parentList.lateKeyword;
      }
    }
    if (lateKeyword == null) return;

    // Replace `late` with `late final` — the existing space after `late`
    // is preserved, so the result is `late final <type>`.
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(lateKeyword!.offset, lateKeyword.length),
        'late final',
      );
    });
  }
}
