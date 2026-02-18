// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with SelectableText
class ReplaceTextWithSelectableFix extends SaropaFixProducer {
  ReplaceTextWithSelectableFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceTextWithSelectableFix',
    50,
    'Replace with SelectableText',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace "Text(" with "SelectableText(" in the constructor name
    final source = node.toSource();
    if (!source.startsWith('Text(') && !source.startsWith('const Text(')) {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        source.replaceFirst('Text(', 'SelectableText('),
      );
    });
  }
}
