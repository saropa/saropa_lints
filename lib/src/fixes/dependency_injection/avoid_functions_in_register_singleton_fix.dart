// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Change to registerLazySingleton
class AvoidFunctionsInRegisterSingletonFix extends SaropaFixProducer {
  AvoidFunctionsInRegisterSingletonFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.avoidFunctionsInRegisterSingletonFix',
    4000,
    'Change to registerLazySingleton',
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

    final methodName = target.methodName;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(methodName.offset, methodName.length),
        'registerLazySingleton',
      );
    });
  }
}
