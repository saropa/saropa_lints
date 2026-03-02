// ignore_for_file: depend_on_referenced_packages

import '../../native/saropa_fix.dart';

/// Quick fix: Insert TODO for substring usage.
class AvoidSubstringTodoFix extends SaropaFixProducer {
  AvoidSubstringTodoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.avoidSubstringTodoFix',
    50,
    'Add TODO: use safer alternative to substring',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final lineStart = unitResult.lineInfo.getOffsetOfLine(
      unitResult.lineInfo.getLocation(node.offset).lineNumber - 1,
    );
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        lineStart,
        '${getLineIndent(node)}// TODO: Prefer safer alternative (e.g. length check, split, replaceRange)\n',
      );
    });
  }
}
