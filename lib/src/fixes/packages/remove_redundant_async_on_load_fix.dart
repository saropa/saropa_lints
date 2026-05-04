// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove the redundant `async` modifier from a Flame
/// `onLoad()` body that contains no `await`.
///
/// Matches `AvoidRedundantAsyncOnLoadRule`. The rule reports at the
/// MethodDeclaration; we navigate to its [BlockFunctionBody] and delete
/// the `async` keyword along with the trailing whitespace before `{`.
/// Removing `async` is safe because the rule already verified there are
/// no `await` expressions in the body.
class RemoveRedundantAsyncOnLoadFix extends SaropaFixProducer {
  RemoveRedundantAsyncOnLoadFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeRedundantAsyncOnLoad',
    50,
    'Remove redundant async keyword',
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

    final FunctionBody body = method.body;
    final Token? keyword = body.keyword;
    // Only handle plain `async` (not `async*`/`sync*`); the rule fires only
    // for `async` so this is defensive.
    if (keyword == null || keyword.lexeme != 'async') return;

    // Delete from the keyword start through any trailing whitespace so we
    // don't leave a dangling space before `{`. The next token is the body's
    // opening brace (BlockFunctionBody) or expression.
    final Token? next = keyword.next;
    final int end = next?.offset ?? keyword.end;
    final int start = keyword.offset;
    if (end <= start) return;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
