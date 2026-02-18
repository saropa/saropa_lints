// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace dynamic with Object?
class PreferObjectOverDynamicFix extends SaropaFixProducer {
  PreferObjectOverDynamicFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferObjectOverDynamicFix',
    4000,
    'Replace dynamic with Object?',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace "dynamic" keyword with "Object?"
    final source = node.toSource();
    if (source != 'dynamic') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'Object?',
      );
    });
  }
}
