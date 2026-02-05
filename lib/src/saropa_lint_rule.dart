// ignore_for_file: always_specify_types, depend_on_referenced_packages, unused_element

import 'dart:developer' as developer;
import 'dart:io' show Directory, File, Platform, stderr, stdout;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'baseline/baseline_manager.dart';
import 'ignore_fixes.dart';
import 'ignore_utils.dart';
import 'report/analysis_reporter.dart';
import 'owasp/owasp.dart';
import 'project_context.dart';
import 'tiers.dart' show essentialRules;

// Re-export types needed by rule implementations
export 'ignore_fixes.dart'
    show AddIgnoreCommentFix, AddIgnoreForFileFix, WrapInTryCatchFix;
export 'owasp/owasp.dart' show OwaspMapping, OwaspMobile, OwaspWeb;
export 'project_context.dart'
    show
        AstNodeCategory,
        AstNodeTypeRegistry,
        BaselineAwareEarlyExit,
        BatchableRuleInfo,
        BloomFilter,
        CachedSymbolInfo,
        GitAwarePriority,
        CompilationUnitCache,
        CompilationUnitDerivedData,
        ConsolidatedVisitorDispatch,
        ContentFingerprint,
        ContentRegionIndex,
        ContentRegions,
        DiffBasedAnalysis,
        FileContentCache,
        FileMetrics,
        FileMetricsCache,
        FileType,
        HotPathProfiler,
        ImportGraphCache,
        ImportNode,
        IncrementalAnalysisTracker,
        initializeCacheManagement,
        LazyPattern,
        LazyPatternCache,
        LineRange,
        LruCache,
        MemoryPressureHandler,
        NodeVisitCallback,
        ParallelAnalysisResult,
        ParallelAnalyzer,
        PatternIndex,
        ProfilingEntry,
        RuleBatchExecutor,
        RuleCost,
        RuleDependencyGraph,
        RuleExecutionStats,
        RuleGroup,
        RuleGroupExecutor,
        RulePatternInfo,
        RulePriorityInfo,
        RulePriorityQueue,
        SemanticTokenCache,
        SmartContentFilter,
        SourceLocation,
        SourceLocationCache,
        SpeculativeAnalysis,
        StringInterner,
        SymbolKind,
        ThrottledAnalysis,
        ViolationBatch;

// =============================================================================
// RULE TIMING INSTRUMENTATION (Performance Profiling)
// =============================================================================
//
// Tracks execution time of each rule to identify slow rules that impact
// analysis performance. Rules taking >10ms are logged for investigation.
//
// Enable timing by setting the environment variable:
//   SAROPA_LINTS_PROFILE=true dart run custom_lint
//
// Timing data helps identify:
// 1. Rules that need optimization
// 2. Rules that should be moved to higher tiers
// 3. Patterns that cause slow analysis
// =============================================================================

/// Controls whether rule timing is enabled.
///
/// Set via environment variable: SAROPA_LINTS_PROFILE=true
final bool _profilingEnabled =
    const bool.fromEnvironment('SAROPA_LINTS_PROFILE') ||
        const String.fromEnvironment('SAROPA_LINTS_PROFILE') == 'true';

/// Threshold in milliseconds for logging slow rules.
const int _slowRuleThresholdMs = 10;

/// Threshold in milliseconds for deferring rules (when defer mode is enabled).
const int _deferThresholdMs = 50;

/// Controls whether slow rule deferral is enabled.
///
/// When enabled, rules that historically take >50ms are skipped in the first
/// pass. Run with SAROPA_LINTS_DEFERRED=true to run only the deferred rules.
///
/// Set via environment variable: SAROPA_LINTS_DEFER=true
final bool _deferSlowRules = const bool.fromEnvironment('SAROPA_LINTS_DEFER') ||
    const String.fromEnvironment('SAROPA_LINTS_DEFER') == 'true';

/// Controls whether to run ONLY deferred (slow) rules.
///
/// Set via environment variable: SAROPA_LINTS_DEFERRED=true
final bool _runDeferredOnly =
    const bool.fromEnvironment('SAROPA_LINTS_DEFERRED') ||
        const String.fromEnvironment('SAROPA_LINTS_DEFERRED') == 'true';

/// Controls whether progress reporting is enabled (default: true).
///
/// Disable via environment variable: SAROPA_LINTS_PROGRESS=false
final bool _progressEnabled =
    const bool.fromEnvironment('SAROPA_LINTS_PROGRESS', defaultValue: true) &&
        const String.fromEnvironment('SAROPA_LINTS_PROGRESS',
                defaultValue: 'true') !=
            'false';

// =============================================================================
// TERMINAL COLOR SUPPORT
// =============================================================================

/// Detects if the terminal supports ANSI colors.
bool get _supportsColor {
  if (Platform.environment.containsKey('NO_COLOR')) return false;
  if (Platform.environment.containsKey('FORCE_COLOR')) return true;
  if (!stderr.hasTerminal) return false;

  if (Platform.isWindows) {
    final term = Platform.environment['TERM'];
    final wtSession = Platform.environment['WT_SESSION'];
    final conEmu = Platform.environment['ConEmuANSI'];
    return wtSession != null || conEmu == 'ON' || term == 'xterm';
  }
  return true;
}

/// ANSI color codes for progress display.
class _ProgressColors {
  static String get reset => _supportsColor ? '\x1B[0m' : '';
  static String get bold => _supportsColor ? '\x1B[1m' : '';
  static String get dim => _supportsColor ? '\x1B[2m' : '';
  static String get red => _supportsColor ? '\x1B[31m' : '';
  static String get green => _supportsColor ? '\x1B[32m' : '';
  static String get yellow => _supportsColor ? '\x1B[33m' : '';
  static String get blue => _supportsColor ? '\x1B[34m' : '';
  static String get cyan => _supportsColor ? '\x1B[36m' : '';
  static String get brightGreen => _supportsColor ? '\x1B[92m' : '';

  /// Clear line: use cursor-to-start + spaces approach for broader compatibility.
  static String get clearLine => '\r${' ' * 80}\r';
}

// =============================================================================
// PROGRESS TRACKING (User Feedback)
// =============================================================================
//
// Tracks analysis progress to show the user that the linter is working.
// Uses in-place updates with a visual progress bar (no scrolling).
// Enabled by default. Disable via environment variable:
//   dart run custom_lint --define=SAROPA_LINTS_PROGRESS=false
//
// Progress output helps users see:
// 1. That the linter is actively working (not frozen)
// 2. How many files have been analyzed
// 3. Approximate progress through the codebase
// =============================================================================

/// Tracks and reports analysis progress across files.
///
/// Enabled by default. Disable via: SAROPA_LINTS_PROGRESS=false
class ProgressTracker {
  ProgressTracker._();

  static final Set<String> _seenFiles = {};
  static DateTime? _startTime;
  static DateTime? _lastProgressTime;
  static int _lastReportedCount = 0;
  static String? _currentFile;
  static DateTime? _currentFileStart;
  static int _totalExpectedFiles = 0;
  static int _violationsFound = 0;
  static int _filesWithIssues = 0;
  static String? _lastFileWithIssue;
  static bool _etaCalibrated = false;
  static bool _discoveredFromFiles =
      false; // True only if discoverFiles() found files

  // Severity tracking
  static int _errorCount = 0;
  static int _warningCount = 0;
  static int _infoCount = 0;

  // Per-file and per-rule tracking for summary
  static final Map<String, int> _issuesByFile = {};
  static final Map<String, int> _issuesByRule = {};
  static final Map<String, String> _ruleSeverities = {}; // rule -> severity

  // Rolling rate samples for more stable ETA (last N samples)
  static final List<double> _rateSamples = [];
  static const int _maxRateSamples = 5;

  // Track slow files (> 2 seconds) for summary
  static final Map<String, int> _slowFiles = {}; // file -> seconds

  // Issue limit tracking
  static int _maxIssues = 1000; // Default limit (0 = unlimited)
  static bool _limitReached = false;
  static int _issuesAfterLimit = 0; // Count of issues we stopped tracking

  // Total enabled rules (set from plugin entry point)
  static int _totalEnabledRules = 0;

  /// Set the total number of enabled rules for progress display.
  static void setEnabledRuleCount(int count) {
    _totalEnabledRules = count;
  }

  /// Set the maximum number of issues to report.
  ///
  /// Configure in `analysis_options_custom.yaml`:
  /// ```yaml
  /// max_issues: 500  # Stop after 500 issues (default: 1000, 0 = unlimited)
  /// ```
  ///
  /// Once the limit is reached, non-ERROR rules stop running entirely.
  /// ERROR-severity rules always run to catch critical issues.
  static void setMaxIssues(int limit) {
    _maxIssues = limit;
  }

  /// Returns true if issue limit has been reached.
  static bool get isLimitReached => _limitReached;

  /// Interval between progress reports (in files or time).
  static const int _fileInterval = 10; // More frequent updates
  static const Duration _timeInterval = Duration(seconds: 5);

  /// Set expected total file count (if known) for % calculation.
  static void setExpectedFileCount(int count) {
    _totalExpectedFiles = count;
    _etaCalibrated = true;
  }

