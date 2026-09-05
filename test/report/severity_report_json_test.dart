/// Tests for the `severity_report` CLI's `--format json` row schema.
///
/// `main()` always shells out to the real `dart analyze`, so this test
/// exercises the extracted, side-effect-free `violationsToJsonRows()`
/// directly instead — same pattern as `test/config/doctor_test.dart`'s
/// `diagnose()` import.
library;

import 'package:saropa_lints/src/models/violation.dart';
import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../../bin/severity_report.dart' show violationsToJsonRows;

void main() {
  group('violationsToJsonRows', () {
    test('empty list maps to empty rows', () {
      expect(violationsToJsonRows(const []), isEmpty);
    });

    test('maps every Violation field into the typed row shape', () {
      final rows = violationsToJsonRows([
        Violation(
          file: 'lib/foo.dart',
          line: 12,
          column: 3,
          rule: 'avoid_print',
          message: 'Do not use print in production code.',
          impact: LintImpact.warning,
        ),
      ]);
      expect(rows, hasLength(1));
      expect(rows.single, {
        'file': 'lib/foo.dart',
        'line': 12,
        'column': 3,
        'rule': 'avoid_print',
        'severity': 'warning',
        'message': 'Do not use print in production code.',
      });
    });

    test('null impact falls back to warning severity', () {
      final rows = violationsToJsonRows([
        Violation(
          file: 'lib/bar.dart',
          line: 1,
          column: 1,
          rule: 'unknown_rule',
          message: 'm',
        ),
      ]);
      expect(rows.single['severity'], 'warning');
    });

    test('preserves error/info severities distinctly', () {
      final rows = violationsToJsonRows([
        Violation(
          file: 'a.dart',
          line: 1,
          column: 1,
          rule: 'r1',
          message: 'm1',
          impact: LintImpact.error,
        ),
        Violation(
          file: 'b.dart',
          line: 2,
          column: 2,
          rule: 'r2',
          message: 'm2',
          impact: LintImpact.info,
        ),
      ]);
      expect(rows[0]['severity'], 'error');
      expect(rows[1]['severity'], 'info');
    });
  });
}
