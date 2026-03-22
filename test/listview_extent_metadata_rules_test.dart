import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/config/migration_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show LintImpact;
import 'package:test/test.dart';

/// Unit tests for ListView extent-hint rules (itemExtentBuilder / separated) and
/// [PreferOverflowBarOverButtonBarRule] AST shape expectations.
///
/// Mirrors the named-argument scan used in production rules (no full plugin run).
void main() {
  group('AvoidListViewWithoutItemExtentRule (argument scan)', () {
    test('flags builder and separated without any extent hint', () {
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
      expect(_countListViewsMissingExtentHints(code), 2);
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
  });

  group('PreferOverflowBarOverButtonBarRule (metadata + AST)', () {
    test('uses low impact, Flutter gating, and ButtonBar pattern index', () {
      final rule = PreferOverflowBarOverButtonBarRule();
      expect(rule.impact, LintImpact.low);
      expect(rule.requiresFlutterImport, isTrue);
      expect(rule.requiredPatterns, contains('ButtonBar'));
    });

    test('counts ButtonBar instance creations but not comments', () {
      // Minimal stub: avoid `children: []` parse quirks in some analyzer versions.
      expect(
        _countButtonBarCreations('''
class ButtonBar {
  ButtonBar();
}
// ButtonBar( is not a widget
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
    final method = node.methodName.name;
    if (method == 'builder' || method == 'separated') {
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
    if (typeName == 'ListView' && (name == 'builder' || name == 'separated')) {
      _countIfMissingHints(args);
    }
  }

  void _countIfMissingHints(ArgumentList argumentList) {
    var hasItemExtent = false;
    var hasPrototypeItem = false;
    var hasItemExtentBuilder = false;
    for (final arg in argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      if (name == 'itemExtent') hasItemExtent = true;
      if (name == 'prototypeItem') hasPrototypeItem = true;
      if (name == 'itemExtentBuilder') hasItemExtentBuilder = true;
    }
    if (!hasItemExtent && !hasPrototypeItem && !hasItemExtentBuilder) {
      missingHintCount++;
    }
  }
}

class _ButtonBarVisitor extends RecursiveAstVisitor<void> {
  int count = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'ButtonBar') {
      count++;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Unresolved or shorthand: `ButtonBar()` parses as MethodInvocation in
    // some parseString contexts; the plugin sees InstanceCreationExpression
    // against material.dart.
    if (node.methodName.name == 'ButtonBar' && node.target == null) {
      count++;
    }
    super.visitMethodInvocation(node);
  }
}
