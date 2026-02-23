// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add a blank line after variable declarations.
///
/// Used by `prefer_blank_line_after_declarations` where the flagged node
/// is the [VariableDeclarationStatement] itself and the blank line should
/// appear *after* it (before the next statement).
class AddBlankLineAfterDeclarationsFix extends SaropaFixProducer {
  AddBlankLineAfterDeclarationsFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addBlankLineAfterDeclarations',
    50,
    'Add blank line after declarations',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is VariableDeclarationStatement
        ? node
        : node.thisOrAncestorOfType<VariableDeclarationStatement>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.end, '\n');
    });
  }
}
