// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add a blank line before the flagged node.
///
/// Works for any rule that flags a node/token where a preceding blank line
/// is missing. Navigates up to the enclosing [ClassMember] or [SwitchMember]
/// so the blank line is placed before metadata/annotations.
class AddBlankLineBeforeFix extends SaropaFixProducer {
  AddBlankLineBeforeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addBlankLineBefore',
    50,
    'Add blank line',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Navigate to the enclosing declaration for proper placement
    // (before annotations/doc comments, not just the name token).
    final target =
        node.thisOrAncestorOfType<ClassMember>() ??
        node.thisOrAncestorOfType<SwitchMember>() ??
        node;

    final lineInfo = unitResult.lineInfo;
    final line = lineInfo.getLocation(target.offset).lineNumber - 1;
    final lineStart = lineInfo.getOffsetOfLine(line);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(lineStart, '\n');
    });
  }
}
