import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/config/migration_rule_source_utils.dart';
import 'package:saropa_lints/src/rules/config/migration_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show LintImpact;
import 'package:test/test.dart';

/// Unit tests for ListView extent-hint rules (itemExtentBuilder / separated) and
/// [PreferOverflowBarOverButtonBarRule] AST shape expectations.
///
/// Mirrors the named-argument scan used in production rules (no full plugin run).
void main() {
  group('AvoidListViewWithoutItemExtentRule (argument scan)', () {
    test('flags builder without any extent hint; does not flag separated', () {
      // ListView.separated is unconditionally excluded because its
      // constructor does not declare itemExtent / prototypeItem /
      // itemExtentBuilder — see archived bug
      // avoid_listview_without_item_extent_false_positive_listview_separated_unfixable.md.
      final code = '''
class ListView {
  ListView.builder({dynamic itemCount, dynamic itemBuilder});
  ListView.separated({
    dynamic itemCount,
    dynamic itemBuilder,
    dynamic separatorBuilder,
  });
  ListView({List<dynamic>? children});
}
void f() {
  ListView.builder(itemCount: 1, itemBuilder: (c, i) => null);
  ListView.separated(
    itemCount: 1,
    itemBuilder: (c, i) => null,
    separatorBuilder: (c, i) => null,
  );
}
''';
      expect(_countListViewsMissingExtentHints(code), 1);
    });

    test('does not flag when itemExtentBuilder is present', () {
      final code = '''
class ListView {
  ListView.builder({
    dynamic itemCount,
    dynamic itemExtentBuilder,
    dynamic itemBuilder,
  });
}
void f() {
  ListView.builder(
    itemCount: 1,
    itemExtentBuilder: (i, d) => 10.0,
    itemBuilder: (c, i) => null,
  );
}
''';
      expect(_countListViewsMissingExtentHints(code), 0);
    });

    test('does not flag when itemExtent or prototypeItem is present', () {
      final code = '''
class ListView {
  ListView.builder({
    dynamic itemCount,
    dynamic itemExtent,
    dynamic prototypeItem,
    dynamic itemBuilder,
  });
  ListView.separated({
    dynamic itemCount,
    dynamic prototypeItem,
    dynamic itemBuilder,
    dynamic separatorBuilder,
  });
}
void f() {
  ListView.builder(
    itemCount: 1,
    itemExtent: 8,
    itemBuilder: (c, i) => null,
  );
  ListView.separated(
    itemCount: 1,
    prototypeItem: null,
    itemBuilder: (c, i) => null,
    separatorBuilder: (c, i) => null,
  );
}
''';
      expect(_countListViewsMissingExtentHints(code), 0);
    });

    test('false positive guard: default ListView constructor is ignored', () {
      final code = '''
class ListView {
  ListView({List<dynamic>? children});
}
void f() {
  ListView(children: []);
}
''';
      expect(_countListViewsMissingExtentHints(code), 0);
    });

    test(
      'false positive guard: shrinkWrap + const NeverScrollableScrollPhysics() skips',
      () {
        // Inline non-scrolling list pattern — outer parent scrolls; shrinkWrap
        // forces eager layout so itemExtent's lazy-extent benefit is impossible
        // and forcing a constant extent here would clip variable-height rows.
        // See bugs/...shrinkwrap_never_scrollable_inline_list.md.
        final code = '''
class NeverScrollableScrollPhysics {
  const NeverScrollableScrollPhysics();
}
class ListView {
  ListView.builder({
    dynamic itemCount,
    dynamic itemBuilder,
    dynamic shrinkWrap,
    dynamic physics,
  });
}
void f() {
  ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 1,
    itemBuilder: (c, i) => null,
  );
}
''';
        expect(_countListViewsMissingExtentHints(code), 0);
      },
    );

    test('false positive guard: ListView.separated is excluded entirely', () {
      // ListView.separated is excluded regardless of arguments — its
      // constructor does not accept the extent-hint parameters at all, so
      // even the inline-non-scrolling shape should produce no diagnostic.
      final code = '''
class NeverScrollableScrollPhysics {
  const NeverScrollableScrollPhysics();
}
class ListView {
  ListView.separated({
    dynamic itemCount,
    dynamic itemBuilder,
    dynamic separatorBuilder,
    dynamic shrinkWrap,
    dynamic physics,
  });
}
void f() {
  ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 1,
    itemBuilder: (c, i) => null,
    separatorBuilder: (c, i) => null,
  );
}
''';
      expect(_countListViewsMissingExtentHints(code), 0);
    });

    test('still flags when only shrinkWrap is set (no physics)', () {
      // shrinkWrap alone is NOT the inline-non-scrolling pattern — the inner
      // list still scrolls and the extent-hint guidance applies.
      final code = '''
class ListView {
  ListView.builder({dynamic itemCount, dynamic itemBuilder, dynamic shrinkWrap});
}
void f() {
  ListView.builder(
    shrinkWrap: true,
    itemCount: 1,
    itemBuilder: (c, i) => null,
  );
}
''';
      expect(_countListViewsMissingExtentHints(code), 1);
    });

    test(
      'still flags when only NeverScrollableScrollPhysics is set (no shrinkWrap)',
      () {
        // Other-axis or unbounded nesting — without shrinkWrap, virtualization
        // can still happen and the extent-hint guidance applies.
        final code = '''
class NeverScrollableScrollPhysics {
  const NeverScrollableScrollPhysics();
}
class ListView {
  ListView.builder({dynamic itemCount, dynamic itemBuilder, dynamic physics});
}
void f() {
  ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 1,
    itemBuilder: (c, i) => null,
  );
}
''';
        expect(_countListViewsMissingExtentHints(code), 1);
      },
    );
  });

  group('PreferOverflowBarOverButtonBarRule (metadata + AST)', () {
    test('uses low impact, Flutter gating, and ButtonBar pattern index', () {
      final rule = PreferOverflowBarOverButtonBarRule();
      expect(rule.impact, LintImpact.info);
      expect(rule.requiresFlutterImport, isTrue);
      expect(
        rule.requiredPatterns,
        containsAll(<String>['ButtonBar', 'buttonBarTheme']),
      );
    });

    test('does not count project-local ButtonBar (same-unit declaration)', () {
      expect(
        _countButtonBarCreations('''
class ButtonBar {
  ButtonBar();
}
// ButtonBar( in comment only
void f() {
  ButtonBar();
}
'''),
        0,
      );
    });

    test('counts ButtonBar when unresolved (ICE or MethodInvocation)', () {
      expect(
        _countButtonBarCreations('''
void f() {
  ButtonBar();
}
'''),
        1,
      );
    });

    test('OverflowBar does not count as ButtonBar', () {
      expect(
        _countButtonBarCreations('''
class OverflowBar {
  OverflowBar({List<dynamic>? children});
}
void f() { OverflowBar(children: []); }
'''),
        0,
      );
    });
  });
}

