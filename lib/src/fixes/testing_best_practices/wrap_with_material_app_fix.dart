// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Wrap with MaterialApp
class WrapWithMaterialAppFix extends SaropaFixProducer {
  WrapWithMaterialAppFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapWithMaterialAppFix',
    50,
    'Wrap with MaterialApp',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    // Find the widget argument in pumpWidget(widget)
    final args = target.argumentList.arguments;
    if (args.isEmpty) return;

    final widget = args.first;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(widget.offset, widget.length),
        'MaterialApp(home: ${widget.toSource()})',
      );
    });
  }
}
