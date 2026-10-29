/// Behavioral tests for the private-method-parameter guard on
/// `AvoidDriftRawSqlInterpolationRule`. Syntactic harness (no resolution).
library;

import 'package:saropa_lints/src/rules/packages/drift_rules.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

int _count(String code) =>
    runRuleSyntactic(AvoidDriftRawSqlInterpolationRule(), code).length;

const String _body =
    "  Future<void> _add(String d) async {\n"
    "    await customStatement('ALTER TABLE t ADD COLUMN \$d');\n"
    "  }\n";

void main() {
  group('avoid_drift_raw_sql_interpolation - private parameter', () {
    test('all callers pass literals - no lint', () {
      expect(
        _count(
          "class A {\n$_body"
          "  Future<void> run() async {\n"
          "    await _add('a TEXT');\n    await _add('b INTEGER');\n  }\n}\n",
        ),
        0,
      );
    });

    test('one non-literal caller - lint', () {
      expect(
        _count(
          "class A {\n$_body"
          "  Future<void> run(String x) async {\n"
          "    await _add('a TEXT');\n    await _add(x);\n  }\n}\n",
        ),
        1,
      );
    });

    test('tear-off - lint', () {
      expect(
        _count(
          "class A {\n$_body"
          "  void run() {\n    _add('a');\n    final f = _add;\n  }\n}\n",
        ),
        1,
      );
    });

    test('no callers in file - lint', () {
      expect(_count('class A {\n$_body}\n'), 1);
    });

    test('public method - lint', () {
      expect(
        _count(
          "class A {\n${_body.replaceAll('_add', 'add')}"
          "  void run() {\n    add('a');\n  }\n}\n",
        ),
        1,
      );
    });
  });
}
