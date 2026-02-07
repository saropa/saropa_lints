// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' show Directory, File, Platform, stderr;

import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Snapshot of the analysis configuration captured at rule-loading time.
///
/// Stored by [AnalysisReporter.setAnalysisConfig] and written into the
/// report header so every report file is self-describing.
class ReportConfig {
  const ReportConfig({
    required this.version,
    required this.effectiveTier,
    required this.enabledRuleCount,
    required this.enabledRuleNames,
    required this.enabledPlatforms,
    required this.disabledPlatforms,
    required this.enabledPackages,
    required this.disabledPackages,
    required this.userExclusions,
    required this.maxIssues,
    required this.outputMode,
  });

  final String version;
  final String effectiveTier;
  final int enabledRuleCount;
  final List<String> enabledRuleNames;
  final List<String> enabledPlatforms;
  final List<String> disabledPlatforms;
  final List<String> enabledPackages;
  final List<String> disabledPackages;
  final List<String> userExclusions;
  final int maxIssues;
  final String outputMode;
}

/// Writes a combined analysis report to the project's `reports/` directory.
///
/// Produces a single timestamped file that is overwritten on each debounce
/// cycle, so it always reflects the full cumulative data. Per-file
/// de-duplication in [ProgressTracker] prevents double-counting when the
/// analyzer re-visits a file.
///
/// Initialize once via [initialize], then call [scheduleWrite] on each
/// file visit or violation. Call [reset] to start a fresh report file.
class AnalysisReporter {
  AnalysisReporter._();

  static String? _projectRoot;
  static String? _timestamp;
  static Timer? _debounceTimer;
  static bool _pathsLogged = false;
  static bool _reportWritten = false;
  static ReportConfig? _config;

  /// Debounce duration: write reports after this idle period.
  static const Duration _debounce = Duration(seconds: 3);

  /// Store the analysis configuration for inclusion in report headers.
  ///
  /// Called from `getLintRules()` where all config data is available.
  static void setAnalysisConfig(ReportConfig config) {
    _config = config;
  }

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
  /// [_debounce] duration, the report is written. The same report file
  /// is overwritten on each write so it always reflects cumulative data.
  ///
  /// Per-file de-duplication is handled by [ProgressTracker._clearFileData],
  /// so re-analyzed files don't double-count.
  ///
  /// When a report has already been written and [ProgressTracker] detects
  /// file re-analysis (a new build/session), this method starts a fresh
  /// session: resets trackers, generates a new timestamp, and writes to
  /// a new report file.
  static void scheduleWrite() {
    if (_projectRoot == null) return;

    // Detect new analysis session: a report was already written and the
    // analyzer is now re-visiting files it already processed. This is
    // safe from false positives because late-arriving straggler files are
    // new (wasNew=true) and never set the re-analysis flag.
    if (_reportWritten && ProgressTracker.hasReanalyzedFile) {
      _startNewSession();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _writeReport);
  }

  /// Start a fresh report session.
  ///
  /// Called when re-analysis is detected after a report has been written.
  /// Resets all accumulated data and generates a new timestamp so the
  /// next report is written to a new file.
  static void _startNewSession() {
    ProgressTracker.reset();
    ImpactTracker.reset();
    ProgressTracker.clearReanalysisFlag();
    _timestamp = _generateTimestamp();
    _pathsLogged = false;
    _reportWritten = false;
  }

  /// The project root directory, or null if not initialized.
  static String? get projectRoot => _projectRoot;

