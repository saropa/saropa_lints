// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' show Directory, File, Platform, stderr;

import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Writes analysis reports to the project's `reports/` directory.
///
/// Automatically generates two timestamped files after each analysis run:
/// - **Full log** (`_saropa_lint_report_full.log`): Every violation with location and metadata
/// - **Summary** (`_saropa_lint_report_summary.log`): Counts by impact, severity, rule, and file
///
/// Reports are triggered via a debounce timer — after 3 seconds of no new
/// violations, the reporter assumes analysis is complete and writes both files.
///
/// Initialize once per analysis session via [initialize], then call
/// [scheduleWrite] after each violation is recorded.
class AnalysisReporter {
  AnalysisReporter._();

  static String? _projectRoot;
  static String? _timestamp;
  static Timer? _debounceTimer;
  static bool _pathsLogged = false;

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

    final now = DateTime.now();
    _timestamp = '${now.year}'
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
  /// [_debounce] duration, reports are written. Reports are overwritten
  /// on each cycle so the final write captures all violations.
  static void scheduleWrite() {
    if (_projectRoot == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _writeReports);
  }

  /// Write both report files, overwriting any previous output.
  static void _writeReports() {
    if (_projectRoot == null) return;

    try {
      final sep = Platform.pathSeparator;
      final reportsDir = Directory('$_projectRoot${sep}reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final fullPath =
          '${reportsDir.path}/${_timestamp}_saropa_lint_report_full.log';
      final summaryPath =
          '${reportsDir.path}/${_timestamp}_saropa_lint_report_summary.log';

      _writeFullLog(fullPath);
      _writeSummary(summaryPath);

      // Log file paths only on the first write to avoid spamming stderr.
      if (!_pathsLogged) {
        _pathsLogged = true;
        stderr.writeln('');
        stderr.writeln('[saropa_lints] Reports written:');
        stderr.writeln('  Full log: $fullPath');
        stderr.writeln('  Summary:  $summaryPath');
      }
    } catch (e) {
      stderr.writeln('[saropa_lints] Could not write reports: $e');
    }
  }

  /// Write the full violation log.
  static void _writeFullLog(String path) {
    final violations = ImpactTracker.violations;
    final buf = StringBuffer();

    buf.writeln('Saropa Lints Full Analysis Log');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Project: $_projectRoot');
    buf.writeln('${'=' * 70}');
    buf.writeln();

    // Write violations grouped by impact (critical first)
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
    buf.writeln('Total: ${ImpactTracker.total} issues');

    File(path).writeAsStringSync(buf.toString());
  }

  /// Write the markdown summary.
  static void _writeSummary(String path) {
    final counts = ImpactTracker.counts;
    final total = ImpactTracker.total;
    final trackerData = ProgressTracker.reportData;
    final buf = StringBuffer();

    buf.writeln('# Saropa Lints Analysis Summary');
    buf.writeln();
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln();

    // Overview
    buf.writeln('## Overview');
    buf.writeln();
    buf.writeln('| Metric | Value |');
    buf.writeln('|--------|-------|');
    buf.writeln('| Total issues | $total |');
    buf.writeln('| Files analyzed | ${trackerData.filesAnalyzed} |');
    buf.writeln('| Files with issues | ${trackerData.filesWithIssues} |');
    buf.writeln('| Rules triggered | ${trackerData.issuesByRule.length} |');
    buf.writeln();

    // By Impact
    buf.writeln('## By Impact');
    buf.writeln();
    buf.writeln('| Impact | Count | % |');
    buf.writeln('|--------|------:|--:|');
    for (final impact in LintImpact.values) {
      final count = counts[impact] ?? 0;
      if (count == 0) continue;
      final pct = total > 0 ? (count * 100.0 / total).toStringAsFixed(1) : '0';
      buf.writeln('| ${impact.name} | $count | $pct% |');
    }
    buf.writeln();

    // By Severity
    buf.writeln('## By Severity');
    buf.writeln();
    buf.writeln('| Severity | Count |');
    buf.writeln('|----------|------:|');
    if (trackerData.errorCount > 0) {
      buf.writeln('| ERROR | ${trackerData.errorCount} |');
    }
    if (trackerData.warningCount > 0) {
      buf.writeln('| WARNING | ${trackerData.warningCount} |');
    }
    if (trackerData.infoCount > 0) {
      buf.writeln('| INFO | ${trackerData.infoCount} |');
    }
    buf.writeln();

    // Top rules
    _writeTopRules(buf, trackerData);

    // Top files
    _writeTopFiles(buf, trackerData);

    File(path).writeAsStringSync(buf.toString());
  }

  /// Write top rules section to the summary buffer.
  static void _writeTopRules(
    StringBuffer buf,
    ProgressTrackerData data,
  ) {
    if (data.issuesByRule.isEmpty) return;

    final sorted = data.issuesByRule.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);

    buf.writeln('## Top Rules');
    buf.writeln();
    buf.writeln('| # | Rule | Count | Severity |');
    buf.writeln('|--:|------|------:|----------|');
    var i = 1;
    for (final entry in top) {
      final severity = data.ruleSeverities[entry.key] ?? '?';
      buf.writeln('| $i | `${entry.key}` | ${entry.value} | $severity |');
      i++;
    }
    buf.writeln();
  }

  /// Write top files section to the summary buffer.
  static void _writeTopFiles(
    StringBuffer buf,
    ProgressTrackerData data,
  ) {
    if (data.issuesByFile.isEmpty) return;

    final sorted = data.issuesByFile.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);

    buf.writeln('## Top Files');
    buf.writeln();
    buf.writeln('| # | File | Issues |');
    buf.writeln('|--:|------|-------:|');
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
      buf.writeln('| $i | `$filePath` | ${entry.value} |');
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
  }
}
