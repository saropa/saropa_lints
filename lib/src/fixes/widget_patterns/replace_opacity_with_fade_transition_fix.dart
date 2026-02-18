// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with FadeTransition
class ReplaceOpacityWithFadeTransitionFix extends SaropaFixProducer {
  ReplaceOpacityWithFadeTransitionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceOpacityWithFadeTransitionFix',
    50,
    'Replace with FadeTransition',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Replace Opacity constructor name with FadeTransition
    final source = node.toSource();
    if (!source.contains('Opacity')) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        source.replaceFirst('Opacity(', 'FadeTransition('),
      );
    });
  }
}
