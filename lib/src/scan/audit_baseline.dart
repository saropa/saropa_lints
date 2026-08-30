/// Baseline save/load/diff logic for audit `--baseline` / `--save-baseline`.
///
/// A baseline is a previous audit snapshot stored at
/// `.saropa/audit_baseline.json`. Comparing the current audit against a
/// baseline tags each diagnostic as `new`, `unchanged`, or `resolved`,
/// turning the audit into a ratchet: teams fix new findings without being
/// overwhelmed by the existing backlog.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Default baseline file path relative to the project root.
const _defaultBaseline = '.saropa/audit_baseline.json';

/// Returns the absolute path to the baseline file for [projectRoot].
/// Uses [overridePath] if provided, otherwise the default location.
String baselinePath(String projectRoot, {String? overridePath}) {
  if (overridePath != null) return p.absolute(overridePath);
  return p.join(projectRoot, _defaultBaseline);
}

/// Returns `true` if a baseline file exists at the resolved path.
bool baselineExists(String projectRoot, {String? overridePath}) {
  return File(
    baselinePath(projectRoot, overridePath: overridePath),
  ).existsSync();
}

/// Loads the baseline file and returns its diagnostics as a set of
/// identity keys (file:line:col:rule) for fast lookup.
///
/// Returns `null` if the file doesn't exist or can't be parsed.
BaselineData? loadBaseline(String projectRoot, {String? overridePath}) {
  final path = baselinePath(projectRoot, overridePath: overridePath);
  final file = File(path);
  if (!file.existsSync()) return null;

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final timestamp = json['timestamp'] as String? ?? '';
    final diagnostics = (json['diagnostics'] as List<dynamic>?) ?? [];

    // Build a set of diagnostic identity keys for diffing.
    final keys = <String>{};
    for (final d in diagnostics) {
      if (d is Map<String, dynamic>) {
        keys.add(_diagnosticKey(d));
      }
    }

    return BaselineData(timestamp: timestamp, diagnosticKeys: keys);
  } on FormatException {
    return null;
  }
}

/// Saves the audit JSON as the project baseline.
///
/// Creates the `.saropa/` directory if it doesn't exist.
void saveBaseline(
  String projectRoot,
  Map<String, dynamic> auditJson, {
  String? overridePath,
}) {
  final path = baselinePath(projectRoot, overridePath: overridePath);
  final dir = Directory(p.dirname(path));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File(
    path,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(auditJson));
}

/// Tags each diagnostic in [diagnostics] with a `baselineStatus` field
/// (`new`, `unchanged`, or `resolved`) and returns summary counts.
///
/// Mutates the maps in [diagnostics] in place — adds `baselineStatus`.
/// Also returns the list of resolved diagnostics (present in baseline
/// but absent in current) so they can be included in the output.
BaselineDiffResult diffAgainstBaseline(
  List<Map<String, dynamic>> diagnostics,
  BaselineData baseline,
) {
  var newCount = 0;
  var unchangedCount = 0;

  // Tag each current diagnostic.
  for (final d in diagnostics) {
    final key = _diagnosticKey(d);
    if (baseline.diagnosticKeys.contains(key)) {
      d['baselineStatus'] = 'unchanged';
      unchangedCount++;
    } else {
      d['baselineStatus'] = 'new';
      newCount++;
    }
  }

  // Find resolved diagnostics: in baseline but not in current.
  final currentKeys = diagnostics.map(_diagnosticKey).toSet();
  final resolvedCount = baseline.diagnosticKeys.difference(currentKeys).length;

  return BaselineDiffResult(
    baselineTimestamp: baseline.timestamp,
    newCount: newCount,
    unchangedCount: unchangedCount,
    resolvedCount: resolvedCount,
  );
}

/// Identity key for a diagnostic — file path + line + column + rule name.
///
/// This deliberately excludes the problem message so that minor wording
/// changes to a rule's message don't cause a diagnostic to flip from
/// "unchanged" to "new".
String _diagnosticKey(Map<String, dynamic> d) {
  final file = d['filePath'] as String? ?? '';
  final line = d['line'] ?? 0;
  final col = d['column'] ?? 0;
  final rule = d['ruleName'] as String? ?? '';
  return '$file:$line:$col:$rule';
}

/// Parsed baseline data — just the timestamp and the set of diagnostic keys.
class BaselineData {
  /// Creates baseline data with the snapshot [timestamp] and the set of
  /// diagnostic identity keys for diffing.
  const BaselineData({required this.timestamp, required this.diagnosticKeys});

  /// ISO-8601 timestamp of when the baseline was captured.
  final String timestamp;

  /// Set of `file:line:col:rule` identity keys from the baseline.
  final Set<String> diagnosticKeys;
}

/// Summary of the diff between a current audit and a baseline.
class BaselineDiffResult {
  /// Creates a diff result with the baseline's [baselineTimestamp] and
  /// counts of new, unchanged, and resolved diagnostics.
  const BaselineDiffResult({
    required this.baselineTimestamp,
    required this.newCount,
    required this.unchangedCount,
    required this.resolvedCount,
  });

  /// ISO-8601 timestamp of the baseline this was compared against.
  final String baselineTimestamp;

  /// Diagnostics in the current audit that were NOT in the baseline.
  final int newCount;

  /// Diagnostics present in both current audit and baseline.
  final int unchangedCount;

  /// Diagnostics in the baseline that are no longer present.
  final int resolvedCount;
}