  /// Auto-discover dart files in a directory for ETA estimation.
  /// Call this early to enable % progress. Returns estimated count.
  static int discoverFiles(String projectPath) {
    try {
      final dir = Directory(projectPath);
      if (!dir.existsSync()) return 0;

      int count = 0;
      // Quick recursive count of .dart files (excluding build, .dart_tool)
      for (final entity in dir.listSync(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final path = entity.path;
          if (!path.contains('.dart_tool') &&
              !path.contains('build${Platform.pathSeparator}') &&
              !path.contains('.pub-cache')) {
            count++;
          }
        }
      }
      // Only mark calibrated if we found a meaningful number of files
      // (avoids false ETA when discovery fails or wrong directory)
      if (count >= 10) {
        _totalExpectedFiles = count;
        _etaCalibrated = true;
        _discoveredFromFiles = true;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Record a violation found for the current file.
  /// [severity] should be 'ERROR', 'WARNING', or 'INFO'
  /// [ruleName] is the lint rule that triggered
  ///
  /// ERROR severity issues are ALWAYS fully tracked (no limit).
  /// The limit only applies to WARNING/INFO to ensure critical issues
  /// are never lost in favor of formatting nits.
  static void recordViolation({String? severity, String? ruleName}) {
    _violationsFound++;
    final severityUpper = severity?.toUpperCase();
    final isError = severityUpper == 'ERROR';

    // Track by severity (always counted, regardless of limit)
    switch (severityUpper) {
      case 'ERROR':
        _errorCount++;
      case 'WARNING':
        _warningCount++;
      case 'INFO':
        _infoCount++;
    }

    // ERROR severity ALWAYS gets full tracking - critical issues never skipped
    // Limit only applies to WARNING/INFO (formatting, style, etc.)
    final nonErrorCount = _warningCount + _infoCount;
    if (!isError && _maxIssues > 0 && nonErrorCount > _maxIssues) {
      if (!_limitReached) {
        _limitReached = true;
      }
      _issuesAfterLimit++;
      return; // Skip detailed tracking for non-critical issues after limit
    }

    // Track by file
    if (_currentFile != null) {
      _issuesByFile[_currentFile!] = (_issuesByFile[_currentFile!] ?? 0) + 1;
      if (_currentFile != _lastFileWithIssue) {
        _filesWithIssues++;
        _lastFileWithIssue = _currentFile;
      }
    }

    // Track by rule
    if (ruleName != null) {
      _issuesByRule[ruleName] = (_issuesByRule[ruleName] ?? 0) + 1;
      if (severityUpper != null) {
        _ruleSeverities[ruleName] = severityUpper;
      }
    }
  }

  /// Record that a file is being analyzed and potentially report progress.
  static void recordFile(String path) {
    if (!_progressEnabled) return;

    // Initialize start time on first file
    _startTime ??= DateTime.now();
    _lastProgressTime ??= _startTime;

    // On first file, discover project files for progress %
    if (!_discoveredFromFiles && _seenFiles.isEmpty) {
      final projectRoot = ProjectContext.findProjectRoot(path);
      if (projectRoot != null) {
        discoverFiles(projectRoot);
      }
    }

    final now = DateTime.now();

    // Check if this is a new file or we're still on the same file
    final wasNew = _seenFiles.add(path);

    if (wasNew) {
      // Track long-running files (> 2 seconds) for summary report
      if (_currentFile != null && _currentFileStart != null) {
        final fileTime = now.difference(_currentFileStart!);
        if (fileTime.inSeconds >= 2) {
          _slowFiles[_currentFile!] = fileTime.inSeconds;
        }
      }

      _currentFile = path;
      _currentFileStart = now;

      // Recalibrate ETA after seeing some files
      // If we're seeing more files than expected, adjust upward
      if (_etaCalibrated && _seenFiles.length > _totalExpectedFiles * 0.9) {
        // Increase estimate by 20% if we're approaching the limit
        _totalExpectedFiles = (_seenFiles.length * 1.2).round();
      }
    }

    final fileCount = _seenFiles.length;

    // Report progress at intervals (every N files or every N seconds)
    final timeSinceLastReport = now.difference(_lastProgressTime!);
    final filesSinceLastReport = fileCount - _lastReportedCount;

    if (filesSinceLastReport >= _fileInterval ||
        timeSinceLastReport >= _timeInterval) {
      _reportProgress(fileCount, now);
      _lastProgressTime = now;
      _lastReportedCount = fileCount;
    }
  }

  /// Calculate files per second using rolling average for stability.
  static double _calculateFilesPerSec(int fileCount, Duration elapsed) {
    final instantRate = elapsed.inMilliseconds > 0
        ? (fileCount * 1000) / elapsed.inMilliseconds
        : 0.0;

    // Add to rolling samples
    _rateSamples.add(instantRate);
    if (_rateSamples.length > _maxRateSamples) {
      _rateSamples.removeAt(0);
    }

    // Return rolling average for smoother ETA
    if (_rateSamples.isEmpty) return instantRate;
    return _rateSamples.reduce((a, b) => a + b) / _rateSamples.length;
  }

  /// Format duration as human-readable string.
  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return '${hours}h ${mins}m';
  }

  static void _reportProgress(int fileCount, DateTime now) {
    final elapsed = now.difference(_startTime!);
    final filesPerSec = _calculateFilesPerSec(fileCount, elapsed);

    // Extract just the filename from the last seen file for context
    final lastFile = _seenFiles.last;
    final displayName = lastFile.split('/').last.split('\\').last;

    // Aliases for cleaner code
    final reset = _ProgressColors.reset;
    final bold = _ProgressColors.bold;
    final dim = _ProgressColors.dim;
    final red = _ProgressColors.red;
    final green = _ProgressColors.green;
    final yellow = _ProgressColors.yellow;
    final cyan = _ProgressColors.cyan;
    final brightGreen = _ProgressColors.brightGreen;
    final clearLine = _ProgressColors.clearLine;

    if (_discoveredFromFiles && _totalExpectedFiles > 0) {
      final percent =
          (fileCount * 100 / _totalExpectedFiles).clamp(0, 100).round();
      final remaining =
          (_totalExpectedFiles - fileCount).clamp(0, _totalExpectedFiles);
      final etaSeconds =
          filesPerSec > 0 ? (remaining / filesPerSec).round() : 0;

      // Visual progress bar (20 chars wide)
      const barWidth = 20;
      final filled = (percent * barWidth / 100).round();
      final empty = barWidth - filled;
      final bar = '$brightGreen${'█' * filled}$dim${'░' * empty}$reset';

      // Color-code issues count (show limit indicator if reached)
      final issuesColor = _violationsFound == 0
          ? green
          : _errorCount > 0
              ? red
              : yellow;
      final issuesDisplay =
          _limitReached ? '$_maxIssues+' : '$_violationsFound';
      final issuesStr = '$issuesColor$issuesDisplay$reset';

      // Build compact status line with clear labels
      final status = StringBuffer()
        ..write(clearLine)
        ..write('$bar $bold$percent%$reset ')
        ..write('$dim│$reset ')
        ..write(
            '${dim}Files:$reset $cyan$fileCount$reset/$dim$_totalExpectedFiles$reset ')
        ..write('$dim│$reset ')
        ..write('${dim}Issues:$reset $issuesStr ')
        ..write('$dim│$reset ')
        ..write('${dim}ETA:$reset $yellow${_formatDuration(etaSeconds)}$reset ')
        ..write('$dim│$reset ')
        ..write('$dim$displayName$reset');

      // Write in-place (no newline) - use stdout for better terminal compat
      stdout.write(status.toString());
      stdout.flush();
    } else {
      // No file count known - simpler output with labels
      final status = StringBuffer()
        ..write(clearLine)
        ..write('$cyan⠿$reset ')
        ..write('${dim}Files:$reset $bold$fileCount$reset ')
        ..write('$dim│$reset ')
        ..write('${dim}Time:$reset ${_formatDuration(elapsed.inSeconds)} ')
        ..write('$dim│$reset ')
        ..write('${dim}Rate:$reset ${filesPerSec.round()}/s ')
        ..write('$dim│$reset ')
        ..write('${dim}Issues:$reset $_violationsFound ')
        ..write('$dim│$reset ')
        ..write('$dim$displayName$reset');

      stdout.write(status.toString());
      stdout.flush();
    }
  }

  /// Report final summary when analysis completes.
  static void reportSummary() {
    if (!_progressEnabled || _startTime == null) return;

    final elapsed = DateTime.now().difference(_startTime!);
    final fileCount = _seenFiles.length;
    final filesPerSec = _calculateFilesPerSec(fileCount, elapsed);

    // Color aliases
    final reset = _ProgressColors.reset;
    final bold = _ProgressColors.bold;
    final dim = _ProgressColors.dim;
    final red = _ProgressColors.red;
    final green = _ProgressColors.green;
    final yellow = _ProgressColors.yellow;
    final cyan = _ProgressColors.cyan;
    final clearLine = _ProgressColors.clearLine;

    final buf = StringBuffer();

    // Clear progress line and add header
    buf.write(clearLine);
    buf.writeln();
    buf.writeln('$cyan${'═' * 70}$reset');
    buf.writeln('$bold  ✓ SAROPA LINTS ANALYSIS COMPLETE$reset');
    buf.writeln('$cyan${'═' * 70}$reset');

    // Overview with color
    buf.writeln();
    final rulesStr =
        _totalEnabledRules > 0 ? ' with $_totalEnabledRules rules' : '';
    buf.writeln(
        '  $dim📁$reset Files: $bold$fileCount$reset analyzed$rulesStr in $cyan${_formatDuration(elapsed.inSeconds)}$reset (${filesPerSec.round()}/s)');

    final issuePercent =
        fileCount > 0 ? (_filesWithIssues * 100 / fileCount).round() : 0;
    final issueColor = _filesWithIssues == 0 ? green : yellow;
    buf.writeln(
        '  $dim📄$reset Files with issues: $issueColor$_filesWithIssues$reset ($issuePercent%)');

    // Warning if issue limit was reached (only applies to warnings/info, not errors)
    if (_limitReached) {
      buf.writeln();
      buf.writeln(
          '$yellow  ⚠️  Limit reached: $_maxIssues warnings/info. Skipping remaining non-error rules.$reset');
      buf.writeln(
          '$dim     All $_errorCount errors fully checked. $_issuesAfterLimit warning/info rules skipped.$reset');
      buf.writeln(
          '$dim     To adjust: echo "max_issues: 2000" > analysis_options_custom.yaml$reset');
    }

    // Severity breakdown (only if there are issues)
    if (_violationsFound > 0) {
      buf.writeln();
      buf.writeln('$dim${'─' * 70}$reset');
      buf.writeln('  $bold ISSUES BY SEVERITY$reset');
      buf.writeln('$dim${'─' * 70}$reset');
      if (_errorCount > 0) {
        buf.writeln('    $red●$reset Errors:   $bold$_errorCount$reset');
      }
      if (_warningCount > 0) {
        buf.writeln('    $yellow●$reset Warnings: $bold$_warningCount$reset');
      }
      if (_infoCount > 0) {
        buf.writeln('    $cyan●$reset Info:     $bold$_infoCount$reset');
      }
      buf.writeln('    $dim──$reset Total:    $bold$_violationsFound$reset');
    } else {
      buf.writeln();
      buf.writeln('  $green✓ No issues found!$reset');
    }

    // Top offending files (max 5 to keep summary compact)
    if (_issuesByFile.isNotEmpty) {
      final sortedFiles = _issuesByFile.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topFiles = sortedFiles.take(5);

      buf.writeln();
      buf.writeln('$dim${'─' * 70}$reset');
      buf.writeln('  $bold TOP FILES WITH ISSUES$reset');
      buf.writeln('$dim${'─' * 70}$reset');
      for (final entry in topFiles) {
        final shortName = entry.key.split('/').last.split('\\').last;
        buf.writeln(
            '    $yellow${entry.value.toString().padLeft(3)}$reset issues  $dim$shortName$reset');
      }
    }

    // Top triggered rules (max 5 to keep summary compact)
    if (_issuesByRule.isNotEmpty) {
      final sortedRules = _issuesByRule.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topRules = sortedRules.take(5);

      buf.writeln();
      buf.writeln('$dim${'─' * 70}$reset');
      buf.writeln('  $bold TOP TRIGGERED RULES$reset');
      buf.writeln('$dim${'─' * 70}$reset');
      for (final entry in topRules) {
        final severity = _ruleSeverities[entry.key] ?? '?';
        final severityColor = severity == 'ERROR'
            ? red
            : severity == 'WARNING'
                ? yellow
                : cyan;
        buf.writeln(
            '    $severityColor●$reset ${entry.value.toString().padLeft(3)}x  $dim${entry.key}$reset');
      }
    }

    // Slow files (if any took > 2 seconds)
    if (_slowFiles.isNotEmpty) {
      final sortedSlow = _slowFiles.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topSlow = sortedSlow.take(5);

      buf.writeln();
      buf.writeln('$dim${'─' * 70}$reset');
      buf.writeln(
          '  $bold ⏱️  SLOW FILES$reset $dim(>${_slowFiles.length} files took >2s)$reset');
      buf.writeln('$dim${'─' * 70}$reset');
      for (final entry in topSlow) {
        final shortName = entry.key.split('/').last.split('\\').last;
        buf.writeln('    $yellow${entry.value}s$reset  $dim$shortName$reset');
      }
    }

    buf.writeln();
    buf.writeln('$cyan${'═' * 70}$reset');

    stderr.writeln(buf.toString());

    // Write log file
    _writeLogFile(buf.toString(), elapsed);
  }

  /// Write detailed log to reports directory.
  static void _writeLogFile(String summary, Duration elapsed) {
    try {
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      final reportsDir = Directory('reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }

      final logPath = 'reports/${timestamp}_saropa_lints_analysis.log';
      final logBuf = StringBuffer();

      logBuf.writeln('Saropa Lints Analysis Report');
      logBuf.writeln('Generated: ${now.toIso8601String()}');
      logBuf.writeln('Duration: ${_formatDuration(elapsed.inSeconds)}');
      logBuf.writeln();

      // Summary (stripped of emojis for plain text)
      logBuf.writeln(summary.replaceAll(RegExp(r'[^\x00-\x7F]'), ''));

      // Full file breakdown
      if (_issuesByFile.isNotEmpty) {
        logBuf.writeln();
        logBuf.writeln('=' * 70);
        logBuf.writeln('ALL FILES WITH ISSUES (${_issuesByFile.length} files)');
        logBuf.writeln('=' * 70);
        final sortedFiles = _issuesByFile.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedFiles) {
          logBuf.writeln(
              '  ${entry.value.toString().padLeft(4)} issues  ${entry.key}');
        }
      }

      // Full rule breakdown
      if (_issuesByRule.isNotEmpty) {
        logBuf.writeln();
        logBuf.writeln('=' * 70);
        logBuf.writeln('ALL TRIGGERED RULES (${_issuesByRule.length} rules)');
        logBuf.writeln('=' * 70);
        final sortedRules = _issuesByRule.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedRules) {
          final severity = _ruleSeverities[entry.key] ?? '?';
          logBuf.writeln(
              '  [$severity] ${entry.value.toString().padLeft(4)}x  ${entry.key}');
        }
      }

      File(logPath).writeAsStringSync(logBuf.toString());
      stderr.writeln('📝 Log written to: $logPath');
    } catch (e) {
      stderr.writeln('⚠️  Could not write log file: $e');
    }
  }

  /// Get a snapshot of all tracking data for report generation.
  static ProgressTrackerData get reportData => ProgressTrackerData(
        filesAnalyzed: _seenFiles.length,
        filesWithIssues: _filesWithIssues,
        violationsFound: _violationsFound,
        errorCount: _errorCount,
        warningCount: _warningCount,
        infoCount: _infoCount,
        issuesByFile: Map<String, int>.unmodifiable(_issuesByFile),
        issuesByRule: Map<String, int>.unmodifiable(_issuesByRule),
        ruleSeverities: Map<String, String>.unmodifiable(_ruleSeverities),
      );

  /// Reset tracking state (useful between analysis runs).
  static void reset() {
    _seenFiles.clear();
    _startTime = null;
    _lastProgressTime = null;
    _lastReportedCount = 0;
    _totalExpectedFiles = 0;
    _totalEnabledRules = 0;
    _etaCalibrated = false;
    _discoveredFromFiles = false;
    _violationsFound = 0;
    _filesWithIssues = 0;
    _lastFileWithIssue = null;
    _errorCount = 0;
    _warningCount = 0;
    _infoCount = 0;
    _issuesByFile.clear();
    _issuesByRule.clear();
    _ruleSeverities.clear();
    _rateSamples.clear();
    _slowFiles.clear();
    _limitReached = false;
    _issuesAfterLimit = 0;
    // Note: _maxIssues is not reset - it's config, not state
  }
}

/// Immutable snapshot of [ProgressTracker] data for report generation.
class ProgressTrackerData {
  const ProgressTrackerData({
    required this.filesAnalyzed,
    required this.filesWithIssues,
    required this.violationsFound,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.issuesByFile,
    required this.issuesByRule,
    required this.ruleSeverities,
  });

