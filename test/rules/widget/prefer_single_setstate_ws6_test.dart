import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/build_method_rules.dart';
import 'package:test/test.dart';

/// WS-6 fix for `prefer_single_setstate`: a setState before a loop must not
/// merge with a setState inside the loop body that runs after an in-loop await
/// (they land in different frames). The segment analysis is pure-AST, exercised
/// here on `parseString` ASTs. `true` = reported as mergeable.
void main() {
  bool mergeable(String methodBody) {
    final unit = parseString(
      content: 'class _S { Future<void> m(List<Object> items) async '
          '{ $methodBody } }',
      throwIfDiagnostics: false,
    ).unit;
    final finder = _MethodFinder('m');
    unit.accept(finder);
    return PreferSingleSetStateRule.findMergeableSetStateForTesting(
          finder.found!.body,
        ) !=
        null;
  }

  group('NO lint — setState separated by an in-loop await', () {
    test('setState before loop; loop body awaits then setState', () {
      expect(
        mergeable('''
setState(() {});
for (int i = 0; i < items.length; i++) {
  final id = await _save(items[i]);
  if (id != null) {}
  if (mounted) setState(() {});
}
'''),
        isFalse,
      );
    });

    test('while loop variant', () {
      expect(
        mergeable('''
setState(() {});
int i = 0;
while (i < items.length) {
  await _save(items[i]);
  setState(() {});
  i++;
}
'''),
        isFalse,
      );
    });

    test('loading-state top-level await (regression guard)', () {
      expect(
        mergeable('setState(() {}); await _save(items); '
            'if (mounted) setState(() {});'),
        isFalse,
      );
    });
  });

  group('LINT — genuinely mergeable', () {
    test('two consecutive setState calls inside one loop body, no await', () {
      expect(
        mergeable('for (int i = 0; i < items.length; i++) '
            '{ setState(() {}); setState(() {}); }'),
        isTrue,
      );
    });

    test('two consecutive straight-line setState calls', () {
      expect(mergeable('setState(() {}); setState(() {});'), isTrue);
    });
  });
}

class _MethodFinder extends RecursiveAstVisitor<void> {
  _MethodFinder(this.name);
  final String name;
  MethodDeclaration? found;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (found == null && node.name.lexeme == name) found = node;
    super.visitMethodDeclaration(node);
  }
}
