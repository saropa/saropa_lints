// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use DateTime.tryParse instead
class UseDateTimeTryParseFix extends SaropaFixProducer {
  UseDateTimeTryParseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useDateTimeTryParseFix',
    50,
    'Use DateTime.tryParse instead',
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

    // Replace DateTime.parse with DateTime.tryParse
    final methodName = target.methodName;
    if (methodName.name != 'parse') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(methodName.offset, methodName.length),
        'tryParse',
      );
    });
  }
}