  final int filesAnalyzed;
  final int filesWithIssues;
  final int violationsFound;
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final Map<String, int> issuesByFile;
  final Map<String, int> issuesByRule;
  final Map<String, String> ruleSeverities;
}

/// Tracks cumulative timing for each rule across all files.
class RuleTimingTracker {
  RuleTimingTracker._();

  static final Map<String, Duration> _totalTime = {};
  static final Map<String, int> _callCount = {};

  /// Rules that have exceeded the deferral threshold (50ms) at least once.
  static final Set<String> _slowRules = {};

  /// Count of slow executions per rule (executions > 50ms).
  static final Map<String, int> _slowExecutionCount = {};

  /// Check if a rule should be deferred based on historical performance.
  ///
  /// Returns true if:
  /// - Deferral mode is enabled (SAROPA_LINTS_DEFER=true)
  /// - This rule has exceeded the deferral threshold before
  /// - We're NOT in deferred-only mode
  static bool shouldDefer(String ruleName) {
    if (!_deferSlowRules) return false;
    if (_runDeferredOnly) return false; // We want to run slow rules now
    return _slowRules.contains(ruleName);
  }

  /// Check if a rule should run because we're in deferred-only mode.
  ///
  /// Returns true if:
  /// - Deferred-only mode is enabled (SAROPA_LINTS_DEFERRED=true)
  /// - This rule is NOT marked as slow (should have run in first pass)
  static bool shouldSkipInDeferredMode(String ruleName) {
    if (!_runDeferredOnly) return false;
    return !_slowRules.contains(ruleName);
  }

  /// Get the list of slow rules for reporting.
  static Set<String> get slowRules => Set.unmodifiable(_slowRules);

  /// Record a rule execution time.
  static void record(String ruleName, Duration elapsed) {
    _totalTime[ruleName] = (_totalTime[ruleName] ?? Duration.zero) + elapsed;
    _callCount[ruleName] = (_callCount[ruleName] ?? 0) + 1;

    // Track rules that exceed the deferral threshold
    if (elapsed.inMilliseconds >= _deferThresholdMs) {
      _slowRules.add(ruleName);
      _slowExecutionCount[ruleName] = (_slowExecutionCount[ruleName] ?? 0) + 1;
    }

    // Log slow rules immediately for debugging
    if (elapsed.inMilliseconds >= _slowRuleThresholdMs) {
      developer.log(
        'SLOW RULE: $ruleName took ${elapsed.inMilliseconds}ms',
        name: 'saropa_lints',
      );
    }
  }

  /// Get all timing data sorted by total time (slowest first).
  static List<RuleTimingRecord> get sortedTimings {
    final entries = _totalTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) {
      final count = _callCount[e.key] ?? 1;
      return RuleTimingRecord(
        ruleName: e.key,
        totalTime: e.value,
        callCount: count,
        averageTime: Duration(microseconds: e.value.inMicroseconds ~/ count),
      );
    }).toList();
  }

  /// Get a summary of the slowest rules.
  static String get summary {
    final timings = sortedTimings.take(20).toList();
    if (timings.isEmpty) return 'No timing data collected.';

    final buffer = StringBuffer();
    buffer.writeln('\n=== SAROPA LINTS TIMING REPORT ===');
    buffer.writeln('Top 20 slowest rules (by total time):');
    buffer.writeln('');

    for (final timing in timings) {
      final isSlowMarker =
          _slowRules.contains(timing.ruleName) ? '[SLOW] ' : '';
      buffer.writeln(
        '  $isSlowMarker${timing.ruleName}: '
        '${timing.totalTime.inMilliseconds}ms total, '
        '${timing.callCount} calls, '
        '${timing.averageTime.inMicroseconds / 1000}ms avg',
      );
    }

    // Add slow rules summary for deferral
    if (_slowRules.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
          '=== RULES ELIGIBLE FOR DEFERRAL (>${_deferThresholdMs}ms) ===');
      buffer.writeln('Use SAROPA_LINTS_DEFER=true to defer these rules.');
      buffer.writeln('');
      for (final rule in _slowRules) {
        final count = _slowExecutionCount[rule] ?? 0;
        buffer.writeln('  $rule ($count slow executions)');
      }
    }

    return buffer.toString();
  }

  /// Reset all timing data.
  static void reset() {
    _totalTime.clear();
    _callCount.clear();
    _slowRules.clear();
    _slowExecutionCount.clear();
  }
}

/// A record of timing data for a single rule.
class RuleTimingRecord {
  const RuleTimingRecord({
    required this.ruleName,
    required this.totalTime,
    required this.callCount,
    required this.averageTime,
  });

  final String ruleName;
  final Duration totalTime;
  final int callCount;
  final Duration averageTime;
}

// =============================================================================
// REPORT WRITER (Detailed Logging to reports/ folder)
// =============================================================================
//
// Enable by setting the environment variable:
//   SAROPA_LINTS_REPORT=true dart run custom_lint
//
// Reports are written to: <project>/reports/saropa_lints/
// - timing_report.txt: Rule timing summary
// - slow_rules.txt: Rules that exceeded threshold
// - skipped_files.txt: Files excluded from analysis
// - impact_report.txt: Violations grouped by impact level
// =============================================================================

