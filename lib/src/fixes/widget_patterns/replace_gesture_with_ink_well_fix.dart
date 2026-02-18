// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with InkWell
class ReplaceGestureWithInkWellFix extends SaropaFixProducer {
  ReplaceGestureWithInkWellFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceGestureWithInkWellFix',
    50,
    'Replace with InkWell',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace GestureDetector constructor name with InkWell
    final source = node.toSource();
    if (!source.contains('GestureDetector')) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        source.replaceFirst('GestureDetector(', 'InkWell('),
      );
    });
  }
}
