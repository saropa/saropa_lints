import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/rules/config/migration_rule_source_utils.dart';
import 'package:test/test.dart';

/// Behavioral tests for [PreferOverflowBarOverButtonBarRule] (v2).
///
/// Uses [parseString] + AST visitors that mirror production guards so CI does not
/// need a full Flutter SDK resolution context. [copyWith] / property-access
/// branches require [ThemeData] static types and are covered in plugin runs;
/// constructor paths are asserted here including false-positive guards.
void main() {
  const ruleName = 'prefer_overflow_bar_over_button_bar';

  group('PreferOverflowBarOverButtonBarRule', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules
          .map((r) => r.code.name.toLowerCase())
          .toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('recommended tier includes rule', () {
      final recommended = getRulesForTier('recommended');
      expect(recommended.contains(ruleName), isTrue);
    });

    test('metadata and quick fix', () {
      final rule = PreferOverflowBarOverButtonBarRule();
      expect(rule.impact, LintImpact.low);
      expect(rule.requiresFlutterImport, isTrue);
      expect(
        rule.requiredPatterns,
        containsAll(<String>['ButtonBar', 'buttonBarTheme']),
      );
      expect(rule.fixGenerators, hasLength(1));
    });
  });

  group('prefer_overflow_bar ICE parity (parseString)', () {
    test('flags unresolved ButtonBar and ButtonBarThemeData', () {
      expect(
        _countOverflowBarViolations('''
void f() {
  ButtonBar();
  ButtonBarThemeData();
}
'''),
        2,
      );
    });

    test('does not flag project-local ButtonBar / ButtonBarThemeData', () {
      expect(
        _countOverflowBarViolations('''
class ButtonBar {
  ButtonBar();
}
class ButtonBarThemeData {
  ButtonBarThemeData();
}
void f() {
  ButtonBar();
  ButtonBarThemeData();
}
'''),
        0,
      );
    });

    test('flags ThemeData(buttonBarTheme:) when ThemeData is unresolved', () {
      expect(
        _countOverflowBarViolations('''
void f() {
  ThemeData(buttonBarTheme: null);
}
'''),
        1,
      );
    });

    test('does not flag local ThemeData with buttonBarTheme', () {
      expect(
        _countOverflowBarViolations('''
class ThemeData {
  ThemeData({Object? buttonBarTheme});
}
void f() {
  ThemeData(buttonBarTheme: null);
}
'''),
        0,
      );
    });

    test('does not flag ThemeData without buttonBarTheme', () {
      expect(
        _countOverflowBarViolations('''
void f() {
  ThemeData();
}
'''),
        0,
      );
    });
  });

  group('migration_rule_source_utils', () {
    test('sourceRangeForDeletingNamedArgument removes comma neighbors', () {
      final result = parseString(
        content: '''
void main() {
  f(a: 1, b: 2, c: 3);
}
void f({int a = 0, int b = 0, int c = 0}) {}
''',
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      );
      NamedExpression? named;
      result.unit.accept(_FindNamedArgVisitor('b', (n) => named = n));
      expect(named, isNotNull);
      final range = sourceRangeForDeletingNamedArgument(result.content, named!);
      expect(range, isNotNull);
      final out = result.content.replaceRange(range!.offset, range.end, '');
      expect(out, contains('f(a: 1, c: 3)'));
      expect(out, isNot(contains('b: 2')));
    });
  });
}

int _countOverflowBarViolations(String source) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  final visitor = _OverflowBarIceVisitor();
  result.unit.accept(visitor);
  return visitor.count;
}

/// Same instance-creation checks as [PreferOverflowBarOverButtonBarRule].
class _OverflowBarIceVisitor extends RecursiveAstVisitor<void> {
  int count = 0;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final CompilationUnit unit = node.root as CompilationUnit;
    final typeName = node.constructorName.type.name.lexeme;
    if (typeName == 'ButtonBar' || typeName == 'ButtonBarThemeData') {
      if (isMaterialMigrationInstanceCreationTarget(
        typeElement: node.constructorName.type.element,
        typeLexeme: typeName,
        compilationUnit: unit,
      )) {
        count++;
      }
      super.visitInstanceCreationExpression(node);
      return;
    }
    if (typeName == 'ThemeData') {
      if (isMaterialMigrationInstanceCreationTarget(
        typeElement: node.constructorName.type.element,
        typeLexeme: typeName,
        compilationUnit: unit,
      )) {
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'buttonBarTheme') {
            count++;
            break;
          }
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null) return;
    if (node.methodName.element != null) return;
    final m = node.methodName.name;
    final CompilationUnit unit = node.root as CompilationUnit;
    if (m == 'ButtonBar' || m == 'ButtonBarThemeData') {
      if (compilationUnitDeclaresClassLikeName(unit, m)) return;
      count++;
      super.visitMethodInvocation(node);
      return;
    }
    if (m == 'ThemeData') {
      if (compilationUnitDeclaresClassLikeName(unit, 'ThemeData')) return;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'buttonBarTheme') {
          count++;
          return;
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

class _FindNamedArgVisitor extends RecursiveAstVisitor<void> {
  _FindNamedArgVisitor(this.name, this.onFound);

  final String name;
  final void Function(NamedExpression node) onFound;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == name) {
      onFound(node);
    }
    super.visitNamedExpression(node);
  }
}