/// Controls whether report writing is enabled.
///
/// Set via environment variable: SAROPA_LINTS_REPORT=true
final bool _reportEnabled = const bool.fromEnvironment('SAROPA_LINTS_REPORT') ||
    const String.fromEnvironment('SAROPA_LINTS_REPORT') == 'true';

/// Writes detailed analysis reports to a reports/ folder.
class ReportWriter {
  ReportWriter._();

  static String? _reportsDir;
  static final List<String> _skippedFiles = [];
  static final List<String> _slowRuleLog = [];
  static DateTime? _analysisStartTime;
  static int _filesAnalyzed = 0;
  static int _rulesRun = 0;

  /// Initialize the report writer with the project root.
  static void initialize(String projectRoot) {
    if (!_reportEnabled) return;

    _reportsDir = '$projectRoot/reports/saropa_lints';
    _analysisStartTime = DateTime.now();

    // Create reports directory if it doesn't exist
    // Note: Directory creation happens on first write
  }

  /// Record a file that was skipped during analysis.
  static void recordSkippedFile(String path, String reason) {
    if (!_reportEnabled) return;
    _skippedFiles.add('$path - $reason');
  }

  /// Record a slow rule execution.
  static void recordSlowRule(String ruleName, String filePath, int ms) {
    if (!_reportEnabled) return;
    _slowRuleLog.add('$ruleName took ${ms}ms on $filePath');
  }

  /// Record that a file was analyzed.
  static void recordFileAnalyzed() {
    _filesAnalyzed++;
  }

  /// Record that a rule was run.
  static void recordRuleRun() {
    _rulesRun++;
  }

  /// Write all reports to the reports/ folder.
  ///
  /// Call this at the end of analysis (e.g., in a shutdown hook).
  static Future<void> writeReports() async {
    if (!_reportEnabled || _reportsDir == null) return;

    try {
      // Import dart:io for file operations
      // ignore: avoid_dynamic
      final io = await _getIoLibrary();
      if (io == null) return;

      // Create reports directory
      await _createDirectory(io, _reportsDir!);

      // Write timing report
      await _writeTimingReport(io);

      // Write slow rules report
      await _writeSlowRulesReport(io);

      // Write skipped files report
      await _writeSkippedFilesReport(io);

      // Write impact report
      await _writeImpactReport(io);

      // Write summary report
      await _writeSummaryReport(io);

      print('[saropa_lints] Reports written to: $_reportsDir');
    } catch (e) {
      print('[saropa_lints] Failed to write reports: $e');
    }
  }

  // ignore: avoid_dynamic
  static Future<dynamic> _getIoLibrary() async {
    try {
      // Dynamic import of dart:io
      // This allows the code to compile on web but gracefully fail
      return await Future.value(
          null); // Placeholder - actual impl needs dart:io
    } catch (_) {
      return null;
    }
  }

  // ignore: avoid_dynamic
  static Future<void> _createDirectory(dynamic io, String path) async {
    // Placeholder - actual implementation needs dart:io
  }

  // ignore: avoid_dynamic
  static Future<void> _writeTimingReport(dynamic io) async {
    final timings = RuleTimingTracker.sortedTimings;
    if (timings.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('SAROPA LINTS TIMING REPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('');
    buffer.writeln('All rules sorted by total execution time:');
    buffer.writeln('');

    for (final timing in timings) {
      final avgMs = timing.averageTime.inMicroseconds / 1000;
      buffer.writeln(
        '${timing.ruleName.padRight(50)} '
        '${timing.totalTime.inMilliseconds.toString().padLeft(6)}ms total  '
        '${timing.callCount.toString().padLeft(5)} calls  '
        '${avgMs.toStringAsFixed(2).padLeft(8)}ms avg',
      );
    }

    // Would write to file here with dart:io
    print(buffer.toString());
  }

  // ignore: avoid_dynamic
  static Future<void> _writeSlowRulesReport(dynamic io) async {
    if (_slowRuleLog.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('SAROPA LINTS SLOW RULES REPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Threshold: ${_slowRuleThresholdMs}ms');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('');

    for (final entry in _slowRuleLog) {
      buffer.writeln(entry);
    }

    print('[saropa_lints] Slow rules: ${_slowRuleLog.length} occurrences');
  }

  // ignore: avoid_dynamic
  static Future<void> _writeSkippedFilesReport(dynamic io) async {
    if (_skippedFiles.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('SAROPA LINTS SKIPPED FILES REPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('');

    for (final entry in _skippedFiles) {
      buffer.writeln(entry);
    }

    print('[saropa_lints] Skipped files: ${_skippedFiles.length}');
  }

  // ignore: avoid_dynamic
  static Future<void> _writeImpactReport(dynamic io) async {
    final buffer = StringBuffer();
    buffer.writeln('SAROPA LINTS IMPACT REPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('');
    buffer.writeln(ImpactTracker.detailedSummary);
    buffer.writeln('');

    // List critical violations
    final critical = ImpactTracker.violations[LintImpact.critical];
    if (critical != null && critical.isNotEmpty) {
      buffer.writeln('CRITICAL VIOLATIONS (fix immediately):');
      for (final v in critical) {
        buffer.writeln('  ${v.file}:${v.line} - ${v.rule}');
      }
    }

    print(buffer.toString());
  }

  // ignore: avoid_dynamic
  static Future<void> _writeSummaryReport(dynamic io) async {
    final elapsed = _analysisStartTime != null
        ? DateTime.now().difference(_analysisStartTime!)
        : Duration.zero;

    final buffer = StringBuffer();
    buffer.writeln('SAROPA LINTS ANALYSIS SUMMARY');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('='.padRight(60, '='));
    buffer.writeln('');
    buffer.writeln('Analysis Duration: ${elapsed.inSeconds}s');
    buffer.writeln('Files Analyzed: $_filesAnalyzed');
    buffer.writeln('Files Skipped: ${_skippedFiles.length}');
    buffer.writeln('Rule Executions: $_rulesRun');
    buffer.writeln('Slow Rule Occurrences: ${_slowRuleLog.length}');
    buffer.writeln('');
    buffer.writeln(ImpactTracker.summary);

    print(buffer.toString());
  }

  /// Reset all tracked data.
  static void reset() {
    _skippedFiles.clear();
    _slowRuleLog.clear();
    _analysisStartTime = null;
    _filesAnalyzed = 0;
    _rulesRun = 0;
  }
}

// =============================================================================
// AST Utilities
// =============================================================================

/// Extension on [InstanceCreationExpression] for common pattern checks.
extension InstanceCreationExpressionUtils on InstanceCreationExpression {
  /// Returns the simple type name of this constructor call.
  ///
  /// Example: `MyWidget()` → `'MyWidget'`
  /// Example: `MyWidget.named()` → `'MyWidget'`
  String get typeName => constructorName.type.name.lexeme;

  /// Checks if this constructor has a named parameter with the given [name].
  ///
  /// Example:
  /// ```dart
  /// // Given: TextField(controller: _ctrl, keyboardType: TextInputType.text)
  /// node.hasNamedParameter('keyboardType')  // true
  /// node.hasNamedParameter('obscureText')   // false
  /// ```
  bool hasNamedParameter(String name) {
    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return true;
      }
    }
    return false;
  }

  /// Checks if this constructor has any of the given named parameters.
  ///
  /// Example:
  /// ```dart
  /// node.hasAnyNamedParameter({'keyboardType', 'inputType'})
  /// ```
  bool hasAnyNamedParameter(Set<String> names) {
    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && names.contains(arg.name.label.name)) {
        return true;
      }
    }
    return false;
  }

  /// Gets the value of a named parameter if it exists.
  ///
  /// Returns the [Expression] for the parameter value, or null if not found.
  Expression? getNamedParameterValue(String name) {
    for (final Expression arg in argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg.expression;
      }
    }
    return null;
  }
}

/// Impact classification for lint rules.
///
/// Helps teams understand the practical severity of violations:
/// - [critical]: Each occurrence is a serious bug. Even 1-2 is unacceptable.
/// - [high]: Significant issues. 10+ should trigger immediate action.
/// - [medium]: Quality issues. 100+ suggests technical debt.
/// - [low]: Style/consistency. Large numbers are acceptable in legacy code.
enum LintImpact {
  /// Each occurrence is independently harmful. Memory leaks, security holes,
  /// crashes. Even 1-2 in production code is unacceptable.
  ///
  /// Examples: undisposed controllers, hardcoded credentials, null crashes
  critical,

  /// Significant issues that compound. A handful is manageable, but 10+
  /// indicates systemic problems requiring immediate attention.
  ///
  /// Examples: missing accessibility labels, performance anti-patterns
  high,

  /// Code quality issues. Individual instances are minor, but 100+ suggests
  /// accumulated technical debt worth addressing.
  ///
  /// Examples: missing error handling, complex conditionals, code duplication
  medium,

  /// Style and consistency issues. Large counts are normal in legacy codebases.
  /// Focus enforcement on new code; address existing violations opportunistically.
  ///
  /// Examples: naming conventions, hardcoded strings, missing documentation
  low,

  /// Opinionated guidance. Preferential patterns that improve consistency but
  /// are not inherently correctness or performance issues. Teams may opt-in or
  /// downgrade freely.
  opinionated,
}

/// The tier at which a rule is enabled by default.
///
/// This is the single source of truth for tier assignment. The init script
/// reads this from each rule to generate analysis_options.yaml.
///
/// Tiers are cumulative: higher tiers include all rules from lower tiers.
enum RuleTier {
  /// Critical rules preventing crashes, security holes, memory leaks.
  /// Must be enabled for all projects.
  essential,

  /// Essential + accessibility, performance patterns.
  /// Recommended for most teams.
  recommended,

  /// Recommended + architecture, testing, documentation.
  /// For enterprise/professional teams.
  professional,

  /// Professional + thorough coverage.
  /// For quality-obsessed teams.
  comprehensive,

  /// All rules enabled including pedantic/opinionated ones.
  /// For greenfield projects with strict standards.
  pedantic,

  /// Stylistic rules (formatting, ordering, naming).
  /// Opt-in only via --stylistic flag. Not included in any tier by default.
  stylistic,
}

/// Controls how a lint rule interacts with test files.
///
/// Most lint rules enforce production code patterns that are irrelevant
/// or counterproductive in test files. For example, hardcoded strings,
/// magic numbers, and missing documentation are expected in tests.
///
/// By default, rules skip test files entirely ([never]). Override
/// [SaropaLintRule.testRelevance] to change this behavior.
///
/// Migration from `skipTestFiles`:
/// - `skipTestFiles => true` is now the default ([never])
/// - `skipTestFiles => false` becomes [always]
/// - `applicableFileTypes => {FileType.test}` becomes [testOnly]
enum TestRelevance {
  /// Rule does NOT run on test files.
  ///
  /// This is the default. Use for production-focused rules:
  /// hardcoded config, magic numbers, security credentials,
  /// accessibility labels, documentation requirements, etc.
  never,

