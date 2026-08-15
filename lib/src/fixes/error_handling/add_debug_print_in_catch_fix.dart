// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Insert a `debugPrint` call logging the caught error in a
/// catch block that has neither a logging call nor a captured exception
/// used for logging.
///
/// Matches [RequireErrorLoggingRule]. When the clause captured an exception
/// variable, the inserted call interpolates it (`debugPrint('Caught error:
/// $e')`); when it did not (e.g. `on TimeoutException { ... }`), the call
/// falls back to the statically-known exception type name, since there is
/// no captured value to interpolate.
class AddDebugPrintInCatchFix extends SaropaFixProducer {
  AddDebugPrintInCatchFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addDebugPrintInCatch',
    50,
    'Add debugPrint for caught error',
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

    // Prefer interpolating the captured exception variable when one
    // exists; otherwise fall back to the statically-known exception type
    // name, since there is nothing else to reference in the log message.
    final String? exceptionName = catchClause.exceptionParameter?.name.lexeme;
    final String message = exceptionName != null
        ? "debugPrint('Caught error: \$$exceptionName');"
        : "debugPrint('${catchClause.exceptionType?.toSource() ?? 'Error'} caught');";

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, '\n$indent  $message');
    });
  }
}
