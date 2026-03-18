// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Insert "rethrow;" in an empty or swallowing catch block.
///
/// Matches [AvoidSwallowingExceptionsRule].
class AddRethrowInCatchFix extends SaropaFixProducer {
  AddRethrowInCatchFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addRethrowInCatch',
    50,
    'Add rethrow in catch block',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final catchClause = node is CatchClause
        ? node
        : node.thisOrAncestorOfType<CatchClause>();
    if (catchClause == null) return;

    final Block body = catchClause.body;
    final indent = getLineIndent(catchClause);
    final insertOffset = body.leftBracket.end;
    final text = '\n$indent  rethrow;';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, text);
    });
  }
}