  /// Rule runs on ALL files including test files.
  ///
  /// Use for universal code quality rules that matter everywhere:
  /// empty catch blocks, unused imports, missing dispose,
  /// naming conventions, async safety, etc.
  always,

  /// Rule runs ONLY on test files.
  ///
  /// Use for test-specific rules: test structure, mock usage,
  /// assertion patterns, test naming, etc.
  testOnly,
}

/// Tracks lint violations by impact level for summary reporting.
///
/// Usage:
/// ```dart
/// // After running analysis:
/// print(ImpactTracker.summary);
/// // Output: "Critical: 3, High: 12, Medium: 156, Low: 892"
///
/// // Get detailed breakdown:
/// final violations = ImpactTracker.violations;
/// for (final v in violations[LintImpact.critical]!) {
///   print('${v.file}:${v.line} - ${v.rule}');
/// }
/// ```
class ImpactTracker {
  ImpactTracker._();

  static final Map<LintImpact, List<ViolationRecord>> _violations = {
    LintImpact.critical: [],
    LintImpact.high: [],
    LintImpact.medium: [],
    LintImpact.low: [],
    LintImpact.opinionated: [],
  };

  /// Record a violation.
  static void record({
    required LintImpact impact,
    required String rule,
    required String file,
    required int line,
    required String message,
  }) {
    _violations[impact]!.add(ViolationRecord(
      rule: rule,
      file: file,
      line: line,
      message: message,
    ));
  }

  /// Get all violations grouped by impact.
  static Map<LintImpact, List<ViolationRecord>> get violations =>
      Map.unmodifiable(_violations);

  /// Get count of violations by impact level.
  static Map<LintImpact, int> get counts => {
        LintImpact.critical: _violations[LintImpact.critical]!.length,
        LintImpact.high: _violations[LintImpact.high]!.length,
        LintImpact.medium: _violations[LintImpact.medium]!.length,
        LintImpact.low: _violations[LintImpact.low]!.length,
        LintImpact.opinionated: _violations[LintImpact.opinionated]!.length,
      };

  /// Get total violation count.
  static int get total =>
      _violations.values.fold(0, (sum, v) => sum + v.length);

  /// Returns true if there are any critical violations.
  static bool get hasCritical => _violations[LintImpact.critical]!.isNotEmpty;

  /// Get a summary string suitable for display.
  ///
  /// Format: "Critical: 3, High: 12, Medium: 156, Low: 892"
  static String get summary {
    final c = counts;
    return 'Critical: ${c[LintImpact.critical]}, '
        'High: ${c[LintImpact.high]}, '
        'Medium: ${c[LintImpact.medium]}, '
        'Low: ${c[LintImpact.low]}, '
        'Opinionated: ${c[LintImpact.opinionated]}';
  }

  /// Get a detailed summary with guidance.
  static String get detailedSummary {
    final c = counts;
    final buffer = StringBuffer();

    buffer.writeln('');
    buffer.writeln('Impact Summary');
    buffer.writeln('==============');

    if (c[LintImpact.critical]! > 0) {
      buffer.writeln('CRITICAL: ${c[LintImpact.critical]} (fix immediately!)');
    }
    if (c[LintImpact.high]! > 0) {
      buffer.writeln('HIGH:     ${c[LintImpact.high]} (address soon)');
    }
    if (c[LintImpact.medium]! > 0) {
      buffer.writeln('MEDIUM:   ${c[LintImpact.medium]} (tech debt)');
    }
    if (c[LintImpact.low]! > 0) {
      buffer.writeln('LOW:      ${c[LintImpact.low]} (style)');
    }
    if (c[LintImpact.opinionated]! > 0) {
      buffer.writeln(
          'OPINIONATED: ${c[LintImpact.opinionated]} (team preference)');
    }

    if (total == 0) {
      buffer.writeln('No issues found.');
    }

    return buffer.toString();
  }

  /// Get violations sorted by impact (critical first).
  static List<ViolationRecord> get sortedViolations {
    final result = <ViolationRecord>[];
    for (final impact in LintImpact.values) {
      result.addAll(_violations[impact]!);
    }
    return result;
  }

  /// Clear all tracked violations (useful between analysis runs).
  static void reset() {
    for (final list in _violations.values) {
      list.clear();
    }
  }
}

/// A recorded lint violation with location and metadata.
class ViolationRecord {
  const ViolationRecord({
    required this.rule,
    required this.file,
    required this.line,
    required this.message,
  });

  final String rule;
  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line - $rule: $message';
}

/// Base class for Saropa lint rules with enhanced features:
///
/// 1. **Hyphenated ignore comments**: Supports both `// ignore: no_empty_block`
///    and `// ignore: no-empty-block` formats.
///
/// 2. **Context-aware suppression**: Automatically skip generated files,
///    test files, or example files by overriding the skip* getters.
///
/// 3. **Documentation URLs**: Auto-generates documentation links for rules.
///
/// 4. **Severity overrides**: Supports project-level severity configuration.
///
/// Usage:
/// ```dart
/// class MyRule extends SaropaLintRule {
///   const MyRule() : super(code: _code);
///
///   static const LintCode _code = LintCode(
///     name: 'my_rule_name',
///     // ...
///   );
///
///   // Optional: skip generated files (default: true)
///   @override
///   bool get skipGeneratedCode => true;
///
///   @override
///   void runWithReporter(
///     CustomLintResolver resolver,
///     SaropaDiagnosticReporter reporter,
///     CustomLintContext context,
///   ) {
///     // Use reporter.atNode() as usual
///   }
/// }
/// ```
abstract class SaropaLintRule extends DartLintRule {
  const SaropaLintRule({required super.code});

  // ============================================================
  // Impact Classification
  // ============================================================

  /// The business impact of this rule's violations.
  ///
  /// Override to specify the impact level for your rule:
  /// - [LintImpact.critical]: Even 1-2 occurrences is serious (memory leaks, security)
  /// - [LintImpact.high]: 10+ requires immediate action (accessibility, performance)
  /// - [LintImpact.medium]: 100+ indicates tech debt (error handling, complexity)
  /// - [LintImpact.low]: Large counts acceptable (style, naming conventions)
  ///
  /// Default: [LintImpact.medium]
  LintImpact get impact => LintImpact.medium;

  // ============================================================
  // Config Key Aliases
  // ============================================================

  /// Alternate config keys that can be used to reference this rule.
  ///
  /// Override to provide aliases that users can use in `custom_lint.yaml`
  /// instead of the canonical rule name (`code.name`).
  ///
  /// This is useful when:
  /// - Rule name has a prefix like `enforce_` or `require_` that users omit
  /// - Rule was renamed but old config should still work
  /// - Common variations or abbreviations should be supported
  ///
  /// Example:
  /// ```dart
  /// @override
  /// List<String> get configAliases => const ['arguments_ordering'];
  /// ```
  ///
  /// Then both of these work in custom_lint.yaml:
  /// ```yaml
  /// rules:
  ///   prefer_arguments_ordering: false  # canonical name
  ///   arguments_ordering: false           # alias
  /// ```
  ///
  /// Default: empty list (no aliases)
  List<String> get configAliases => const <String>[];

  // ============================================================
  // Rule Cost Classification (Performance Optimization)
  // ============================================================

  /// The estimated execution cost of this rule.
  ///
  /// Override to specify the cost level for your rule:
  /// - [RuleCost.trivial]: Very fast (simple pattern matching)
  /// - [RuleCost.low]: Fast (single AST node inspection)
  /// - [RuleCost.medium]: Medium (traverse part of AST) - default
  /// - [RuleCost.high]: Slow (traverse full AST or type resolution)
  /// - [RuleCost.extreme]: Very slow (cross-file analysis simulation)
  ///
  /// Rules are sorted by cost before execution, so fast rules run first.
  /// Default: [RuleCost.medium]
  RuleCost get cost => RuleCost.medium;

  // ============================================================
  // OWASP Security Compliance Mapping
  // ============================================================

  /// OWASP categories this rule helps prevent.
  ///
  /// Override to specify OWASP Mobile Top 10 and/or Web Top 10 categories
  /// that this rule addresses. Returns `null` for non-security rules.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// OwaspMapping? get owasp => const OwaspMapping(
  ///   mobile: {OwaspMobile.m1, OwaspMobile.m10},
  ///   web: {OwaspWeb.a02, OwaspWeb.a07},
  /// );
  /// ```
  ///
  /// This mapping enables:
  /// - Compliance reporting for security audits
  /// - Risk categorization aligned with industry standards
  /// - Coverage analysis across OWASP categories
  OwaspMapping? get owasp => null;

  // ============================================================
  // Quick Fixes (Automatic Ignore Suppression)
  // ============================================================

  /// Rule-specific quick fixes.
  ///
  /// Override this getter to provide custom fixes for your rule.
  /// These are combined with the automatic ignore fixes.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// List<Fix> get customFixes => [_MyRuleSpecificFix()];
  /// ```
  ///
  /// Default: empty list (only ignore fixes provided)
  List<Fix> get customFixes => const <Fix>[];

  /// Whether to include automatic "ignore" quick fixes.
  ///
  /// When `true` (default), every rule automatically gets two quick fixes:
  /// - "Ignore 'rule_name' for this line" - adds `// ignore: rule_name`
  /// - "Ignore 'rule_name' for this file" - adds `// ignore_for_file: rule_name`
  ///
  /// Set to `false` for rules where suppression should not be offered
  /// (e.g., critical security rules).
  ///
  /// Example:
  /// ```dart
  /// @override
  /// bool get includeIgnoreFixes => false; // Don't allow suppression
  /// ```
  bool get includeIgnoreFixes => true;

  /// Returns the complete list of quick fixes for this rule.
  ///
  /// By default, this combines [customFixes] with automatic ignore fixes
  /// (if [includeIgnoreFixes] is `true`).
  ///
  /// **For new rules:** Override [customFixes] to add rule-specific fixes.
  ///
  /// **For existing rules:** If you override `getFixes()` directly, you can
  /// call `super.getFixes()` to include the ignore fixes:
  /// ```dart
  /// @override
  /// List<Fix> getFixes() => [...super.getFixes(), _MyCustomFix()];
  /// ```
  @override
  List<Fix> getFixes() {
    final fixes = <Fix>[...customFixes];
    if (includeIgnoreFixes) {
      fixes.addAll(<Fix>[
        AddIgnoreCommentFix(code.name),
        AddIgnoreForFileFix(code.name),
      ]);
    }
    return fixes;
  }

