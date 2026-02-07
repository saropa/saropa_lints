// ignore_for_file: avoid_print

import 'dart:io' show Directory, File, Platform, stderr;

import 'package:saropa_lints/src/report/analysis_reporter.dart';
import 'package:saropa_lints/src/report/batch_data.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Merged analysis data from all isolate batches in a session.
class ConsolidatedData {
  const ConsolidatedData({
    required this.config,
    required this.filesAnalyzed,
    required this.filesWithIssues,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.issuesByFile,
    required this.issuesByRule,
    required this.ruleSeverities,
    required this.violations,
    required this.batchCount,
  });

  final ReportConfig? config;
  final int filesAnalyzed;
  final int filesWithIssues;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final Map<String, int> issuesByFile;
  final Map<String, int> issuesByRule;
  final Map<String, String> ruleSeverities;
  final Map<LintImpact, List<ViolationRecord>> violations;
  final int batchCount;

  /// Total violation count across all impact levels.
  int get total => violations.values.fold(0, (s, l) => s + l.length);

  /// Impact-level counts derived from the violation map.
  Map<LintImpact, int> get impactCounts {
    final result = <LintImpact, int>{};
    for (final entry in violations.entries) {
      if (entry.value.isNotEmpty) {
        result[entry.key] = entry.value.length;
      }
    }
    return result;
  }
}

/// Coordinates report data across plugin isolate restarts.
///
/// Each isolate writes a batch file to `reports/.batches/`. On each
/// debounce cycle the calling isolate reads ALL batch files for the
/// session, merges them (deduplicating violations), and produces a
/// single [ConsolidatedData] for the report writer.
class ReportConsolidator {
  ReportConsolidator._();

  /// Maximum session age before it is considered stale.
  static const Duration _sessionTimeout = Duration(minutes: 30);

  static const String _sessionFileName = '.saropa_session';
  static const String _batchDirName = '.batches';

  // ─────────────────────────────────────────────────────────────────────
  // Session management
  // ─────────────────────────────────────────────────────────────────────

  /// Join an existing session or create a new one.
  ///
  /// Returns the session ID (timestamp string) that all isolates in
  /// this analysis run share. Also cleans up stale sessions.
  static String initSession(String projectRoot) {
    final sep = Platform.pathSeparator;
    final reportsDir = '$projectRoot${sep}reports';
    final sessionFile = File('$reportsDir$sep$_sessionFileName');

    _cleanupStaleSessions(reportsDir);

    // Try to join existing session
    if (sessionFile.existsSync()) {
      try {
        final content = sessionFile.readAsStringSync().trim();
        if (content.isNotEmpty) return content;
      } catch (_) {
        // Fall through to create new session
      }
    }

    // Create new session
    final sessionId = _generateSessionId();
    try {
      final dir = Directory(reportsDir);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      sessionFile.writeAsStringSync(sessionId);

      final batchDir = Directory('$reportsDir$sep$_batchDirName');
      if (!batchDir.existsSync()) batchDir.createSync();
    } catch (e) {
      stderr.writeln('[saropa_lints] Could not create session: $e');
    }
    return sessionId;
  }

  /// Write this isolate's batch data to disk.
  static void writeBatch(String projectRoot, BatchData data) {
    try {
      final path = _batchPath(projectRoot, data.sessionId, data.isolateId);
      final dir = Directory(_batchDir(projectRoot));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File(path).writeAsStringSync(data.toJsonString());
    } catch (e) {
      stderr.writeln('[saropa_lints] Could not write batch: $e');
    }
  }

  /// Read all batch files for [sessionId] and merge into one result.
  ///
  /// If no batch files exist, returns null. Corrupted or locked
  /// batch files are silently skipped.
  static ConsolidatedData? consolidate(
    String projectRoot,
    String sessionId,
  ) {
    final batches = _readAllBatches(projectRoot, sessionId);
    if (batches.isEmpty) return null;
    return _merge(batches);
  }

  /// The report filename for a session.
  static String reportFilename(String sessionId) =>
      '${sessionId}_saropa_lint_report.log';

  // ─────────────────────────────────────────────────────────────────────
  // Cleanup
  // ─────────────────────────────────────────────────────────────────────

