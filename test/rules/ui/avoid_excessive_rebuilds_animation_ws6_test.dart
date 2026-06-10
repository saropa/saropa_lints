import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/ui/animation_rules.dart';
import 'package:test/test.dart';

/// WS-6 fix for `avoid_excessive_rebuilds_animation`: count only the HOISTABLE
/// widgets (those whose subtree reads no animation `.value`). A leaf
/// layout-property read (`fontSize: 14 * a.value`) makes its required wrapper
/// scaffold non-hoistable, while a large static subtree wrapped by
/// `Opacity(opacity: a.value, child: ...)` stays counted. Pure-AST.
void main() {
  int count(String builderBody) {
    final unit = parseString(
      content: 'Object f() { return (c, w) { $builderBody }; }',
      throwIfDiagnostics: false,
    ).unit;
    final finder = _BodyFinder();
    unit.accept(finder);
    return AvoidExcessiveRebuildsAnimationRule.hoistableWidgetCountForTesting(
      finder.found!,
    );
  }

  test('leaf layout-property read: wrappers are not counted (FP cleared)', () {
    // Container/Stack/Column all transitively contain the `.value` read, so
    // none is hoistable. Only the static Positioned/Icon/Text are counted (3).
    final n = count('''
return Container(
  child: Stack(children: [
    Positioned(child: Icon()),
    Column(children: [
      Text(style: TextStyle(fontSize: 14 * a.value)),
      Text('static'),
    ]),
  ]),
);
''');
    expect(n, lessThan(5));
  });

  test('static subtree under Opacity(opacity: a.value) stays counted (TP)', () {
    // Opacity reads `.value` so it is not counted, but the large static child
    // subtree reads no `.value` and remains hoistable.
    final n = count('''
return Opacity(
  opacity: a.value,
  child: Container(child: Column(children: [
    Row(children: [Icon(), Text('a')]),
    Card(child: Padding(child: Text('b'))),
  ])),
);
''');
    expect(n, greaterThan(5));
  });
}

class _BodyFinder extends RecursiveAstVisitor<void> {
  FunctionBody? found;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // The inner builder closure `(c, w) { ... }`.
    if (node.parameters != null && node.parameters!.parameters.length == 2) {
      found ??= node.body;
    }
    super.visitFunctionExpression(node);
  }
}