  // ============================================================
  // File Type Filtering (Performance Optimization)
  // ============================================================

  /// The file types this rule applies to.
  ///
  /// Override to restrict this rule to specific file types for early exit.
  /// Return `null` to apply to all files (default behavior).
  ///
  /// Example: A widget-specific rule should return `{FileType.widget}`:
  /// ```dart
  /// @override
  /// Set<FileType>? get applicableFileTypes => {FileType.widget};
  /// ```
  ///
  /// Files not matching any of the specified types will be skipped entirely,
  /// avoiding expensive AST traversal for irrelevant files.
  Set<FileType>? get applicableFileTypes => null;

  // ============================================================
  // Content Pre-filtering (Performance Optimization)
  // ============================================================

  /// String patterns that must be present in the file for this rule to run.
  ///
  /// Override to specify patterns for fast string-based early exit BEFORE
  /// AST parsing. If the file content doesn't contain ANY of these patterns,
  /// the rule is skipped entirely.
  ///
  /// Example: A rule checking `Timer.periodic` usage:
  /// ```dart
  /// @override
  /// Set<String>? get requiredPatterns => {'Timer.periodic'};
  /// ```
  ///
  /// Example: A rule checking various database calls:
  /// ```dart
  /// @override
  /// Set<String>? get requiredPatterns => {'rawQuery', 'rawInsert', 'execute'};
  /// ```
  ///
  /// This is faster than AST traversal since it's a simple string search.
  /// Return `null` to skip this optimization (default).
  Set<String>? get requiredPatterns => null;

  // ============================================================
  // Skip Small Files (Performance Optimization)
  // ============================================================

  /// Minimum line count for this rule to run.
  ///
  /// High-cost rules can override this to skip small files where complex
  /// patterns are unlikely. Files with fewer lines than this value are skipped.
  ///
  /// Example: A rule checking for complex nested callbacks:
  /// ```dart
  /// @override
  /// int get minimumLineCount => 50;
  /// ```
  ///
  /// Default: 0 (no minimum, rule runs on all files)
  int get minimumLineCount => 0;

  // ============================================================
  // Skip Large Files (DANGEROUS - Use Sparingly)
  // ============================================================

  /// Maximum line count for this rule to run.
  ///
  /// **WARNING**: Use this ONLY for rules with O(n²) or worse complexity
  /// where analysis time becomes prohibitive. Large files often NEED
  /// linting most - skipping them can hide real bugs!
  ///
  /// Consider using `avoid_long_length_files` rule to encourage file splitting
  /// instead of silently skipping analysis.
  ///
  /// Default: 0 (OFF - rule runs on all files regardless of size)
  int get maximumLineCount => 0;

  // ============================================================
  // Content Type Requirements (Performance Optimization)
  // ============================================================

  /// Whether this rule only applies to async code.
  ///
  /// If true, the rule is skipped for files without 'async' or 'Future'.
  /// This is a fast pre-filter before AST analysis.
  ///
  /// Example: Rules checking for missing await:
  /// ```dart
  /// @override
  /// bool get requiresAsync => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresAsync => false;

  /// Whether this rule only applies to Flutter widget code.
  ///
  /// If true, the rule is skipped for files without Widget/State patterns.
  /// This is a fast pre-filter before AST analysis.
  ///
  /// Example: Rules checking StatefulWidget lifecycle:
  /// ```dart
  /// @override
  /// bool get requiresWidgets => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresWidgets => false;

  /// Whether this rule only applies to files with class declarations.
  ///
  /// If true, the rule is skipped for files without class/mixin/extension.
  /// Uses ContentRegionIndex for fast detection.
  ///
  /// Example: Rules checking class structure:
  /// ```dart
  /// @override
  /// bool get requiresClassDeclaration => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresClassDeclaration => false;

  /// Whether this rule only applies to files with a main() function.
  ///
  /// If true, the rule is skipped for library files without main().
  /// Uses ContentRegionIndex for fast detection.
  ///
  /// Example: Rules checking app entry points:
  /// ```dart
  /// @override
  /// bool get requiresMainFunction => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresMainFunction => false;

  /// Whether this rule only applies to files with imports.
  ///
  /// If true, the rule is skipped for files without import/export statements.
  /// Uses ContentRegionIndex for fast detection.
  ///
  /// Example: Rules checking import organization:
  /// ```dart
  /// @override
  /// bool get requiresImports => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresImports => false;

  /// Whether this rule only applies to files that import Flutter.
  ///
  /// If true, the rule is skipped for files without `package:flutter/` imports.
  /// Uses cached FileMetrics for O(1) lookup after first computation.
  ///
  /// Example: Widget-specific rules:
  /// ```dart
  /// @override
  /// bool get requiresFlutterImport => true;
  /// ```
  ///
  /// **Impact**: Skips ~300+ widget rules instantly for pure Dart files.
  ///
  /// Default: false (runs on all files)
  bool get requiresFlutterImport => false;

  /// Whether this rule only applies to files that import Bloc.
  ///
  /// If true, the rule is skipped for files without `package:bloc/` or
  /// `package:flutter_bloc/` imports. Uses cached FileMetrics.
  ///
  /// Example: Bloc-specific rules:
  /// ```dart
  /// @override
  /// bool get requiresBlocImport => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresBlocImport => false;

  /// Whether this rule only applies to files that import Provider.
  ///
  /// If true, the rule is skipped for files without `package:provider/` imports.
  /// Uses cached FileMetrics.
  ///
  /// Example: Provider-specific rules:
  /// ```dart
  /// @override
  /// bool get requiresProviderImport => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresProviderImport => false;

  /// Whether this rule only applies to files that import Riverpod.
  ///
  /// If true, the rule is skipped for files without `package:riverpod/`,
  /// `package:flutter_riverpod/`, or `package:hooks_riverpod/` imports.
  /// Uses cached FileMetrics.
  ///
  /// Example: Riverpod-specific rules:
  /// ```dart
  /// @override
  /// bool get requiresRiverpodImport => true;
  /// ```
  ///
  /// Default: false (runs on all files)
  bool get requiresRiverpodImport => false;

  // ============================================================
  // Context-Aware Auto-Suppression (#2)
  // ============================================================

  /// Whether to skip generated files (*.g.dart, *.freezed.dart, *.gen.dart).
  ///
  /// Default: `true` - Generated code can't be fixed manually.
  bool get skipGeneratedCode => true;

  /// How this rule relates to test files.
  ///
  /// Override to control test file behavior:
  /// - [TestRelevance.never]: Skip test files (default)
  /// - [TestRelevance.always]: Run on all files including tests
  /// - [TestRelevance.testOnly]: Run ONLY on test files
  ///
  /// **Note:** Rules using `applicableFileTypes => {FileType.test}` are
  /// automatically treated as [TestRelevance.testOnly] for backwards
  /// compatibility, so they do NOT need to override this.
  TestRelevance get testRelevance => TestRelevance.never;

  /// Whether to skip test files (*_test.dart, test/**).
  ///
  /// @deprecated Use [testRelevance] instead:
  /// - `skipTestFiles => true` is now the default ([TestRelevance.never])
  /// - `skipTestFiles => false` becomes `testRelevance => TestRelevance.always`
  @Deprecated('Use testRelevance instead. See TestRelevance enum.')
  bool get skipTestFiles => false;

  /// Whether to skip example files (example/**).
  ///
  /// Default: `false` - Examples should generally follow best practices.
  /// Override to `true` for strict rules that may hinder documentation.
  bool get skipExampleFiles => false;

  /// Whether to skip fixture files (fixture/**, fixtures/**).
  ///
  /// Default: `true` - Fixture files often contain intentionally bad code.
  bool get skipFixtureFiles => true;

  // =========================================================================
  // GLOBAL FILE EXCLUSION PATTERNS
  // =========================================================================
  // These patterns are ALWAYS skipped regardless of rule settings.
  // They represent files that should never be analyzed by any rule.

  /// Folders that are ALWAYS excluded from analysis.
  /// These contain build artifacts, cached packages, or tooling output.
  static const Set<String> _globalExcludedFolders = <String>{
    '/.dart_tool/',
    '/build/',
    '/.pub-cache/',
    '/.pub/',
    '/ios/Pods/',
    '/ios/.symlinks/',
    '/android/.gradle/',
    '/windows/flutter/',
    '/linux/flutter/',
    '/macos/Flutter/',
    '/.fvm/',
  };

  // cspell:ignore pbenum pbjson pbserver
  /// File suffixes that indicate generated code.
  /// These files are machine-generated and can't be manually fixed.
  static const Set<String> _generatedFileSuffixes = <String>{
    '.g.dart',
    '.freezed.dart',
    '.gen.dart',
    '.gr.dart',
    '.config.dart',
    '.mocks.dart',
    '.chopper.dart',
    '.reflectable.dart',
    '.pb.dart',
    '.pbjson.dart',
    '.pbenum.dart',
    '.pbserver.dart',
    '.mapper.dart',
    '.module.dart',
  };

  /// Resolves the effective test relevance, accounting for backwards
  /// compatibility with [applicableFileTypes].
  ///
  /// Priority:
  /// 1. [applicableFileTypes] containing [FileType.test] => [testOnly]
  /// 2. [testRelevance] getter value (default: [TestRelevance.never])
  TestRelevance get _effectiveTestRelevance {
    final applicable = applicableFileTypes;
    if (applicable != null && applicable.contains(FileType.test)) {
      return TestRelevance.testOnly;
    }
    return testRelevance;
  }

