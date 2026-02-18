// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace `expect` with `expectLater` for Future assertions.
class ReplaceExpectWithExpectLaterFix extends SaropaFixProducer {
  ReplaceExpectWithExpectLaterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceExpectWithExpectLater',
    50,
    'Replace with expectLater',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    if (invocation.methodName.name != 'expect') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(invocation.methodName.offset, invocation.methodName.length),
        'expectLater',
      );
    });
  }
}
