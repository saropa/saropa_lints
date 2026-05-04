// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Convert a getter with a single-return block body to an
/// expression body, e.g. `int get value { return _x; }` → `int get value => _x;`.
///
/// Matches `PreferExpressionBodyGettersRule`, which fires only when the
/// getter's body is a [BlockFunctionBody] containing exactly one
/// [ReturnStatement] with a non-null expression. We replace the entire
/// `{ return EXPR; }` body with `=> EXPR;`. The trailing semicolon is
/// preserved by replacing only the body — the declaration semicolon comes
/// from the enclosing [MethodDeclaration].
class ConvertToExpressionBodyGetterFix extends SaropaFixProducer {
  ConvertToExpressionBodyGetterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertToExpressionBodyGetter',
    50,
    'Convert to expression body',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final MethodDeclaration? method = node is MethodDeclaration
        ? node
        : node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;
    if (!method.isGetter) return;

    final FunctionBody body = method.body;
    if (body is! BlockFunctionBody) return;
    final Block block = body.block;
    if (block.statements.length != 1) return;
    final stmt = block.statements.first;
    if (stmt is! ReturnStatement) return;
    final Expression? expr = stmt.expression;
    if (expr == null) return;

    final String exprSource = expr.toSource();

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(body.offset, body.length),
        '=> $exprSource;',
      );
    });
  }
}
