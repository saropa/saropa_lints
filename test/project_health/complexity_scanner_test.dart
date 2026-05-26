/// Tests for the parsed-AST complexity scanner: cyclomatic, cognitive
/// (nesting-weighted), variable/parameter counts, boolean density, exits.
import 'package:saropa_lints/src/cli/project_health/complexity_scanner.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

FunctionMetric _target(String code) =>
    scanComplexity(code).firstWhere((f) => f.name == 'target');

void main() {
  group('scanComplexity', () {
    test('trivial function is cyclomatic 1, cognitive 0', () {
      final m = _target('int target() => 1;');
      expect(m.cyclomatic, 1);
      expect(m.cognitive, 0);
      expect(m.exitPoints, 0);
    });

    test('counts parameters and local variables', () {
      final m = _target('void target(int a, int b) { var x = 1; var y = 2; }');
      expect(m.parameterCount, 2);
      expect(m.variableCount, 2);
    });

    test('each branch raises cyclomatic', () {
      final m = _target('void target() { if (a) {} }');
      expect(m.cyclomatic, 2);
    });

    test('nested branches weight cognitive above cyclomatic', () {
      const code = '''
void target() {
  if (a) {
    if (b) {
      if (c) {}
    }
  }
}
''';
      final m = _target(code);
      expect(m.cyclomatic, 4); // 1 + 3 ifs
      expect(m.cognitive, 6); // 1 + 2 + 3 (depth-weighted)
      expect(m.cognitive, greaterThan(m.cyclomatic));
    });

    test('boolean operators counted for density and cyclomatic', () {
      final m = _target('void target() { if (a && b || c) {} }');
      expect(m.maxBooleanTerms, 2); // && and ||
      expect(m.cyclomatic, 4); // if + && + ||
    });

    test('multiple returns counted as exit points', () {
      final m = _target('int target() { if (a) { return 1; } return 2; }');
      expect(m.exitPoints, 2);
    });

    test('switch cases each add a decision point', () {
      final m = _target(
        'void target() { switch (x) { case 1: break; case 2: break; } }',
      );
      expect(m.cyclomatic, 4); // switch + 2 cases
    });

    test('finds methods inside classes', () {
      final fns = scanComplexity('class A { void target() {} }');
      expect(fns.map((f) => f.name), contains('target'));
    });
  });
}
