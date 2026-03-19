/// Machine-readable serialization of scan results.
library;

import 'dart:convert';

import 'scan_diagnostic.dart';

/// JSON keys for the scan report schema.
const String kScanJsonVersion = 'version';
const String kScanJsonDiagnostics = 'diagnostics';
const String kScanJsonSummary = 'summary';
const String kScanJsonTotalCount = 'totalCount';
const String kScanJsonByFile = 'byFile';
const String kScanJsonByRule = 'byRule';

/// Serializes [diagnostics] to the same JSON structure used by
/// `dart run saropa_lints scan --format json`.
///
/// Schema:
/// - `version`: 1 (int)
/// - `diagnostics`: list of objects with: filePath, line, column, ruleName,
///   severity, problemMessage, correctionMessage (optional)
/// - `summary`: object with totalCount, byFile (map filePath -> count),
///   byRule (map ruleName -> count)
Map<String, Object> scanDiagnosticsToJson(List<ScanDiagnostic> diagnostics) {
  final list = diagnostics
      .map(
        (d) => <String, Object?>{
          'filePath': d.filePath,
          'line': d.line,
          'column': d.column,
          'ruleName': d.ruleName,
          'severity': d.severity,
          'problemMessage': d.problemMessage,
          'correctionMessage': d.correctionMessage,
        },
      )
      .toList();

  final byFile = <String, int>{};
  final byRule = <String, int>{};
  for (final d in diagnostics) {
    byFile[d.filePath] = (byFile[d.filePath] ?? 0) + 1;
    byRule[d.ruleName] = (byRule[d.ruleName] ?? 0) + 1;
  }

  return <String, Object>{
    kScanJsonVersion: 1,
    kScanJsonDiagnostics: list,
    kScanJsonSummary: <String, Object>{
      kScanJsonTotalCount: diagnostics.length,
      kScanJsonByFile: byFile,
      kScanJsonByRule: byRule,
    },
  };
}

/// Encodes [diagnostics] to a JSON string (pretty-printed).
String scanDiagnosticsToJsonString(List<ScanDiagnostic> diagnostics) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(scanDiagnosticsToJson(diagnostics));
}
