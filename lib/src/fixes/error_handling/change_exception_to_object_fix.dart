// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Change to "on Object" to catch Error types too
class ChangeExceptionToObjectFix extends SaropaFixProducer {
  ChangeExceptionToObjectFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.changeExceptionToObjectFix',
    50,
    'Change to "on Object" to catch Error types too',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is CatchClause
        ? node
        : node.thisOrAncestorOfType<CatchClause>();
    if (target == null) return;

    // Replace "on Exception" with "on Object" in the catch clause
    final exceptionType = target.exceptionType;
    if (exceptionType == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(exceptionType.offset, exceptionType.length),
        'Object',
      );
    });
  }
}