  /// Check if a file path should be skipped based on context settings.
  bool _shouldSkipFile(String path) {
    // Normalize path separators
    final normalizedPath = path.replaceAll('\\', '/');

    // =========================================================================
    // GLOBAL EXCLUSIONS (always skip, regardless of rule settings)
    // =========================================================================

    // Check global excluded folders
    for (final folder in _globalExcludedFolders) {
      if (normalizedPath.contains(folder)) {
        return true;
      }
    }

    // =========================================================================
    // RULE-CONFIGURABLE EXCLUSIONS
    // =========================================================================

    // Check generated code patterns
    if (skipGeneratedCode) {
      // Check file suffixes
      for (final suffix in _generatedFileSuffixes) {
        if (normalizedPath.endsWith(suffix)) {
          return true;
        }
      }

      // Check generated folder
      if (normalizedPath.contains('/generated/')) {
        return true;
      }

      // Check for generated file markers in content (deferred - expensive)
      // This is handled separately via content-based detection
    }

    // Check test files using TestRelevance
    final isTest = FileTypeDetector.isTestPath(normalizedPath);
    final relevance = _effectiveTestRelevance;
    if (relevance == TestRelevance.testOnly && !isTest) {
      return true; // Skip non-test files for test-only rules
    }
    if (relevance == TestRelevance.never && isTest) {
      return true; // Skip test files (default)
    }
    // TestRelevance.always: no skip based on test status

    // Check example files
    if (skipExampleFiles) {
      if (normalizedPath.contains('/example/') ||
          normalizedPath.contains('/examples/')) {
        return true;
      }
    }

    // Check fixture files - but NOT in example/ directory
    // (example fixtures are specifically for testing the linter rules)
    if (skipFixtureFiles) {
      final isInExample = normalizedPath.contains('/example/') ||
          normalizedPath.contains('/examples/');
      if (!isInExample) {
        if (normalizedPath.contains('/fixture/') ||
            normalizedPath.contains('/fixtures/') ||
            normalizedPath.contains('_fixture.dart')) {
          return true;
        }
      }
    }

    return false;
  }

  // ============================================================
  // Documentation URL Generation (#4)
  // ============================================================

  /// Base URL for rule documentation.
  ///
  /// Override to customize the documentation host.
  static const String documentationBaseUrl =
      'https://pub.dev/packages/saropa_lints';

  /// Returns the documentation URL for this rule.
  ///
  /// Format: `https://pub.dev/packages/saropa_lints#rule_name`
  String get documentationUrl => '$documentationBaseUrl#${code.name}';

  /// Returns the rule name in hyphenated format for display.
  ///
  /// Example: `no_empty_block` → `no-empty-block`
  String get hyphenatedName => code.name.replaceAll('_', '-');

  // ============================================================
  // Severity Override Support (#5)
  // ============================================================

  /// Global severity overrides map.
  ///
  /// Set this to override severities at the project level:
  /// ```dart
  /// SaropaLintRule.severityOverrides = {
  ///   'avoid_print': DiagnosticSeverity.ERROR,
  ///   'prefer_const': DiagnosticSeverity.INFO,
  /// };
  /// ```
  static Map<String, DiagnosticSeverity>? severityOverrides;

  /// Rules that are completely disabled via severity overrides.
  ///
  /// Set rule name to null in [severityOverrides] to disable.
  static Set<String>? disabledRules;

  /// Check if this rule is disabled via configuration.
  bool get isDisabled => disabledRules?.contains(code.name) ?? false;

  /// Get the effective severity for this rule, considering overrides.
  DiagnosticSeverity? get effectiveSeverity =>
      severityOverrides?[code.name] ?? code.errorSeverity;

  // ============================================================
  // Core Implementation
  // ============================================================

  // Track if we've initialized the project root for disk persistence
  static bool _projectRootInitialized = false;

  // Track recent analysis for throttling: "path:contentHash" -> timestamp
  // Prevents duplicate analysis of identical content within short windows
  static final Map<String, DateTime> _recentAnalysis = {};
  static const Duration _throttleWindow = Duration(milliseconds: 300);

  /// Common markers found in generated files (checked in first 500 chars).
  static const List<String> _generatedContentMarkers = <String>[
    'GENERATED CODE',
    'DO NOT MODIFY',
    'DO NOT EDIT',
    'AUTO-GENERATED',
    'AUTOGENERATED',
    '@GeneratedCode',
    '@Generated(',
    'Generated by ',
    'Code generated by',
    'This file was generated',
    'generated file',
    'part of ', // Part files are often generated
  ];

  /// Check if file content indicates it's generated code.
  ///
  /// Examines the first 500 characters for common generator markers.
  static bool _isGeneratedContent(String content) {
    if (content.isEmpty) return false;

    // Only check the header of the file for performance
    final header = content.length > 500 ? content.substring(0, 500) : content;
    final upperHeader = header.toUpperCase();

    for (final marker in _generatedContentMarkers) {
      if (upperHeader.contains(marker.toUpperCase())) {
        return true;
      }
    }
    return false;
  }

  // Track edit frequency per file for adaptive tier switching
  // Maps file path to list of recent analysis timestamps
  static final Map<String, List<DateTime>> _fileEditHistory = {};
  static const Duration _rapidEditWindow = Duration(seconds: 2);
  static const int _rapidEditThreshold = 3;

  /// Check if a file is being rapidly edited (3+ analyses in 2 seconds).
  ///
  /// During rapid editing, only essential-tier rules run for faster feedback.
  static bool _isRapidEditMode(String path) {
    final now = DateTime.now();
    final history = _fileEditHistory[path];

    if (history == null) {
      _fileEditHistory[path] = [now];
      return false;
    }

    // Add current timestamp
    history.add(now);

    // Remove old entries outside the window
    final cutoff = now.subtract(_rapidEditWindow);
    history.removeWhere((t) => t.isBefore(cutoff));

    // Cleanup: limit total tracked files to prevent memory growth
    if (_fileEditHistory.length > 100) {
      // Remove files not edited recently
      final oldCutoff = now.subtract(const Duration(seconds: 30));
      _fileEditHistory.removeWhere(
        (_, times) => times.isEmpty || times.last.isBefore(oldCutoff),
      );
    }

    // Rapid mode if 3+ edits in the window
    return history.length >= _rapidEditThreshold;
  }

  /// Check if this rule belongs to the essential tier.
  ///
  /// Essential-tier rules run even during rapid editing.
  bool _isEssentialTierRule() {
    return essentialRules.contains(code.name);
  }

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check if rule is disabled
    if (isDisabled) return;

    // =========================================================================
    // ISSUE LIMIT CHECK (Performance Optimization)
    // =========================================================================
    // After hitting the warning/info limit, skip non-ERROR rules entirely.
    // This provides real speedup on legacy codebases with many issues.
    // ERROR-severity rules always run (security, crashes, etc.)
    if (ProgressTracker.isLimitReached &&
        code.errorSeverity != DiagnosticSeverity.ERROR) {
      return;
    }

    // =========================================================================
    // SLOW RULE DEFERRAL (Performance Optimization)
    // =========================================================================
    // When SAROPA_LINTS_DEFER=true, skip rules that historically take >50ms.
    // Run these later with SAROPA_LINTS_DEFERRED=true for a two-pass approach.
    if (RuleTimingTracker.shouldDefer(code.name)) {
      return; // Will run in second pass with SAROPA_LINTS_DEFERRED=true
    }
    if (RuleTimingTracker.shouldSkipInDeferredMode(code.name)) {
      return; // Already ran in first pass
    }

    // Check if file should be skipped based on context
    final path = resolver.source.fullName;
    if (_shouldSkipFile(path)) return;

    // =========================================================================
    // PROGRESS TRACKING (User Feedback)
    // =========================================================================
    // Record this file for progress reporting. Only fires when enabled via
    // environment variable SAROPA_LINTS_PROGRESS=true
    ProgressTracker.recordFile(path);

    // =========================================================================
    // BATCH EXECUTION PLAN CHECK (Performance Optimization)
    // =========================================================================
    // If a batch execution plan was created, check if this rule should run
    // on this file. The plan was computed via parallel pre-analysis.
    if (!RuleBatchExecutor.shouldRuleRunOnFile(code.name, path)) {
      return;
    }

    // Get file content from resolver (already loaded by analyzer)
    final content = resolver.source.contents.data;

    // =========================================================================
    // FILE-LEVEL IGNORE CHECK
    // =========================================================================
    // Respect `// ignore_for_file: rule_name` directives. This check runs
    // once per rule per file, before any AST callbacks, so the entire rule
    // is skipped efficiently when the file opts out.
    if (IgnoreUtils.isIgnoredForFile(content, code.name)) {
      return;
    }

    // =========================================================================
    // CONTENT-BASED GENERATED FILE DETECTION (Performance Optimization)
    // =========================================================================
    // Some generated files don't have a recognizable suffix. Detect them by
    // looking for common generator markers in the first 500 chars of the file.
    if (skipGeneratedCode && _isGeneratedContent(content)) {
      return;
    }

    // =========================================================================
    // DISK PERSISTENCE INITIALIZATION (Performance Optimization)
    // =========================================================================
    // On first file, detect project root and load cached analysis state.
    // This allows the cache to survive IDE restarts.
    if (!_projectRootInitialized) {
      _projectRootInitialized = true;
      final projectRoot = ProjectContext.findProjectRoot(path);
      if (projectRoot != null) {
        IncrementalAnalysisTracker.setProjectRoot(projectRoot);
        // Initialize git-aware prioritization for faster feedback on edited files
        GitAwarePriority.initialize(projectRoot);
        // Initialize report writer for automatic report generation
        AnalysisReporter.initialize(projectRoot);
      }
    }

    // =========================================================================
    // MEMORY PRESSURE CHECK (Performance Optimization)
    // =========================================================================
    // Record that a file is being processed. This triggers automatic cache
    // clearing when memory usage exceeds the configured threshold.
    MemoryPressureHandler.recordFileProcessed();

    // =========================================================================
    // RAPID ANALYSIS THROTTLE (Performance Optimization)
    // =========================================================================
    // Skip if we just analyzed this exact content. This prevents redundant
    // analysis during rapid saves while still analyzing changed content.
    // BUG FIX: Include rule name in key so different rules don't share throttle
    final analysisKey = '$path:${content.hashCode}:${code.name}';
    final now = DateTime.now();
    final lastAnalysis = _recentAnalysis[analysisKey];
    if (lastAnalysis != null &&
        now.difference(lastAnalysis) < _throttleWindow) {
      return; // Same content analyzed too recently
    }
    _recentAnalysis[analysisKey] = now;

    // Cleanup stale entries periodically to prevent memory leaks
    if (_recentAnalysis.length > 1000) {
      final cutoff = now.subtract(const Duration(seconds: 10));
      _recentAnalysis.removeWhere((_, time) => time.isBefore(cutoff));
    }

    // =========================================================================
    // INCREMENTAL ANALYSIS CHECK (Performance Optimization)
    // =========================================================================
    // If this rule already passed on this unchanged file, skip re-analysis.
    // This provides massive speedups for subsequent analysis runs.
    if (IncrementalAnalysisTracker.canSkipRule(path, content, code.name)) {
      return;
    }

