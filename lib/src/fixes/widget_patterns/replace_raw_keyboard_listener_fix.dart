// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with KeyboardListener
class ReplaceRawKeyboardListenerFix extends SaropaFixProducer {
  ReplaceRawKeyboardListenerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceRawKeyboardListenerFix',
    50,
    'Replace with KeyboardListener',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace RawKeyboardListener with KeyboardListener in the constructor name
    final source = node.toSource();
    if (!source.contains('RawKeyboardListener')) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        source.replaceFirst('RawKeyboardListener', 'KeyboardListener'),
      );
    });
  }
}
