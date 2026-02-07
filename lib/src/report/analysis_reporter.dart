// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' show Directory, File, Platform, stderr;
import 'dart:math' show Random;

import 'package:saropa_lints/src/report/batch_data.dart';
import 'package:saropa_lints/src/report/import_graph_tracker.dart';
import 'package:saropa_lints/src/report/report_consolidator.dart';
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
  static String? _sessionId;
  static String? _isolateId;
  static Timer? _debounceTimer;
  static bool _pathsLogged = false;
  static bool _reportWritten = false;
  static ReportConfig? _config;

  /// Debounce duration: write reports after this idle period.
  static const Duration _debounce = Duration(seconds: 3);

  /// Maximum violations to write inline in the report.
  /// Higher-impact violations take priority when the cap is reached.
  static const int _maxInlineViolations = 500;

  /// Maximum report files to keep in the reports directory.
  static const int _maxReportFiles = 10;

  /// Maximum rows in the FILE IMPORTANCE table.
  static const int _maxFileImportanceRows = 50;

  /// Store the analysis configuration for inclusion in report headers.
  ///
  /// Called from `getLintRules()` where all config data is available.
  static void setAnalysisConfig(ReportConfig config) {
    _config = config;
  }

  /// Initialize the reporter with the project root directory.
  ///
  /// Joins an existing session (from a prior isolate in the same
  /// analysis run) or creates a new one. Safe to call multiple times.
  static void initialize(String projectRoot) {
    if (_projectRoot != null) return;
    _projectRoot = projectRoot;
    _pathsLogged = false;
    _sessionId = ReportConsolidator.initSession(projectRoot);
    _isolateId = _generateIsolateId();
  }

  /// Generate a short unique ID for this isolate.
  static String _generateIsolateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0xFFFF);
    return (now ^ rand).toRadixString(36).substring(0, 6);
  }

  /// Schedule report writing after a debounce period.
  ///
  /// Each call resets the timer. When no new violations arrive for
  /// `_debounce` duration, the report is written. The same report file
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
    ImportGraphTracker.reset();
    ProgressTracker.clearReanalysisFlag();
    if (_projectRoot != null) {
      ReportConsolidator.cleanupSession(_projectRoot!);
      _sessionId = ReportConsolidator.initSession(_projectRoot!);
    }
    _isolateId = _generateIsolateId();
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
    if (_projectRoot == null || _sessionId == null) return null;
    final sep = Platform.pathSeparator;
    return '$_projectRoot${sep}reports$sep'
        '${ReportConsolidator.reportFilename(_sessionId!)}';
  }

  /// Write the consolidated report file.
  ///
  /// Called by the debounce timer when analysis goes idle. Writes
  /// this isolate's batch data, then reads ALL batches from the
  /// session and merges them into one report file.
  static void _writeReport() {
    if (_projectRoot == null || _sessionId == null) return;

    try {
      final sep = Platform.pathSeparator;
      final reportsDir = Directory('$_projectRoot${sep}reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      // 1. Write this isolate's batch file
      _writeBatchFile();

      // 2. Consolidate all batches into one report
      final consolidated = ReportConsolidator.consolidate(
        _projectRoot!,
        _sessionId!,
      );
      if (consolidated == null) return;

      // 3. Write the consolidated report
      final path = reportPath!;
      _writeCombinedReport(path, consolidated);

      _reportWritten = true;
      _cleanOldReports();

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

  /// Write this isolate's data as a batch file for cross-isolate merging.
  static void _writeBatchFile() {
    if (_projectRoot == null || _sessionId == null) return;

    final trackerData = ProgressTracker.reportData;
    final batch = BatchData(
      sessionId: _sessionId!,
      isolateId: _isolateId ?? 'unknown',
      updatedAt: DateTime.now(),
      config: _config,
      analyzedFiles: ProgressTracker.analyzedFiles.toList(),
      issuesByFile: trackerData.issuesByFile,
      issuesByRule: trackerData.issuesByRule,
      ruleSeverities: trackerData.ruleSeverities,
      severityCounts: SeverityCounts(
        error: trackerData.errorCount,
        warning: trackerData.warningCount,
        info: trackerData.infoCount,
      ),
      violations: ImpactTracker.violations,
    );

    ReportConsolidator.writeBatch(_projectRoot!, batch);
  }

  /// Write the consolidated report (summary + full violation list).
  static void _writeCombinedReport(String path, ConsolidatedData data) {
    ImportGraphTracker.compute();

    final config = data.config ?? _config;
    final buf = StringBuffer();

    _writeHeader(buf, config, data.batchCount);
    _writeConfigSection(buf, config);
    _writeOverview(buf, data);
    _writeImpactSection(buf, data.impactCounts, data.total);
    _writeSeveritySubsection(buf, data);
    _writeTopRulesFromMap(buf, data.issuesByRule, data.ruleSeverities);
    _writeFileImportance(buf, data.issuesByFile);
    _writePrioritizedViolations(buf, data.violations);
    _writeViolationList(buf, data.violations);
    _writeProjectStructure(buf);

    buf.writeln('${'=' * 70}');
    buf.writeln('Total: ${data.total} issues');

    File(path).writeAsStringSync(buf.toString());
  }

  /// Write the report header block.
  static void _writeHeader(
    StringBuffer buf,
    ReportConfig? config,
    int batchCount,
  ) {
    buf.writeln('Saropa Lints Analysis Report');
    buf.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buf.writeln('Project: $_projectRoot');
    if (config != null) {
      buf.writeln('Version: ${config.version}');
    }
    if (batchCount > 1) {
      buf.writeln('Batches: $batchCount isolates contributed');
    }
    buf.writeln('${'=' * 70}');
    buf.writeln();
  }

  /// Write the overview statistics block.
  static void _writeOverview(StringBuffer buf, ConsolidatedData data) {
    buf.writeln('OVERVIEW');
    buf.writeln('  Total issues:       ${data.total}');
    buf.writeln('  Files analyzed:     ${data.filesAnalyzed}');
    buf.writeln('  Files with issues:  ${data.filesWithIssues}');
    buf.writeln('  Rules triggered:    ${data.issuesByRule.length}');
    buf.writeln();
  }

  /// Write the analysis configuration section.
  static void _writeConfigSection(StringBuffer buf, ReportConfig? config) {
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

  /// Write violations grouped by impact level, capped at
  /// [_maxInlineViolations] total. Higher-impact violations take
  /// priority when the cap is reached.
  static void _writeViolationList(
    StringBuffer buf,
    Map<LintImpact, List<ViolationRecord>> violations,
  ) {
    final total = violations.values.fold(0, (s, l) => s + l.length);

    buf.writeln('${'=' * 70}');
    buf.writeln(
        'ALL VIOLATIONS${total > _maxInlineViolations ? ' (showing $_maxInlineViolations of $total)' : ''}');
    buf.writeln('${'=' * 70}');
    buf.writeln();

    var remaining = _maxInlineViolations;

    for (final impact in LintImpact.values) {
      final list = violations[impact];
      if (list == null || list.isEmpty) continue;

      final toWrite = remaining >= list.length ? list.length : remaining;
      _writeImpactViolations(buf, impact, list, toWrite);
      remaining -= toWrite;
    }
  }

  /// Write violations for a single impact level, capped at [limit].
  static void _writeImpactViolations(
    StringBuffer buf,
    LintImpact impact,
    List<ViolationRecord> list,
    int limit,
  ) {
    buf.writeln('--- ${impact.name.toUpperCase()} (${list.length}) ---');

    for (var i = 0; i < limit; i++) {
      final v = list[i];
      buf.writeln('  ${v.file}:${v.line} '
          '| [${v.rule}] ${v.message} '
          '| ${impact.name}');
    }

    final omitted = list.length - limit;
    if (omitted > 0) {
      buf.writeln('  ... $omitted more ${impact.name} violations omitted');
    }
    buf.writeln();
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
  static void _writeSeveritySubsection(
    StringBuffer buf,
    ConsolidatedData data,
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

  /// Write top rules section from raw maps.
  static void _writeTopRulesFromMap(
    StringBuffer buf,
    Map<String, int> issuesByRule,
    Map<String, String> ruleSeverities,
  ) {
    if (issuesByRule.isEmpty) return;

    final sorted = issuesByRule.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(20);

    buf.writeln('TOP RULES');
    var i = 1;
    for (final entry in top) {
      final severity = ruleSeverities[entry.key] ?? '?';
      buf.writeln('  ${i.toString().padLeft(2)}. '
          '${entry.key} (${entry.value}) [$severity]');
      i++;
    }
    buf.writeln();
  }

  /// Write all analyzed files ranked by importance score.
  ///
  /// Replaces the old TOP FILES section (which was just a violation count).
  /// Shows every file with its importance score, fan-in, layer, and
  /// issue count so the developer sees which files matter most.
  static void _writeFileImportance(
    StringBuffer buf,
    Map<String, int> issuesByFile,
  ) {
    final files = ImportGraphTracker.allFiles;
    if (files.isEmpty) return;

    // Build scored list: all known files
    final scored =
        <({String path, double score, int fanIn, String layer, int issues})>[];
    for (final file in files) {
      scored.add((
        path: file,
        score: ImportGraphTracker.getFileScore(file),
        fanIn: ImportGraphTracker.importersOf(file).length,
        layer: ImportGraphTracker.getLayer(file),
        issues: issuesByFile[file] ?? 0,
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));

    final capped = scored.take(_maxFileImportanceRows).toList();
    final omitted = scored.length - capped.length;

    buf.writeln('FILE IMPORTANCE (${scored.length} files, '
        'sorted by priority score'
        '${omitted > 0 ? ', showing top ${capped.length}' : ''})');
    buf.writeln('  ${'Score'.padLeft(5)} | '
        '${'Fan-in'.padLeft(6)} | '
        '${'Layer'.padRight(10)} | '
        '${'Issues'.padLeft(6)} | File');
    buf.writeln('  ${'-' * 5}-+-${'-' * 6}-+-'
        '${'-' * 10}-+-${'-' * 6}-+-${'-' * 30}');

    for (final f in capped) {
      buf.writeln('  ${f.score.toStringAsFixed(0).padLeft(5)} | '
          '${f.fanIn.toString().padLeft(6)} | '
          '${f.layer.padRight(10)} | '
          '${f.issues.toString().padLeft(6)} | '
          '${_relativePath(f.path)}');
    }

    if (omitted > 0) {
      buf.writeln('  ... $omitted more files omitted');
    }
    buf.writeln();
  }

  /// Write all violations sorted by priority score descending.
  ///
  /// Each violation's priority combines its impact level, the file's
  /// importance (fan-in), and the file's architectural layer weight.
  static void _writePrioritizedViolations(
    StringBuffer buf,
    Map<LintImpact, List<ViolationRecord>> violations,
  ) {
    // Flatten all violations with their impact
    final all = <({ViolationRecord v, LintImpact impact, double priority})>[];
    for (final entry in violations.entries) {
      for (final v in entry.value) {
        all.add((
          v: v,
          impact: entry.key,
          priority: ImportGraphTracker.getPriority(v.file, entry.key),
        ));
      }
    }
    if (all.isEmpty) return;

    all.sort((a, b) => b.priority.compareTo(a.priority));

    final showing =
        all.length > _maxInlineViolations ? _maxInlineViolations : all.length;

    buf.writeln('${'=' * 70}');
    buf.writeln('FIX PRIORITY (${all.length} violations, '
        'sorted by priority = impact * importance * layer)');
    buf.writeln('${'=' * 70}');
    buf.writeln();
    buf.writeln('  ${'Priority'.padLeft(8)} | '
        '${'Impact'.padRight(11)} | '
        '${'File'.padRight(40)} | '
        '${'Line'.padLeft(4)} | Rule');
    buf.writeln('  ${'-' * 8}-+-${'-' * 11}-+-'
        '${'-' * 40}-+-${'-' * 4}-+-${'-' * 20}');

    for (var i = 0; i < showing; i++) {
      final e = all[i];
      buf.writeln('  ${e.priority.toStringAsFixed(0).padLeft(8)} | '
          '${e.impact.name.padRight(11)} | '
          '${_relativePath(e.v.file).padRight(40)} | '
          '${e.v.line.toString().padLeft(4)} | '
          '${e.v.rule}');
    }

    final omitted = all.length - showing;
    if (omitted > 0) {
      buf.writeln('  ... $omitted more violations omitted');
    }
    buf.writeln();
  }

  /// Write the full import dependency tree from entry points.
  static void _writeProjectStructure(StringBuffer buf) {
    final files = ImportGraphTracker.allFiles;
    if (files.isEmpty) return;

    buf.writeln('${'=' * 70}');
    buf.writeln('PROJECT STRUCTURE '
        '(${files.length} files, ${ImportGraphTracker.totalEdges} edges)');
    buf.writeln('${'=' * 70}');
    buf.writeln();

    // Find entry points: files with no importers and at least one import
    final roots = <String>[];
    final standalone = <String>[];
    for (final file in files) {
      final fanIn = ImportGraphTracker.importersOf(file).length;
      final fanOut = ImportGraphTracker.importsOf(file).length;
      if (fanIn == 0) {
        if (fanOut > 0) {
          roots.add(file);
        } else {
          standalone.add(file);
        }
      }
    }
    roots.sort();

    // DFS tree walk from each root
    final visited = <String>{};
    for (final root in roots) {
      _writeTreeNode(buf, root, '', true, visited);
    }

    // Standalone files
    if (standalone.isNotEmpty) {
      standalone.sort();
      buf.writeln();
      buf.writeln('Standalone (no inbound imports):');
      for (final file in standalone) {
        final layer = ImportGraphTracker.getLayer(file);
        buf.writeln('  ${_relativePath(file)} [$layer]');
      }
    }
    buf.writeln();
  }

  /// Recursively write a tree node and its children.
  static void _writeTreeNode(
    StringBuffer buf,
    String file,
    String prefix,
    bool isLast,
    Set<String> visited,
  ) {
    final connector = prefix.isEmpty ? '' : (isLast ? '└── ' : '├── ');
    final layer = ImportGraphTracker.getLayer(file);
    final fanIn = ImportGraphTracker.importersOf(file).length;
    final fanOut = ImportGraphTracker.importsOf(file).length;
    final label = '${_relativePath(file)} '
        '[$layer] (fan-in: $fanIn, fan-out: $fanOut)';

    if (!visited.add(file)) {
      buf.writeln('$prefix$connector$label [shown above]');
      return;
    }

    buf.writeln('$prefix$connector$label');

    final children = ImportGraphTracker.importsOf(file).toList()..sort();
    // Only show children that are in our project graph
    final projectChildren =
        children.where((c) => ImportGraphTracker.allFiles.contains(c)).toList();

    final childPrefix =
        prefix + (prefix.isEmpty ? '' : (isLast ? '    ' : '│   '));
    for (var i = 0; i < projectChildren.length; i++) {
      _writeTreeNode(
        buf,
        projectChildren[i],
        childPrefix,
        i == projectChildren.length - 1,
        visited,
      );
    }
  }

  /// Convert an absolute path to a relative path from project root.
  ///
  /// Normalizes separators to `/` before comparing so that Windows
  /// paths (which may mix `\` and `/`) are handled correctly.
  static String _relativePath(String filePath) {
    if (_projectRoot == null) return filePath;
    final root = _projectRoot!.replaceAll('\\', '/');
    final file = filePath.replaceAll('\\', '/');
    if (file.startsWith('$root/')) {
      return file.substring(root.length + 1);
    }
    return filePath;
  }

  /// Move old report files to `.trash/`, keeping only the
  /// [_maxReportFiles] most recent in the reports directory.
  /// Trashed files can still be viewed but are excluded from the
  /// active reports listing.
  static void _cleanOldReports() {
    if (_projectRoot == null) return;

    try {
      final sep = Platform.pathSeparator;
      final reportsDir = Directory('$_projectRoot${sep}reports');
      if (!reportsDir.existsSync()) return;

      final reportFiles = reportsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_saropa_lint_report.log'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (reportFiles.length <= _maxReportFiles) return;

      final trashDir = Directory('$_projectRoot${sep}reports$sep.trash');
      if (!trashDir.existsSync()) {
        trashDir.createSync(recursive: true);
      }

      for (final old in reportFiles.skip(_maxReportFiles)) {
        final name = old.path.split(sep).last;
        old.renameSync('${trashDir.path}$sep$name');
      }
    } catch (_) {
      // Cleanup failure is non-critical — silently ignore.
    }
  }

  /// Reset state for a fresh analysis session.
  ///
  /// Call this before starting a new analysis run (e.g. from `init`)
  /// to clear accumulated data and generate a new report file.
  static void reset() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _projectRoot = null;
    _sessionId = null;
    _isolateId = null;
    _pathsLogged = false;
    _reportWritten = false;
    _config = null;
    ImportGraphTracker.reset();
  }
}