    // =========================================================================
    // EARLY EXIT BY REQUIRED PATTERNS (Performance Optimization)
    // =========================================================================
    // If this rule specifies required patterns, check if the file contains
    // any of them before doing expensive AST work. This is a fast string search.
    final patterns = requiredPatterns;
    if (patterns != null && patterns.isNotEmpty) {
      final hasAnyPattern = patterns.any((p) => content.contains(p));
      if (!hasAnyPattern) {
        // Early exit - file doesn't contain any required patterns
        // Record as passed since it can never violate this rule
        IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
        return;
      }
    }

    // =========================================================================
    // FILE METRICS CHECKS (Performance Optimization)
    // =========================================================================
    // Use cached file metrics for fast filtering based on file characteristics.
    final metrics = FileMetricsCache.get(path, content);

    // Check minimum line count
    final minLines = minimumLineCount;
    if (minLines > 0 && metrics.lineCount < minLines) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }

    // Check maximum line count (DANGEROUS - only for O(n²) rules)
    final maxLines = maximumLineCount;
    if (maxLines > 0 && metrics.lineCount > maxLines) {
      // NOTE: This skips analysis! Only use for prohibitively slow rules.
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }

    // Check async code requirement
    if (requiresAsync && !metrics.hasAsyncCode) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }

    // Check widget code requirement
    if (requiresWidgets && !metrics.hasWidgets) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }

    // =========================================================================
    // CONTENT REGION CHECKS (Performance Optimization)
    // =========================================================================
    // Use ContentRegionIndex for fast structural checks without full AST parse.
    if (requiresClassDeclaration || requiresMainFunction || requiresImports) {
      final regions = ContentRegionIndex.get(path, content);

      // Check class declaration requirement
      if (requiresClassDeclaration && regions.classDeclarations.isEmpty) {
        IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
        return;
      }

      // Check main function requirement
      if (requiresMainFunction && !regions.hasMain) {
        IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
        return;
      }

      // Check imports requirement
      if (requiresImports && regions.importRegion.isEmpty) {
        IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
        return;
      }
    }

    // =========================================================================
    // PACKAGE IMPORT CHECKS (Performance Optimization)
    // =========================================================================
    // Use cached FileMetrics for O(1) import detection. Avoids redundant
    // string searches when multiple rules check the same imports.
    if (requiresFlutterImport && !metrics.hasFlutterImport) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }
    if (requiresBlocImport && !metrics.hasBlocImport) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }
    if (requiresProviderImport && !metrics.hasProviderImport) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }
    if (requiresRiverpodImport && !metrics.hasRiverpodImport) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
      return;
    }

    // =========================================================================
    // ADAPTIVE TIER SWITCHING (Performance Optimization)
    // =========================================================================
    // During rapid editing (same file analyzed 3+ times in 2 seconds), only
    // run essential-tier rules. Full analysis runs after editing settles.
    // BUG FIX: Disable during CLI runs - this was incorrectly triggering when
    // multiple rules analyze the same file within a single custom_lint run.
    // TODO: Re-enable only for IDE/interactive analysis mode
    // if (_isRapidEditMode(path) && !_isEssentialTierRule()) {
    //   // Skip non-essential rules during rapid editing for faster feedback
    //   return;
    // }

    // =========================================================================
    // EARLY EXIT BY FILE TYPE (Performance Optimization)
    // =========================================================================
    // If this rule specifies applicable file types, check if the current file
    // matches before doing any expensive AST work. This can skip entire rules
    // for files where they don't apply (e.g., widget rules on non-widget files).
    final applicable = applicableFileTypes;
    if (applicable != null && applicable.isNotEmpty) {
      final fileTypes = FileTypeDetector.detect(path, content);

      // Check if any of the rule's applicable types match the file's types
      final hasMatch = applicable.any((type) => fileTypes.contains(type));
      if (!hasMatch) {
        // Early exit - this rule doesn't apply to this file type
        IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
        return;
      }
    }

    // Run the rule
    _runRuleWithReporter(resolver, reporter, path, content, context);
  }

  /// Internal helper to run the rule with timing and reporter wrapping.
  void _runRuleWithReporter(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    String path,
    String content,
    CustomLintContext context,
  ) {
    // Create wrapped reporter with severity override and impact tracking
    final wrappedReporter = SaropaDiagnosticReporter(
      reporter,
      code.name,
      filePath: path,
      impact: impact,
      severityOverride: severityOverrides?[code.name],
    );

    // Track whether rule reports any violations
    var hadViolations = false;
    final trackingReporter = _TrackingReporter(
      wrappedReporter,
      onViolation: () => hadViolations = true,
    );

    // =========================================================================
    // TIMING INSTRUMENTATION
    // =========================================================================
    // When profiling is enabled (SAROPA_LINTS_PROFILE=true), measure rule
    // execution time and log slow rules (>10ms) for performance investigation.
    if (_profilingEnabled) {
      final stopwatch = Stopwatch()..start();
      runWithReporter(resolver, trackingReporter, context);
      stopwatch.stop();
      RuleTimingTracker.record(code.name, stopwatch.elapsed);
    } else {
      runWithReporter(resolver, trackingReporter, context);
    }

    // =========================================================================
    // RECORD CLEAN FILES (Performance Optimization)
    // =========================================================================
    // If the rule found no violations, record this for incremental analysis.
    // Next time, we can skip this rule entirely if the file hasn't changed.
    if (!hadViolations) {
      IncrementalAnalysisTracker.recordRulePassed(path, content, code.name);
    }
  }

  /// Override this method instead of [run] to implement your lint rule.
  ///
  /// The [reporter] automatically handles:
  /// - Hyphenated ignore comment aliases
  /// - Severity overrides
  /// - Context-aware suppression (files are pre-filtered)
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  );
}

/// A diagnostic reporter that checks for hyphenated ignore comments,
/// supports severity overrides, and tracks violations by impact level.
///
/// Wraps a [DiagnosticReporter] and intercepts [atNode] calls to check
/// for ignore comments in both underscore and hyphen formats.
class SaropaDiagnosticReporter {
  SaropaDiagnosticReporter(
    this._delegate,
    this._ruleName, {
    required this.filePath,
    required this.impact,
    this.severityOverride,
  });

  final DiagnosticReporter _delegate;
  final String _ruleName;
  final String filePath;
  final LintImpact impact;

  /// Optional severity override for this rule.
  final DiagnosticSeverity? severityOverride;

  /// Creates a new LintCode with overridden severity if configured.
  LintCode _applyOverride(LintCode code) {
    final override = severityOverride;
    if (override == null) return code;

    return LintCode(
      name: code.name,
      problemMessage: code.problemMessage,
      correctionMessage: code.correctionMessage,
      uniqueName: code.uniqueName,
      url: code.url,
      errorSeverity: override,
    );
  }

  /// Reports a diagnostic at the given [node], unless an ignore comment
  /// is present (supports both underscore and hyphen formats), or the
  /// violation is suppressed by baseline configuration.
  void atNode(AstNode node, LintCode code) {
    // Check for hyphenated ignore comment before reporting
    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
      return;
    }

    // Check if violation is suppressed by baseline
    final line = _getLineNumber(node.offset, node);
    if (BaselineManager.isBaselined(filePath, _ruleName, line)) {
      return;
    }

    // Track the violation by impact level
    _trackViolation(code, line);

    _delegate.atNode(node, _applyOverride(code));
  }

  /// Reports a diagnostic at the given [token].
  void atToken(Token token, LintCode code) {
    // Check for hyphenated ignore comment on the token
    if (IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)) {
      return;
    }

    // Check if violation is suppressed by baseline (path-based only for tokens)
    // Token doesn't have easy line access, so line-based baseline won't match
    if (BaselineManager.isBaselined(filePath, _ruleName, 0)) {
      return;
    }

    // Track the violation by impact level
    _trackViolation(code, 0); // Token doesn't have easy line access

    // Use atOffset instead of atToken to ensure proper span width.
    // The built-in atToken has a bug where endColumn equals startColumn
    // (zero-width highlight). Using atOffset with explicit length fixes this.
    _delegate.atOffset(
      offset: token.offset,
      length: token.length,
      diagnosticCode: _applyOverride(code),
    );
  }

  /// Reports a diagnostic at the given offset and length.
  ///
  /// Note: This method cannot check for ignore comments or line-based baseline
  /// since we only have offset/length, not an AST node. Use [atNode] when possible.
  void atOffset({
    required int offset,
    required int length,
    required LintCode errorCode,
  }) {
    // Check if violation is suppressed by baseline (path-based only)
    if (BaselineManager.isBaselined(filePath, errorCode.name, 0)) {
      return;
    }

    // Track the violation by impact level
    _trackViolation(errorCode, 0);

    // Cannot easily check for ignore comments with just offset/length
    // Delegate directly to the underlying reporter
    _delegate.atOffset(
      offset: offset,
      length: length,
      diagnosticCode: _applyOverride(errorCode),
    );
  }

  /// Track a violation in the ImpactTracker and ProgressTracker.
  void _trackViolation(LintCode code, int line) {
    // Track for impact reporting
    ImpactTracker.record(
      impact: impact,
      rule: _ruleName,
      file: filePath,
      line: line,
      message: code.problemMessage,
    );

    // Track for progress reporting with severity
    final severity = code.errorSeverity.name;
    ProgressTracker.recordViolation(severity: severity, ruleName: _ruleName);

    // Schedule report file writing (debounced)
    AnalysisReporter.scheduleWrite();
  }

  /// Get approximate line number from an AST node.
  int _getLineNumber(int offset, AstNode node) {
    // Try to get line info from the node's root
    try {
      final root = node.root;
      if (root is CompilationUnit) {
        return root.lineInfo.getLocation(offset).lineNumber;
      }
    } catch (_) {
      // Fall back to 0 if we can't determine the line
    }
    return 0;
  }
}

/// A wrapper reporter that tracks whether any violations were reported.
///
/// Used by the incremental analysis system to record rules that pass
/// (report no violations) so they can be skipped on subsequent runs.
class _TrackingReporter extends SaropaDiagnosticReporter {
  _TrackingReporter(
    SaropaDiagnosticReporter delegate, {
    required this.onViolation,
  }) : super(
          delegate._delegate,
          delegate._ruleName,
          filePath: delegate.filePath,
          impact: delegate.impact,
          severityOverride: delegate.severityOverride,
        );

  final void Function() onViolation;

  @override
  void atNode(AstNode node, LintCode code) {
    onViolation();
    super.atNode(node, code);
  }

  @override
  void atToken(Token token, LintCode code) {
    onViolation();
    super.atToken(token, code);
  }

  @override
  void atOffset({
    required int offset,
    required int length,
    required LintCode errorCode,
  }) {
    onViolation();
    super.atOffset(offset: offset, length: length, errorCode: errorCode);
  }
}
