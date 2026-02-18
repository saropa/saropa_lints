// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Change to Future<void> Function()
class ChangeToFutureVoidFunctionFix extends SaropaFixProducer {
  ChangeToFutureVoidFunctionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.changeToFutureVoidFunctionFix',
    50,
    'Change to Future<void> Function()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is NamedType
        ? node
        : node.thisOrAncestorOfType<NamedType>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        'Future<void> Function()',
      );
    });
  }
}