  /// Remove batch files and session marker for the current session.
  static void cleanupSession(String projectRoot) {
    try {
      final sep = Platform.pathSeparator;
      final reportsDir = '$projectRoot${sep}reports';
      final sessionFile = File('$reportsDir$sep$_sessionFileName');
      if (sessionFile.existsSync()) sessionFile.deleteSync();

      final batchDir = Directory('$reportsDir$sep$_batchDirName');
      if (batchDir.existsSync()) {
        batchDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Cleanup failure is non-critical.
    }
  }

  /// Delete batch files and session markers older than [_sessionTimeout].
  static void _cleanupStaleSessions(String reportsDir) {
    try {
      final sep = Platform.pathSeparator;
      final sessionFile = File('$reportsDir$sep$_sessionFileName');
      if (!sessionFile.existsSync()) return;

      final age = DateTime.now().difference(sessionFile.lastModifiedSync());
      if (age <= _sessionTimeout) return;

      // Session is stale — remove it and all batch files.
      sessionFile.deleteSync();
      final batchDir = Directory('$reportsDir$sep$_batchDirName');
      if (batchDir.existsSync()) {
        batchDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Cleanup failure is non-critical.
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────────

  static String _generateSessionId() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  static String _batchDir(String projectRoot) {
    final sep = Platform.pathSeparator;
    return '$projectRoot${sep}reports$sep$_batchDirName';
  }

  static String _batchPath(
    String projectRoot,
    String sessionId,
    String isolateId,
  ) {
    final sep = Platform.pathSeparator;
    return '${_batchDir(projectRoot)}$sep'
        '${sessionId}_batch_$isolateId.json';
  }

  /// Read and parse all batch JSON files for [sessionId].
  static List<BatchData> _readAllBatches(
    String projectRoot,
    String sessionId,
  ) {
    final batches = <BatchData>[];
    try {
      final dir = Directory(_batchDir(projectRoot));
      if (!dir.existsSync()) return batches;

      final prefix = '${sessionId}_batch_';
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.startsWith(prefix)) continue;

        try {
          final content = entity.readAsStringSync();
          final batch = BatchData.fromJsonString(content);
          if (batch != null) batches.add(batch);
        } catch (_) {
          // Skip corrupted or locked files.
        }
      }
    } catch (_) {
      // If the directory can't be listed, return what we have.
    }
    return batches;
  }

  /// Merge multiple batches into a single [ConsolidatedData].
  ///
  /// Violations are deduplicated by `(file, line, rule)`. All summary
  /// statistics are recomputed from the deduplicated violation set.
  static ConsolidatedData _merge(List<BatchData> batches) {
    // Use config from first batch (all should be identical).
    final config = batches
        .map((b) => b.config)
        .firstWhere((c) => c != null, orElse: () => null);

    // Merge rule severities from all batches.
    final ruleSeverities = <String, String>{};
    for (final batch in batches) {
      ruleSeverities.addAll(batch.ruleSeverities);
    }

    // Collect all analyzed files (union).
    final allFiles = <String>{};
    for (final batch in batches) {
      allFiles.addAll(batch.analyzedFiles);
    }

    // Deduplicate violations across batches.
    final deduped = _deduplicateViolations(batches);

    // Recompute statistics from deduplicated violations.
    final issuesByFile = <String, int>{};
    final issuesByRule = <String, int>{};
    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;

    for (final entry in deduped.entries) {
      for (final v in entry.value) {
        issuesByFile[v.file] = (issuesByFile[v.file] ?? 0) + 1;
        issuesByRule[v.rule] = (issuesByRule[v.rule] ?? 0) + 1;

        final severity = ruleSeverities[v.rule]?.toUpperCase();
        if (severity == 'ERROR') {
          errorCount++;
        } else if (severity == 'WARNING') {
          warningCount++;
        } else {
          infoCount++;
        }
      }
    }

    return ConsolidatedData(
      config: config,
      filesAnalyzed: allFiles.length,
      filesWithIssues: issuesByFile.length,
      errorCount: errorCount,
      warningCount: warningCount,
      infoCount: infoCount,
      issuesByFile: issuesByFile,
      issuesByRule: issuesByRule,
      ruleSeverities: ruleSeverities,
      violations: deduped,
      batchCount: batches.length,
    );
  }

  /// Deduplicate violations by `(file, line, rule)` across all batches.
  static Map<LintImpact, List<ViolationRecord>> _deduplicateViolations(
    List<BatchData> batches,
  ) {
    final seen = <String>{};
    final result = <LintImpact, List<ViolationRecord>>{};

    for (final impact in LintImpact.values) {
      final deduped = <ViolationRecord>[];

      for (final batch in batches) {
        final list = batch.violations[impact];
        if (list == null) continue;

        for (final v in list) {
          final key = '${v.file}:${v.line}:${v.rule}';
          if (seen.add(key)) {
            deduped.add(v);
          }
        }
      }

      if (deduped.isNotEmpty) {
        result[impact] = deduped;
      }
    }
    return result;
  }
}
