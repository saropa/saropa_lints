import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/widget_layout_flex_scroll_rules.dart';
import 'package:test/test.dart';

/// WS-4 false-positive fixes for `avoid_listview_without_item_extent`. The
/// report decision is pure syntactic analysis (written type names + argument
/// shapes), exercised here on unresolved `parseString` ASTs via
/// `shouldReportForTesting`.
void main() {
  bool reports(String listViewExpr) {
    // Unresolved `parseString` parses `ListView.builder(...)` as a
    // MethodInvocation (the instance-creation rewrite happens during
    // resolution). The rule handles both shapes; the test exercises the
    // MethodInvocation path.
    final unit = parseString(
      content: 'Object f() => $listViewExpr;',
      throwIfDiagnostics: false,
    ).unit;
    final finder = _ListViewFinder();
    unit.accept(finder);
    return AvoidListViewWithoutItemExtentRule.shouldReportForTesting(
      finder.found!,
    );
  }

  group('NO report (false-positive guards)', () {
    test('shrinkWrap: true with default physics', () {
      expect(
        reports(
          'ListView.builder(shrinkWrap: true, itemCount: 3, '
          'itemBuilder: (c, i) => Text("x"))',
        ),
        isFalse,
      );
    });

    test('shrinkWrap: true + NeverScrollableScrollPhysics (still OK)', () {
      expect(
        reports(
          'ListView.builder(shrinkWrap: true, '
          'physics: const NeverScrollableScrollPhysics(), itemCount: 3, '
          'itemBuilder: (c, i) => Text("x"))',
        ),
        isFalse,
      );
    });

    test('itemBuilder returns ListTile (optional subtitle = variable height)',
        () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) => '
          'ListTile(title: Text("t"), subtitle: i.isEven ? Text("s") : null))',
        ),
        isFalse,
      );
    });

    test('itemBuilder returns ExpansionTile', () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) => '
          'ExpansionTile(title: Text("t")))',
        ),
        isFalse,
      );
    });

    test('itemBuilder (block body) returns CommonListTile wrapper', () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) '
          '{ return CommonListTile(title: Text("t")); })',
        ),
        isFalse,
      );
    });

    test('itemBuilder returns CommonPanelExpandable wrapper', () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) => '
          'CommonPanelExpandable(title: Text("t")))',
        ),
        isFalse,
      );
    });

    test('itemExtent present', () {
      expect(
        reports(
          'ListView.builder(itemExtent: 56, itemCount: 3, '
          'itemBuilder: (c, i) => Text("x"))',
        ),
        isFalse,
      );
    });

    test('ListView.separated is not this rule', () {
      expect(
        reports(
          'ListView.separated(itemCount: 3, '
          'itemBuilder: (c, i) => Text("x"), '
          'separatorBuilder: (c, i) => const Divider())',
        ),
        isFalse,
      );
    });
  });

  group('REPORT (true positives preserved)', () {
    test('plain scrolling, fixed-height row, no extent', () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) => '
          'SizedBox(height: 56, child: Text("x")))',
        ),
        isTrue,
      );
    });

    test('plain scrolling, simple Text row, no shrinkWrap, no extent', () {
      expect(
        reports(
          'ListView.builder(itemCount: 3, itemBuilder: (c, i) => Text("x"))',
        ),
        isTrue,
      );
    });
  });
}

class _ListViewFinder extends RecursiveAstVisitor<void> {
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.realTarget;
    if (found == null && target is SimpleIdentifier && target.name == 'ListView') {
      found = node;
    }
    super.visitMethodInvocation(node);
  }
}
