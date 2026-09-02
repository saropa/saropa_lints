/// SARIF 2.1.0 serialization of audit results.
///
/// Lets `dart run saropa_lints audit --format sarif` feed GitHub code-scanning
/// annotations directly on a PR diff (see `bugs/../PLAN_full_audit.md`'s
/// "SARIF output" brainstorm section — this is the implementation of that
/// deferred idea).
library;

import 'dart:convert';

import 'package:path/path.dart' as p;

/// The SARIF schema this module emits. Pinned to 2.1.0 — GitHub code
/// scanning only accepts this version, so bumping it is a breaking change
/// for consumers, not a routine update.
const String _kSarifVersion = '2.1.0';
const String _kSarifSchemaUri =
    'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json';

/// Maps this project's three-level [LintImpact]/severity scale (error,
/// warning, info — see `saropa_lint_rule.dart`) onto SARIF's `level` enum
/// (error, warning, note, none). There is no finer-grained scale in the
/// codebase to draw from, so this is a direct 1:1 mapping, not an invented
/// scale. Unrecognized values fall back to `warning` rather than `none`,
/// because `none` means "not evaluated as a problem" in the SARIF spec —
/// a worse default for an unknown diagnostic than surfacing it visibly.
String sarifLevelForSeverity(String? severity) {
  switch ((severity ?? '').toLowerCase()) {
    case 'error':
      return 'error';
    case 'warning':
      return 'warning';
    case 'info':
      return 'note';
    default:
      return 'warning';
  }
}

/// Converts [filePath] to a URI relative to [rootPath] using forward
/// slashes. SARIF's `artifactLocation.uri` is defined as a URI reference,
/// and URIs always use `/` as the path separator regardless of host OS —
/// emitting Windows backslashes here would produce an invalid SARIF file
/// that GitHub's code-scanning importer rejects.
String _toSarifUri(String filePath, String rootPath) {
  // `p.relative` also normalizes `..`/`.` segments and mismatched
  // separators between filePath and rootPath (e.g. one absolute, one not).
  final relative = p.relative(filePath, from: rootPath);
  return relative.replaceAll(r'\', '/');
}

/// Builds one SARIF `result` object from a single enriched diagnostic map
/// (the same shape produced by `scanDiagnosticsToJson`, optionally enriched
/// with `tier`/`category`/`baselineStatus` by `bin/audit.dart`).
Map<String, dynamic> _resultFromDiagnostic(
  Map<String, dynamic> diagnostic,
  String rootPath,
) {
  final filePath = diagnostic['filePath'] as String? ?? '';
  // Extra fields beyond the SARIF core schema are carried in `properties` —
  // a spec-legal arbitrary bag (SARIF 2.1.0 §3.8, "property bag") — so
  // tier/category/baseline data survives the SARIF round-trip for consumers
  // that want it, without inventing new top-level SARIF fields.
  // Validated: GitHub code-scanning and VS Code SARIF Viewer both tolerate
  // unknown `properties` keys per the spec's explicit allowance.
  final properties = <String, dynamic>{
    for (final key in ['tier', 'category', 'baselineStatus'])
      if (diagnostic[key] != null) key: diagnostic[key],
  };

  return <String, dynamic>{
    'ruleId': diagnostic['ruleName'],
    'level': sarifLevelForSeverity(diagnostic['severity'] as String?),
    'message': <String, dynamic>{'text': diagnostic['problemMessage'] ?? ''},
    'locations': [
      <String, dynamic>{
        'physicalLocation': <String, dynamic>{
          'artifactLocation': <String, dynamic>{
            'uri': _toSarifUri(filePath, rootPath),
          },
          'region': <String, dynamic>{
            'startLine': diagnostic['line'],
            'startColumn': diagnostic['column'],
            'endLine': diagnostic['endLine'],
            'endColumn': diagnostic['endColumn'],
          },
        },
      },
    ],
    if (properties.isNotEmpty) 'properties': properties,
  };
}

/// Builds the `tool.driver.rules[]` array: one `reportingDescriptor` per
/// distinct rule name seen in [diagnostics], in first-seen order. GitHub's
/// code-scanning UI uses this to label and group findings by rule, and
/// SARIF disallows duplicate rule ids in this array — hence the `Set` guard.
List<Map<String, dynamic>> _ruleDescriptors(
  List<Map<String, dynamic>> diagnostics,
) {
  final seen = <String>{};
  final descriptors = <Map<String, dynamic>>[];
  for (final diagnostic in diagnostics) {
    final ruleName = diagnostic['ruleName'] as String?;
    if (ruleName == null || !seen.add(ruleName)) continue;
    descriptors.add(<String, dynamic>{'id': ruleName});
  }
  return descriptors;
}

/// Builds a full SARIF 2.1.0 log for [diagnostics] (enriched diagnostic
/// maps as produced by `scanDiagnosticsToJson` + audit's tier/category
/// enrichment). [rootPath] anchors the relative `artifactLocation.uri`
/// values. [toolVersion] should be `saropaLintsVersion` from
/// `package:saropa_lints/saropa_lints.dart` — passed in rather than read
/// here so this module has no dependency on the package's own export graph.
Map<String, dynamic> buildSarifReport(
  List<Map<String, dynamic>> diagnostics, {
  required String rootPath,
  required String toolVersion,
}) {
  return <String, dynamic>{
    r'$schema': _kSarifSchemaUri,
    'version': _kSarifVersion,
    'runs': [
      <String, dynamic>{
        'tool': <String, dynamic>{
          'driver': <String, dynamic>{
            'name': 'saropa_lints',
            'version': toolVersion,
            'rules': _ruleDescriptors(diagnostics),
          },
        },
        'results': [
          for (final diagnostic in diagnostics)
            _resultFromDiagnostic(diagnostic, rootPath),
        ],
      },
    ],
  };
}

/// Encodes [diagnostics] as a pretty-printed SARIF 2.1.0 JSON string.
/// Mirrors `scanDiagnosticsToJsonString`'s encoding convention (2-space
/// indent) so both output formats look consistent to a human reading
/// `--output` files side by side.
String sarifReportToJsonString(
  List<Map<String, dynamic>> diagnostics, {
  required String rootPath,
  required String toolVersion,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    buildSarifReport(
      diagnostics,
      rootPath: rootPath,
      toolVersion: toolVersion,
    ),
  );
}
