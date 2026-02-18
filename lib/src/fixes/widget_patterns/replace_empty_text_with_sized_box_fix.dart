// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with SizedBox.shrink()
class ReplaceEmptyTextWithSizedBoxFix extends SaropaFixProducer {
  ReplaceEmptyTextWithSizedBoxFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceEmptyTextWithSizedBoxFix',
    50,
    'Replace with SizedBox.shrink()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace Text('') or Text("") with const SizedBox.shrink()
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'const SizedBox.shrink()',
      );
    });
  }
}
