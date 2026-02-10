// ignore_for_file: avoid_print

import 'dart:convert' show JsonEncoder;
import 'dart:io' show Directory, File, Platform, stderr;

import 'package:saropa_lints/src/report/analysis_reporter.dart';
import 'package:saropa_lints/src/report/report_consolidator.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Writes a structured JSON export of all lint violations.
///
/// This file is consumed by Saropa Log Capture to cross-reference
/// runtime errors with static analysis findings. The export is written
/// to `reports/.saropa_lints/violations.json` and overwritten on each
/// analysis run.
///
/// See `bugs/discussion/log_capture_integration.md` for the full spec.
class ViolationExporter {
  ViolationExporter._();

  static const String _dirName = '.saropa_lints';
  static const String _fileName = 'violations.json';
  static const String _schemaVersion = '1.0';

  /// Write the structured JSON export alongside the markdown report.
  ///
  /// [projectRoot] is the absolute project root path.
  /// [sessionId] is the current analysis session identifier.
  /// [data] is the consolidated analysis data from all isolates.
  /// [owaspLookup] maps rule names to their OWASP mappings.
  static void write({
    required String projectRoot,
    required String sessionId,
    required ConsolidatedData data,
    required Map<String, OwaspMapping> owaspLookup,
  }) {
    try {
      final json = _buildJson(
        projectRoot: projectRoot,
        sessionId: sessionId,
        data: data,
        owaspLookup: owaspLookup,
      );

      final encoded = const JsonEncoder.withIndent('  ').convert(json);

      _writeAtomic(projectRoot, encoded);
    } catch (e) {
      stderr.writeln('[saropa_lints] Could not write violation export: $e');
    }
  }

  /// Build the full JSON structure for the export.
  static Map<String, Object> _buildJson({
    required String projectRoot,
    required String sessionId,
    required ConsolidatedData data,
    required Map<String, OwaspMapping> owaspLookup,
  }) {
    final config = data.config;

    return <String, Object>{
      'schema': _schemaVersion,
      if (config != null) 'version': config.version,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'sessionId': sessionId,
      'config': _buildConfig(config),
      'summary': _buildSummary(data, projectRoot),
      'violations': _buildViolations(
        projectRoot: projectRoot,
        violations: data.violations,
        ruleSeverities: data.ruleSeverities,
        owaspLookup: owaspLookup,
      ),
    };
  }

  /// Build the config section.
  static Map<String, Object> _buildConfig(ReportConfig? config) {
    if (config == null) {
      return <String, Object>{'tier': 'unknown'};
    }

    return <String, Object>{
      'tier': config.effectiveTier,
      'enabledRuleCount': config.enabledRuleCount,
      'enabledRuleCountNote': 'After tier selection and user overrides',
      'enabledRuleNames': config.enabledRuleNames,
      'enabledPlatforms': config.enabledPlatforms,
      'disabledPlatforms': config.disabledPlatforms,
      'enabledPackages': config.enabledPackages,
      'disabledPackages': config.disabledPackages,
      'userExclusions': config.userExclusions,
      'maxIssues': config.maxIssues,
      'maxIssuesNote':
          'IDE Problems tab cap only; this export contains all violations',
      'outputMode': config.outputMode,
    };
  }

  /// Build the summary section with aggregate counts.
  static Map<String, Object> _buildSummary(
    ConsolidatedData data,
    String projectRoot,
  ) {
    return <String, Object>{
      'filesAnalyzed': data.filesAnalyzed,
      'filesWithIssues': data.filesWithIssues,
      'totalViolations': data.total,
      'batchCount': data.batchCount,
      'bySeverity': <String, int>{
        'error': data.errorCount,
        'warning': data.warningCount,
        'info': data.infoCount,
      },
      'byImpact': <String, int>{
        for (final impact in LintImpact.values)
          impact.name: data.impactCounts[impact] ?? 0,
      },
      'issuesByFile': _relativizeFileKeys(data.issuesByFile, projectRoot),
      'issuesByRule': data.issuesByRule,
      'ruleSeverities': _lowercaseSeverities(data.ruleSeverities),
    };
  }

  /// Lowercase all severity values for consistency with violation entries.
  static Map<String, String> _lowercaseSeverities(
    Map<String, String> severities,
  ) {
    return <String, String>{
      for (final entry in severities.entries)
        entry.key: entry.value.toLowerCase(),
    };
  }

