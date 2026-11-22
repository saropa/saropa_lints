import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/rules/core/class_constructor_rules.dart';
import 'package:test/test.dart';

/// Behavioral tests for avoid_variable_shadowing wildcard handling.
///
/// The shadowing walk is purely syntactic, so it runs on an unresolved AST via
/// [AvoidShadowingRule.shadowedNamesForTesting].
void main() {
  // Parses a single top-level function and returns the flagged names.
  List<String> flagged(String src, [Set<String> outer = const {'f'}]) {
    final unit = parseString(content: src, throwIfDiagnostics: false).unit;
    final fn = unit.declarations.whereType<FunctionDeclaration>().first;
    return AvoidShadowingRule.shadowedNamesForTesting(
      fn.functionExpression.body,
      outer,
    );
  }

  group('avoid_variable_shadowing wildcard `_`', () {
    test('NO lint: repeated `_` locals in nested scopes', () {
      expect(
        flagged('''
void f() {
  final bool _ = true;
  void inner() {
    final bool _ = false;
  }
}
'''),
        isEmpty,
      );
    });

    test('NO lint: `_` for-in loop variable after `_` local', () {
      expect(
        flagged('''
void f() {
  final _ = 1;
  for (final _ in [1]) {}
}
'''),
        isEmpty,
      );
    });

    test('LINT: real shadowing still reported', () {
      expect(
        flagged('''
void f() {
  final x = 1;
  void inner() {
    final x = 2;
  }
}
'''),
        ['x'],
      );
    });
  });
}
