import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:test/test.dart';

/// WS-6 fix for `avoid_unawaited_future`: a `close()`/`cancel()` in a sync void
/// cleanup context (void method, hand-named teardown, or a sync callback
/// closure) cannot be awaited, so it is intentional cleanup, not a lost-error
/// risk. Pure-AST exemption check.
void main() {
  bool exempt(String enclosing) {
    final unit = parseString(
      content: 'class _C { $enclosing }',
      throwIfDiagnostics: false,
    ).unit;
    final finder = _CloseCancelFinder();
    unit.accept(finder);
    return AvoidUnawaitedFutureRule.isSyncVoidCleanupForTesting(
      finder.invocation!,
      finder.statement!,
    );
  }

  test('close() in a void dispose() is exempt', () {
    expect(exempt('void dispose() { _queue.close(); }'), isTrue);
  });

  test('close() in a hand-named disposeController() is exempt', () {
    expect(exempt('void disposeController() { controller?.close(); }'), isTrue);
  });

  test('cancel() inside a sync callback closure is exempt', () {
    expect(
      exempt('void build() { x.onCancel = () { sub.cancel(); }; }'),
      isTrue,
    );
  });

  test('close() in an async method is NOT exempt (await is possible)', () {
    expect(
      exempt('Future<void> teardown() async { _queue.close(); }'),
      isFalse,
    );
  });

  test('close() in a non-void, non-teardown method is NOT exempt', () {
    expect(exempt('int compute() { thing.close(); return 0; }'), isFalse);
  });
}

class _CloseCancelFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? invocation;
  ExpressionStatement? statement;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final Expression e = node.expression;
    if (invocation == null &&
        e is MethodInvocation &&
        (e.methodName.name == 'close' || e.methodName.name == 'cancel')) {
      invocation = e;
      statement = node;
    }
    super.visitExpressionStatement(node);
  }
}
