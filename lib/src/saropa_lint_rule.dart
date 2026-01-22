// ignore_for_file: always_specify_types, depend_on_referenced_packages, unused_element

import 'dart:developer' as developer;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'baseline/baseline_manager.dart';
import 'ignore_utils.dart';
import 'owasp/owasp.dart';
import 'project_context.dart';
import 'tiers.dart' show essentialRules;

// Re-export types needed by rule implementations
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

/// Controls whether progress reporting is enabled (default: true).
///
/// Disable via environment variable: SAROPA_LINTS_PROGRESS=false
final bool _progressEnabled =
    const bool.fromEnvironment('SAROPA_LINTS_PROGRESS', defaultValue: true) &&
        const String.fromEnvironment('SAROPA_LINTS_PROGRESS',
                defaultValue: 'true') !=
            'false';

// =============================================================================
// PROGRESS TRACKING (User Feedback)
// =============================================================================
//
// Tracks analysis progress to show the user that the linter is working.
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

  /// Interval between progress reports (in files or time).
  static const int _fileInterval = 25;
  static const Duration _timeInterval = Duration(seconds: 3);

  /// Record that a file is being analyzed and potentially report progress.
  static void recordFile(String path) {
    if (!_progressEnabled) return;

    // Initialize start time on first file
    _startTime ??= DateTime.now();
    _lastProgressTime ??= _startTime;

    // Track unique files
    final wasNew = _seenFiles.add(path);
    if (!wasNew) return; // Already seen this file

    final now = DateTime.now();
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

  /// Calculate files per second, avoiding division by zero.
  static double _calculateFilesPerSec(int fileCount, Duration elapsed) {
    return elapsed.inMilliseconds > 0
        ? (fileCount * 1000) / elapsed.inMilliseconds
        : 0.0;
  }

  static void _reportProgress(int fileCount, DateTime now) {
    final elapsed = now.difference(_startTime!);
    final filesPerSec = _calculateFilesPerSec(fileCount, elapsed);

    // Extract just the filename from the last seen file for context
    final lastFile = _seenFiles.last;
    final shortName = lastFile.split('/').last.split('\\').last;

    print(
      '[saropa_lints] Progress: $fileCount files analyzed '
      '(${elapsed.inSeconds}s, ${filesPerSec.toStringAsFixed(1)} files/sec) '
      '- $shortName',
    );
  }

  /// Report final summary when analysis completes.
  static void reportSummary() {
    if (!_progressEnabled || _startTime == null) return;

    final elapsed = DateTime.now().difference(_startTime!);
    final fileCount = _seenFiles.length;
    final filesPerSec = _calculateFilesPerSec(fileCount, elapsed);

    print(
      '[saropa_lints] Complete: $fileCount files analyzed in ${elapsed.inSeconds}s '
      '(${filesPerSec.toStringAsFixed(1)} files/sec)',
    );
  }

  /// Reset tracking state (useful between analysis runs).
  static void reset() {
    _seenFiles.clear();
    _startTime = null;
    _lastProgressTime = null;
    _lastReportedCount = 0;
  }
}

/// Tracks cumulative timing for each rule across all files.
class RuleTimingTracker {
  RuleTimingTracker._();

  static final Map<String, Duration> _totalTime = {};
  static final Map<String, int> _callCount = {};

  /// Record a rule execution time.
  static void record(String ruleName, Duration elapsed) {
    _totalTime[ruleName] = (_totalTime[ruleName] ?? Duration.zero) + elapsed;
    _callCount[ruleName] = (_callCount[ruleName] ?? 0) + 1;

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
      buffer.writeln(
        '  ${timing.ruleName}: '
        '${timing.totalTime.inMilliseconds}ms total, '
        '${timing.callCount} calls, '
        '${timing.averageTime.inMicroseconds / 1000}ms avg',
      );
    }

    return buffer.toString();
  }

  /// Reset all timing data.
  static void reset() {
    _totalTime.clear();
    _callCount.clear();
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
  ///   enforce_arguments_ordering: false  # canonical name
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

  /// Whether to skip test files (*_test.dart, test/**).
  ///
  /// Default: `false` - Most rules should run in tests too.
  /// Override to `true` for rules that don't apply to test code.
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

  /// Check if a file path should be skipped based on context settings.
  bool _shouldSkipFile(String path) {
    // Normalize path separators
    final normalizedPath = path.replaceAll('\\', '/');

    // Check generated code patterns
    if (skipGeneratedCode) {
      if (normalizedPath.endsWith('.g.dart') ||
          normalizedPath.endsWith('.freezed.dart') ||
          normalizedPath.endsWith('.gen.dart') ||
          normalizedPath.endsWith('.gr.dart') ||
          normalizedPath.endsWith('.config.dart') ||
          normalizedPath.endsWith('.mocks.dart') ||
          normalizedPath.contains('/generated/')) {
        return true;
      }
    }

    // Check test files
    if (skipTestFiles) {
      if (normalizedPath.endsWith('_test.dart') ||
          normalizedPath.contains('/test/') ||
          normalizedPath.contains('/test_driver/') ||
          normalizedPath.contains('/integration_test/')) {
        return true;
      }
    }

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

  /// Track a violation in the ImpactTracker.
  void _trackViolation(LintCode code, int line) {
    ImpactTracker.record(
      impact: impact,
      rule: _ruleName,
      file: filePath,
      line: line,
      message: code.problemMessage,
    );
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
