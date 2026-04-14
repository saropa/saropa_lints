// ignore_for_file: avoid_print

import 'dart:developer' as developer;
import 'dart:io' show Directory, File, Platform, stderr;

import 'package:path/path.dart' as path;
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
    this.mergedRawImports = const <String, List<String>>{},
    this.suppressions = const <SuppressionRecord>[],
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

  /// Union of per-file import/export URIs from all isolate batches, keyed by
  /// absolute normalized paths. Empty when batches omit `ig` (legacy).
  final Map<String, List<String>> mergedRawImports;

  /// Deduplicated suppression records from all isolate batches.
  /// Paths are normalized to project-relative form.
  final List<SuppressionRecord> suppressions;

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
      } catch (e, st) {
        developer.log(
          'initSession read session file failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
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
  /// Paths are normalized to project-relative form so the same file
  /// reported with absolute vs relative path is counted once.
  static ConsolidatedData? consolidate(String projectRoot, String sessionId) {
    final batches = _readAllBatches(projectRoot, sessionId);
    if (batches.isEmpty) return null;
    return _merge(projectRoot, batches);
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
    } catch (e, st) {
      developer.log(
        'cleanupSession failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Cleanup failure is non-critical.
    }
  }

  /// Delete batch files and session markers older than [_sessionTimeout].
  static void _cleanupStaleSessions(String reportsDir) {
    try {
      final base = path.normalize(reportsDir);
      final sessionPath = path.join(base, _sessionFileName);
      if (!path.isWithin(base, sessionPath)) return;

      final sessionFile = File(sessionPath);
      if (!sessionFile.existsSync()) return;

      final age = DateTime.now().difference(sessionFile.lastModifiedSync());
      if (age <= _sessionTimeout) return;

      // Session is stale — remove it and all batch files.
      sessionFile.deleteSync();
      final batchDirPath = path.join(base, _batchDirName);
      if (!path.isWithin(base, batchDirPath)) return;

      final batchDir = Directory(batchDirPath);
      if (batchDir.existsSync()) {
        batchDir.deleteSync(recursive: true);
      }
    } catch (e, st) {
      developer.log(
        '_cleanupStaleSessions failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
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
  static List<BatchData> _readAllBatches(String projectRoot, String sessionId) {
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
        } catch (e, st) {
          developer.log(
            '_readAllBatches batch file read failed',
            name: 'saropa_lints',
            error: e,
            stackTrace: st,
          );
          // Skip corrupted or locked files.
        }
      }
    } catch (e, st) {
      developer.log(
        '_readAllBatches list directory failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // If the directory can't be listed, return what we have.
    }
    return batches;
  }

  /// Normalize a file path to project-relative form with forward slashes.
  ///
  /// Same semantics as `toRelativePath()` in violation_export.dart; not shared
  /// to avoid circular dependency. Ensures the same file is not counted twice when
  /// reported as both absolute and relative path.
  static String _normalizePath(String path, String projectRoot) {
    final root = projectRoot.replaceAll('\\', '/');
    final file = path.replaceAll('\\', '/');
    if (file.startsWith('$root/')) {
      return file.substring(root.length + 1);
    }
    return file;
  }

  /// Merge multiple batches into a single [ConsolidatedData].
  ///
  /// Violations are deduplicated by `(file, line, rule)` using
  /// normalized paths so absolute vs relative path for the same file
  /// count as one. All summary statistics use normalized paths.
  static ConsolidatedData _merge(String projectRoot, List<BatchData> batches) {
    // Use config from first batch (all should be identical).
    final config = batches
        .map((b) => b.config)
        .firstWhere((c) => c != null, orElse: () => null);

    // Merge rule severities from all batches.
    final ruleSeverities = <String, String>{};
    for (final batch in batches) {
      ruleSeverities.addAll(batch.ruleSeverities);
    }

    // Collect all analyzed files (union) with normalized paths.
    final allFiles = <String>{};
    for (final batch in batches) {
      for (final path in batch.analyzedFiles) {
        allFiles.add(_normalizePath(path, projectRoot));
      }
    }

    // Deduplicate violations using normalized paths.
    final deduped = _deduplicateViolations(projectRoot, batches);

    // Recompute statistics from deduplicated violations (paths already normalized).
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

    final mergedImports = _mergeImportSnapshots(projectRoot, batches);
    final mergedSuppressions = _mergeSuppressions(projectRoot, batches);

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
      mergedRawImports: mergedImports,
      suppressions: mergedSuppressions,
    );
  }

  /// Merge `rawImportsByFile` from every batch into one map (absolute keys).
  static Map<String, List<String>> _mergeImportSnapshots(
    String projectRoot,
    List<BatchData> batches,
  ) {
    final merged = <String, Set<String>>{};
    for (final batch in batches) {
      if (batch.rawImportsByFile.isEmpty) continue;
      for (final e in batch.rawImportsByFile.entries) {
        final abs = _absoluteImportSnapshotKey(e.key, projectRoot);
        final canon = _findMergePathKey(merged.keys, abs) ?? abs;
        merged.putIfAbsent(canon, () => <String>{}).addAll(e.value);
      }
    }
    return merged.map((k, s) => MapEntry(k, s.toList()));
  }

  static String _absoluteImportSnapshotKey(String key, String projectRoot) {
    final t = key.trim();
    if (t.isEmpty) return key;
    if (path.isAbsolute(t)) return path.normalize(t);
    return path.normalize(path.join(projectRoot, t));
  }

  static String? _findMergePathKey(Iterable<String> keys, String candidate) {
    for (final k in keys) {
      if (_mergeSameFilePath(k, candidate)) return k;
    }
    return null;
  }

  static bool _mergeSameFilePath(String a, String b) {
    final na = a.replaceAll('\\', '/');
    final nb = b.replaceAll('\\', '/');
    if (na == nb) return true;
    if (Platform.isWindows && na.toLowerCase() == nb.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Deduplicate suppressions by `(file, line, rule)` across all batches.
  ///
  /// Uses normalized paths so the same suppression reported with different
  /// path forms (absolute vs relative) is counted once.
  static List<SuppressionRecord> _mergeSuppressions(
    String projectRoot,
    List<BatchData> batches,
  ) {
    final seen = <String>{};
    final result = <SuppressionRecord>[];

    for (final batch in batches) {
      for (final s in batch.suppressions) {
        final normFile = _normalizePath(s.file, projectRoot);
        final key = '$normFile:${s.line}:${s.rule}';
        if (seen.add(key)) {
          result.add(
            SuppressionRecord(
              rule: s.rule,
              file: normFile,
              line: s.line,
              kind: s.kind,
            ),
          );
        }
      }
    }
    return result;
  }

  /// Deduplicate violations by `(file, line, rule)` across all batches.
  ///
  /// Uses normalized paths for the key and stores [ViolationRecord] with
  /// normalized file path so the same issue is not listed twice when
  /// reported with different path forms.
  static Map<LintImpact, List<ViolationRecord>> _deduplicateViolations(
    String projectRoot,
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
          final normFile = _normalizePath(v.file, projectRoot);
          final key = '$normFile:${v.line}:${v.rule}';
          if (seen.add(key)) {
            deduped.add(
              ViolationRecord(
                rule: v.rule,
                file: normFile,
                line: v.line,
                message: v.message,
                correction: v.correction,
              ),
            );
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