  /// Relativize file path keys for cross-machine compatibility.
  static Map<String, int> _relativizeFileKeys(
    Map<String, int> issuesByFile,
    String projectRoot,
  ) {
    return <String, int>{
      for (final entry in issuesByFile.entries)
        toRelativePath(entry.key, projectRoot): entry.value,
    };
  }

  /// Build the sorted violations list.
  ///
  /// Ordering: impact (critical first) → file (alpha, case-insensitive)
  /// → line (ascending).
  static List<Map<String, Object>> _buildViolations({
    required String projectRoot,
    required Map<LintImpact, List<ViolationRecord>> violations,
    required Map<String, String> ruleSeverities,
    required Map<String, OwaspMapping> owaspLookup,
  }) {
    final result = <_SortableViolation>[];

    for (final impact in LintImpact.values) {
      final list = violations[impact];
      if (list == null) continue;

      for (final v in list) {
        result.add(_SortableViolation(
          record: v,
          impact: impact,
          relativePath: toRelativePath(v.file, projectRoot),
          severity: ruleSeverities[v.rule]?.toLowerCase() ?? 'info',
          owasp: owaspLookup[v.rule],
        ));
      }
    }

    result.sort(_compareViolations);

    return result.map(_violationToJson).toList();
  }

  /// Compare violations for sorting: impact → file → line.
  static int _compareViolations(
    _SortableViolation a,
    _SortableViolation b,
  ) {
    final impactCmp = a.impact.index.compareTo(b.impact.index);
    if (impactCmp != 0) return impactCmp;

    final fileCmp =
        a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase());
    if (fileCmp != 0) return fileCmp;

    return a.record.line.compareTo(b.record.line);
  }

  /// Convert a sortable violation to its JSON representation.
  static Map<String, Object> _violationToJson(_SortableViolation v) {
    return <String, Object>{
      'file': v.relativePath,
      'line': v.record.line,
      'rule': v.record.rule,
      'message': v.record.message,
      if (v.record.correction != null) 'correction': v.record.correction!,
      'severity': v.severity,
      'impact': v.impact.name,
      'owasp': _owaspToJson(v.owasp),
    };
  }

  /// Convert OWASP mapping to JSON with lowercase IDs.
  static Map<String, List<String>> _owaspToJson(OwaspMapping? mapping) {
    if (mapping == null || mapping.isEmpty) {
      return <String, List<String>>{'mobile': <String>[], 'web': <String>[]};
    }

    return <String, List<String>>{
      'mobile': mapping.mobile.map((m) => m.id.toLowerCase()).toList(),
      'web': mapping.web.map((w) => w.id.toLowerCase()).toList(),
    };
  }

  /// Write the file atomically: write to temp, delete old, rename.
  ///
  /// On Windows, `File.rename()` fails if the target exists, so we
  /// delete the target first. If any step fails, fall back to a
  /// direct write.
  static void _writeAtomic(String projectRoot, String content) {
    final sep = Platform.pathSeparator;
    final dir = Directory('$projectRoot${sep}reports$sep$_dirName');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final targetPath = '${dir.path}$sep$_fileName';
    final tmpPath = '$targetPath.tmp';
    final tmpFile = File(tmpPath);
    final targetFile = File(targetPath);

    try {
      // Write to temp file
      tmpFile.writeAsStringSync(content);

      // Delete existing target (required for Windows rename)
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }

      // Rename temp to target
      tmpFile.renameSync(targetPath);
    } catch (_) {
      // Fallback: direct write if atomic strategy fails
      try {
        targetFile.writeAsStringSync(content);
      } catch (e) {
        stderr.writeln(
          '[saropa_lints] Could not write violation export: $e',
        );
      }

      // Clean up temp file if it still exists
      try {
        if (tmpFile.existsSync()) tmpFile.deleteSync();
      } catch (_) {
        // Cleanup failure is non-critical.
      }
    }
  }
}

/// Convert an absolute path to a relative forward-slash path.
///
/// Strips [projectRoot] prefix and normalizes all separators to `/`.
/// Used by both the markdown report and the structured JSON export.
String toRelativePath(String filePath, String projectRoot) {
  final root = projectRoot.replaceAll('\\', '/');
  final file = filePath.replaceAll('\\', '/');
  if (file.startsWith('$root/')) {
    return file.substring(root.length + 1);
  }
  return file;
}

/// Internal holder for sorting violations before JSON serialization.
class _SortableViolation {
  const _SortableViolation({
    required this.record,
    required this.impact,
    required this.relativePath,
    required this.severity,
    required this.owasp,
  });

  final ViolationRecord record;
  final LintImpact impact;
  final String relativePath;
  final String severity;
  final OwaspMapping? owasp;
}
