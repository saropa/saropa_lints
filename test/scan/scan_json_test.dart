/// Unit tests for [scanDiagnosticsToJson] serialization.
///
/// Verifies that all fields — including the endLine/endColumn span data added
/// to fix the VS Code single-character highlight UX bug — round-trip through
/// the JSON output.
library;

import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:saropa_lints/src/scan/scan_json.dart';
import 'package:test/test.dart';

void main() {
  group('scanDiagnosticsToJson', () {
    test('emits endLine and endColumn in each diagnostic object', () {
      // A diagnostic spanning line 10 col 3 to line 12 col 15.
      final diag = ScanDiagnostic(
        ruleName: 'avoid_something',
        filePath: '/proj/lib/a.dart',
        line: 10,
        column: 3,
        offset: 200,
        length: 42,
        endLine: 12,
        endColumn: 15,
        severity: 'WARNING',
        problemMessage: 'do not do this',
      );

      final json = scanDiagnosticsToJson([diag]);
      final diagnostics = json['diagnostics']! as List<dynamic>;
      expect(diagnostics, hasLength(1));

      final entry = diagnostics.first as Map<String, Object?>;
      // Start position fields.
      expect(entry['line'], 10);
      expect(entry['column'], 3);
      // End position fields — the point of this test.
      expect(entry['endLine'], 12);
      expect(entry['endColumn'], 15);
      // Other fields still present.
      expect(entry['ruleName'], 'avoid_something');
      expect(entry['severity'], 'WARNING');
      expect(entry['problemMessage'], 'do not do this');
    });

    test('summary counts are correct', () {
      final diags = [
        ScanDiagnostic(
          ruleName: 'rule_a',
          filePath: '/a.dart',
          line: 1,
          column: 1,
          offset: 0,
          length: 5,
          endLine: 1,
          endColumn: 6,
          severity: 'INFO',
          problemMessage: 'msg',
        ),
        ScanDiagnostic(
          ruleName: 'rule_a',
          filePath: '/b.dart',
          line: 2,
          column: 1,
          offset: 10,
          length: 3,
          endLine: 2,
          endColumn: 4,
          severity: 'INFO',
          problemMessage: 'msg',
        ),
      ];

      final json = scanDiagnosticsToJson(diags);
      final summary = json['summary']! as Map<String, Object>;
      expect(summary['totalCount'], 2);
      expect((summary['byRule']! as Map<String, int>)['rule_a'], 2);
      expect((summary['byFile']! as Map<String, int>)['/a.dart'], 1);
      expect((summary['byFile']! as Map<String, int>)['/b.dart'], 1);
    });
  });
}