int _countListViewsMissingExtentHints(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final visitor = _ListViewExtentVisitor();
  result.unit.accept(visitor);
  return visitor.missingHintCount;
}

int _countButtonBarCreations(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final visitor = _ButtonBarVisitor();
  result.unit.accept(visitor);
  return visitor.count;
}

/// Same extent-hint names as [AvoidListViewWithoutItemExtentRule].
///
/// Handles both [InstanceCreationExpression] and unresolved
/// [MethodInvocation] shapes (`ListView.builder` without a resolved type).
class _ListViewExtentVisitor extends RecursiveAstVisitor<void> {
  int missingHintCount = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _maybeCountListView(node.constructorName, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Only `.builder` is targeted; `.separated` is excluded — its constructor
    // does not accept itemExtent / prototypeItem / itemExtentBuilder, so a
    // diagnostic there would be unfixable.
    if (node.methodName.name == 'builder') {
      final target = node.target;
      if (target is SimpleIdentifier && target.name == 'ListView') {
        _countIfMissingHints(node.argumentList);
      }
    }
    super.visitMethodInvocation(node);
  }

  void _maybeCountListView(ConstructorName constructorName, ArgumentList args) {
    final typeName = constructorName.type.name.lexeme;
    final name = constructorName.name?.name;
    if (typeName == 'ListView' && name == 'builder') {
      _countIfMissingHints(args);
    }
  }

  void _countIfMissingHints(ArgumentList argumentList) {
    var hasItemExtent = false;
    var hasPrototypeItem = false;
    var hasItemExtentBuilder = false;
    var shrinkWrapTrue = false;
    var neverScrollablePhysics = false;
    for (final arg in argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      if (name == 'itemExtent') hasItemExtent = true;
      if (name == 'prototypeItem') hasPrototypeItem = true;
      if (name == 'itemExtentBuilder') hasItemExtentBuilder = true;
      if (name == 'shrinkWrap') {
        final v = arg.expression;
        if (v is BooleanLiteral && v.value) shrinkWrapTrue = true;
      }
      if (name == 'physics') {
        Expression v = arg.expression;
        if (v is ParenthesizedExpression) v = v.expression;
        if (v is InstanceCreationExpression &&
            v.constructorName.type.name.lexeme ==
                'NeverScrollableScrollPhysics') {
          neverScrollablePhysics = true;
        }
      }
    }
    // Mirrors the rule's inline-non-scrolling skip.
    final isInlineNonScrolling = shrinkWrapTrue && neverScrollablePhysics;
    if (!hasItemExtent &&
        !hasPrototypeItem &&
        !hasItemExtentBuilder &&
        !isInlineNonScrolling) {
      missingHintCount++;
    }
  }
}

/// Mirrors [PreferOverflowBarOverButtonBarRule] `ButtonBar` detection (ICE + MI).
class _ButtonBarVisitor extends RecursiveAstVisitor<void> {
  static const typeName = 'ButtonBar';

  int count = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == typeName &&
        isMaterialMigrationInstanceCreationTarget(
          typeElement: node.constructorName.type.element,
          typeLexeme: typeName,
          compilationUnit: node.root as CompilationUnit,
        )) {
      count++;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null &&
        node.methodName.name == typeName &&
        node.methodName.element == null &&
        !compilationUnitDeclaresClassLikeName(
          node.root as CompilationUnit,
          typeName,
        )) {
      count++;
    }
    super.visitMethodInvocation(node);
  }
}
