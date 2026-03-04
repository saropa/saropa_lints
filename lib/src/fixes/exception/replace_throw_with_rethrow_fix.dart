// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace throw e with rethrow when e is the catch parameter.
///
/// Matches [AvoidThrowInCatchBlockRule].
class ReplaceThrowWithRethrowFix extends SaropaFixProducer {
  ReplaceThrowWithRethrowFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceThrowWithRethrow',
    50,
    'Replace with rethrow',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final throwExpr = node is ThrowExpression
        ? node
        : node.thisOrAncestorOfType<ThrowExpression>();
    if (throwExpr == null) return;

    final expr = throwExpr.expression;
    if (expr is! SimpleIdentifier) return;

    final catchClause = throwExpr.thisOrAncestorOfType<CatchClause>();
    if (catchClause == null) return;

    final param = catchClause.exceptionParameter;
    if (param == null) return;

    final paramName = param.name.lexeme;
    if (paramName != expr.name) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(throwExpr.offset, throwExpr.length),
        'rethrow',
      );
    });
  }
}