  /// Write the report immediately, cancelling any pending debounce.
  ///
  /// Used by the abort mechanism to flush partial results before rules
  /// stop running.
  static void writeNow() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _writeReport();
  }

  /// Full path to the report file, or null if not initialized.
  static String? get reportPath {
    if (_projectRoot == null || _timestamp == null) return null;
    final sep = Platform.pathSeparator;
    return '$_projectRoot${sep}reports$sep'
        '${_timestamp}_saropa_lint_report.log';
  }

  /// Write the combined report file, overwriting any previous output.
  ///
  /// Called by the debounce timer when analysis goes idle. The same
  /// timestamped file is overwritten on each call so late-arriving
  /// results are always included.
  static void _writeReport() {
    if (_projectRoot == null) return;

    try {
      final sep = Platform.pathSeparator;
      final reportsDir = Directory('$_projectRoot${sep}reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final path = reportPath!;
      _writeCombinedReport(path);

      _reportWritten = true;

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
    if (_config != null) {
      buf.writeln('Version: ${_config!.version}');
    }
    buf.writeln('${'=' * 70}');
    buf.writeln();

    // Configuration
    _writeConfigSection(buf);

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
    _writeViolationList(buf, violations);

    buf.writeln('${'=' * 70}');
    buf.writeln('Total: $total issues');

    File(path).writeAsStringSync(buf.toString());
  }

  /// Write the analysis configuration section.
  static void _writeConfigSection(StringBuffer buf) {
    final config = _config;
    if (config == null) {
      buf.writeln('CONFIGURATION');
      buf.writeln('  (not available — config was not captured)');
      buf.writeln();
      return;
    }

    buf.writeln('CONFIGURATION');
    buf.writeln('  Tier:             ${config.effectiveTier}');
    buf.writeln('  Rules enabled:    ${config.enabledRuleCount}');
    buf.writeln('  Max issues:       '
        '${config.maxIssues == 0 ? 'unlimited' : config.maxIssues}');
    buf.writeln('  Output mode:      ${config.outputMode}');
    buf.writeln();

    _writePlatformsSubsection(buf, config);
    _writePackagesSubsection(buf, config);
    _writeExclusionsSubsection(buf, config);
    _writeCustomYamlSubsection(buf);
    _writeEnabledRulesSubsection(buf, config);
  }

  /// Write platforms subsection of the config.
  static void _writePlatformsSubsection(
    StringBuffer buf,
    ReportConfig config,
  ) {
    buf.writeln('  Platforms:');
    if (config.enabledPlatforms.isNotEmpty) {
      buf.writeln('    Enabled:  ${config.enabledPlatforms.join(', ')}');
    }
    if (config.disabledPlatforms.isNotEmpty) {
      buf.writeln('    Disabled: ${config.disabledPlatforms.join(', ')}');
    }
    buf.writeln();
  }

  /// Write packages subsection of the config.
  static void _writePackagesSubsection(
    StringBuffer buf,
    ReportConfig config,
  ) {
    buf.writeln('  Packages:');
    if (config.enabledPackages.isNotEmpty) {
      buf.writeln('    Enabled:  ${config.enabledPackages.join(', ')}');
    }
    if (config.disabledPackages.isNotEmpty) {
      buf.writeln('    Disabled: ${config.disabledPackages.join(', ')}');
    }
    buf.writeln();
  }

  /// Write user exclusions subsection.
  static void _writeExclusionsSubsection(
    StringBuffer buf,
    ReportConfig config,
  ) {
    if (config.userExclusions.isEmpty) return;

    buf.writeln('  User exclusions (${config.userExclusions.length}):');
    for (final rule in config.userExclusions) {
      buf.writeln('    - $rule');
    }
    buf.writeln();
  }

  /// Write the full analysis_options_custom.yaml content verbatim.
  static void _writeCustomYamlSubsection(StringBuffer buf) {
    if (_projectRoot == null) return;

    try {
      final sep = Platform.pathSeparator;
      final customFile =
          File('$_projectRoot${sep}analysis_options_custom.yaml');
      if (!customFile.existsSync()) return;

      final content = customFile.readAsStringSync().trimRight();
      buf.writeln('${'─' * 70}');
      buf.writeln('  analysis_options_custom.yaml:');
      buf.writeln('${'─' * 70}');
      for (final line in content.split('\n')) {
        buf.writeln('  | $line');
      }
      buf.writeln('${'─' * 70}');
      buf.writeln();
    } catch (_) {
      // Silently skip if file can't be read
    }
  }

  /// Write the full list of enabled rule names (sorted).
  static void _writeEnabledRulesSubsection(
    StringBuffer buf,
    ReportConfig config,
  ) {
    if (config.enabledRuleNames.isEmpty) return;

    final sorted = config.enabledRuleNames.toList()..sort();
    buf.writeln('  Enabled rules (${sorted.length}):');
    for (final rule in sorted) {
      buf.writeln('    - $rule');
    }
    buf.writeln();
  }

  /// Write all violations grouped by impact level.
  static void _writeViolationList(
    StringBuffer buf,
    Map<LintImpact, List<ViolationRecord>> violations,
  ) {
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

  /// Reset state for a fresh analysis session.
  ///
  /// Call this before starting a new analysis run (e.g. from `init`)
  /// to clear accumulated data and generate a new report file.
  static void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _projectRoot = null;
    _timestamp = null;
    _pathsLogged = false;
    _reportWritten = false;
    _config = null;
  }
}
