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
/// - `diagnostics`: list of objects with: filePath, line, column, endLine,
///   endColumn, ruleName, severity, problemMessage, correctionMessage (opt)
/// - `summary`: object with totalCount, byFile (map filePath -> count),
///   byRule (map ruleName -> count)
/// - `failOn` (optional): object with `threshold` and `thresholdMet` when
///   `--fail-on` is active — explains why exit code may differ from the
///   diagnostic list contents.
Map<String, Object> scanDiagnosticsToJson(
  List<ScanDiagnostic> diagnostics, {
  Map<String, Object>? failOn,
}) {
  final list = diagnostics
      .map(
        (d) => <String, Object?>{
          'filePath': d.filePath,
          'line': d.line,
          'column': d.column,
          'endLine': d.endLine,
          'endColumn': d.endColumn,
          'ruleName': d.ruleName,
          'severity': d.severity,
          // Rule-declared impact when available (null for non-saropa rules).
          'impact': d.impact,
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
    // Inject --fail-on metadata when present so JSON consumers understand
    // why the exit code may disagree with an empty diagnostics array.
    if (failOn != null) 'failOn': failOn,
  };
}

/// Encodes [diagnostics] to a JSON string (pretty-printed).
///
/// When [failOn] is provided, a `failOn` object is included in the root
/// to explain exit-code semantics to JSON consumers.
String scanDiagnosticsToJsonString(
  List<ScanDiagnostic> diagnostics, {
  Map<String, Object>? failOn,
}) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(scanDiagnosticsToJson(diagnostics, failOn: failOn));
}
