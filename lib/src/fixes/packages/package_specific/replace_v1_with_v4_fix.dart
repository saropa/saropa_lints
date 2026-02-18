// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Replace v1() with v4()
class ReplaceV1WithV4Fix extends SaropaFixProducer {
  ReplaceV1WithV4Fix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceV1WithV4Fix',
    50,
    'Replace v1() with v4()',
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

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.methodName.offset, target.methodName.length),
        'v4',
      );
    });
  }
}
