// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' show Directory, File, Platform, stderr;

import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Writes a combined analysis report to the project's `reports/` directory.
///
/// Generates a single timestamped file after each analysis run containing
/// both the full violation list and summary statistics.
///
/// Reports are triggered via a debounce timer — after 3 seconds of no new
/// violations, the reporter assumes analysis is complete and writes the file.
///
/// Initialize once per analysis session via [initialize], then call
/// [scheduleWrite] after each violation is recorded.
class AnalysisReporter {
  AnalysisReporter._();

  static String? _projectRoot;
  static String? _timestamp;
  static Timer? _debounceTimer;
  static bool _pathsLogged = false;
  static bool _sessionEnded = false;

  /// Debounce duration: write reports after this idle period.
  static const Duration _debounce = Duration(seconds: 3);

  /// Initialize the reporter with the project root directory.
  ///
  /// Called once when the first file is analyzed and the project root
  /// is detected. Safe to call multiple times (subsequent calls are ignored).
  static void initialize(String projectRoot) {
    if (_projectRoot != null) return;
    _projectRoot = projectRoot;
    _pathsLogged = false;
    _timestamp = _generateTimestamp();
  }

  /// Generate a timestamp string for the report filename.
  static String _generateTimestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  /// Schedule report writing after a debounce period.
  ///
  /// Each call resets the timer. When no new violations arrive for
  /// `_debounce` duration, reports are written. Reports are overwritten
  /// on each cycle so the final write captures all violations.
  ///
  /// If a previous session ended (debounce fired), this resets all
  /// trackers for a fresh session before scheduling.
  static void scheduleWrite() {
    if (_projectRoot == null) return;

    // Detect new session: if the debounce fired (session ended) and
    // we're being called again, a new analysis run has started.
    if (_sessionEnded) {
      _startNewSession();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _writeReport);
  }

  /// Full path to the report file, or null if not initialized.
  static String? get reportPath {
    if (_projectRoot == null || _timestamp == null) return null;
    final sep = Platform.pathSeparator;
    return '$_projectRoot${sep}reports$sep'
        '${_timestamp}_saropa_lint_report.log';
  }

  /// Reset all trackers and start a fresh session with a new timestamp.
  static void _startNewSession() {
    _sessionEnded = false;
    _pathsLogged = false;

    // Reset trackers so counts don't accumulate across sessions
    ProgressTracker.reset();
    ImpactTracker.reset();

    _timestamp = _generateTimestamp();
  }

  /// Write the combined report file, overwriting any previous output.
  ///
  /// Called by the debounce timer when analysis goes idle. Marks the
  /// session as ended so the next [scheduleWrite] call resets trackers.
  static void _writeReport() {
    if (_projectRoot == null) return;

    _sessionEnded = true;

    try {
      final sep = Platform.pathSeparator;
      final reportsDir = Directory('$_projectRoot${sep}reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final path = reportPath!;
      _writeCombinedReport(path);

      // Log file path only on the first write to avoid spamming stderr.
      if (!_pathsLogged) {
        _pathsLogged = true;
        stderr.writeln('');
        stderr.writeln('[saropa_lints] Report: $path');
      }
    } catch (e) {
      stderr.writeln('[saropa_lints] Could not write report: $e');
    }
  }

  /// Write the combined report (summary + full violation list).
  static void _writeCombinedReport(String path) {
    final violations = ImpactTracker.violations;
    final counts = ImpactTracker.counts;
    final total = ImpactTracker.total;
    final trackerData = ProgressTracker.reportData;
    final buf = StringBuffer();

    // Header
    buf.writeln('Saropa Lints Analysis Report');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Project: $_projectRoot');
    buf.writeln('${'=' * 70}');
    buf.writeln();

    // Overview
    buf.writeln('OVERVIEW');
    buf.writeln('  Total issues:       $total');
    buf.writeln('  Files analyzed:     ${trackerData.filesAnalyzed}');
    buf.writeln('  Files with issues:  ${trackerData.filesWithIssues}');
    buf.writeln('  Rules triggered:    ${trackerData.issuesByRule.length}');
    buf.writeln();

    // By Impact
    _writeImpactSection(buf, counts, total);

    // By Severity
    _writeSeveritySection(buf, trackerData);

    // Top rules
    _writeTopRules(buf, trackerData);

    // Top files
    _writeTopFiles(buf, trackerData);

    // Full violation list
    buf.writeln('${'=' * 70}');
    buf.writeln('ALL VIOLATIONS');
    buf.writeln('${'=' * 70}');
    buf.writeln();

    for (final impact in LintImpact.values) {
      final list = violations[impact];
      if (list == null || list.isEmpty) continue;

      buf.writeln('--- ${impact.name.toUpperCase()} (${list.length}) ---');
      for (final v in list) {
        buf.writeln('  ${v.file}:${v.line} '
            '| [${v.rule}] ${v.message} '
            '| ${impact.name}');
      }
      buf.writeln();
    }

    buf.writeln('${'=' * 70}');
    buf.writeln('Total: $total issues');

    File(path).writeAsStringSync(buf.toString());
  }

  /// Write impact breakdown section.
  static void _writeImpactSection(
    StringBuffer buf,
    Map<LintImpact, int> counts,
    int total,
  ) {
    buf.writeln('BY IMPACT');
    for (final impact in LintImpact.values) {
      final count = counts[impact] ?? 0;
      if (count == 0) continue;
      final pct = total > 0 ? (count * 100.0 / total).toStringAsFixed(1) : '0';
      buf.writeln('  ${impact.name.padRight(12)} $count ($pct%)');
    }
    buf.writeln();
  }

  /// Write severity breakdown section.
  static void _writeSeveritySection(
    StringBuffer buf,
    ProgressTrackerData data,
  ) {
    buf.writeln('BY SEVERITY');
    if (data.errorCount > 0) {
      buf.writeln('  ERROR        ${data.errorCount}');
    }
    if (data.warningCount > 0) {
      buf.writeln('  WARNING      ${data.warningCount}');
    }
    if (data.infoCount > 0) {
      buf.writeln('  INFO         ${data.infoCount}');
    }
    buf.writeln();
  }

  /// Write top rules section.
  static void _writeTopRules(
    StringBuffer buf,
    ProgressTrackerData data,
  ) {
    if (data.issuesByRule.isEmpty) return;

    final sorted = data.issuesByRule.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);

    buf.writeln('TOP RULES');
    var i = 1;
    for (final entry in top) {
      final severity = data.ruleSeverities[entry.key] ?? '?';
      buf.writeln('  ${i.toString().padLeft(2)}. '
          '${entry.key} (${entry.value}) [$severity]');
      i++;
    }
    buf.writeln();
  }

  /// Write top files section.
  static void _writeTopFiles(
    StringBuffer buf,
    ProgressTrackerData data,
  ) {
    if (data.issuesByFile.isEmpty) return;

    final sorted = data.issuesByFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);

    buf.writeln('TOP FILES');
    var i = 1;
    for (final entry in top) {
      // Show relative path from project root
      var filePath = entry.key;
      if (_projectRoot != null && filePath.startsWith(_projectRoot!)) {
        filePath = filePath.substring(_projectRoot!.length);
        if (filePath.startsWith('/') || filePath.startsWith('\\')) {
          filePath = filePath.substring(1);
        }
      }
      buf.writeln('  ${i.toString().padLeft(2)}. $filePath (${entry.value})');
      i++;
    }
    buf.writeln();
  }

  /// Reset state between analysis runs.
  static void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _projectRoot = null;
    _timestamp = null;
    _pathsLogged = false;
    _sessionEnded = false;
  }
}
