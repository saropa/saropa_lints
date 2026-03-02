// ignore_for_file: depend_on_referenced_packages

import '../../native/saropa_fix.dart';

/// Quick fix: Insert TODO comment for weak crypto usage.
class WeakCryptoTodoFix extends SaropaFixProducer {
  WeakCryptoTodoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.weakCryptoTodoFix',
    50,
    'Add TODO: replace with stronger algorithm',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final lineInfo = unitResult.lineInfo;
    final location = lineInfo.getLocation(node.offset);
    final lineStart = lineInfo.getOffsetOfLine(location.lineNumber - 1);
    final indent = getLineIndent(node);

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        lineStart,
        '${indent}// TODO: Use stronger algorithm (e.g. SHA-256)\n',
      );
    });
  }
}
