// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'dart:developer' as developer;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'ignore_utils.dart';

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

    // Create wrapped reporter with severity override and impact tracking
    final wrappedReporter = SaropaDiagnosticReporter(
      reporter,
      code.name,
      filePath: path,
      impact: impact,
      severityOverride: severityOverrides?[code.name],
    );

    // =========================================================================
    // TIMING INSTRUMENTATION
    // =========================================================================
    // When profiling is enabled (SAROPA_LINTS_PROFILE=true), measure rule
    // execution time and log slow rules (>10ms) for performance investigation.
    if (_profilingEnabled) {
      final stopwatch = Stopwatch()..start();
      runWithReporter(resolver, wrappedReporter, context);
      stopwatch.stop();
      RuleTimingTracker.record(code.name, stopwatch.elapsed);
    } else {
      runWithReporter(resolver, wrappedReporter, context);
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
  /// is present (supports both underscore and hyphen formats).
  void atNode(AstNode node, LintCode code) {
    // Check for hyphenated ignore comment before reporting
    if (IgnoreUtils.hasIgnoreComment(node, _ruleName)) {
      return;
    }

    // Track the violation by impact level
    _trackViolation(code, _getLineNumber(node.offset, node));

    _delegate.atNode(node, _applyOverride(code));
  }

  /// Reports a diagnostic at the given [token].
  void atToken(Token token, LintCode code) {
    // Check for hyphenated ignore comment on the token
    if (IgnoreUtils.hasIgnoreCommentOnToken(token, _ruleName)) {
      return;
    }

    // Track the violation by impact level
    _trackViolation(code, 0); // Token doesn't have easy line access

    _delegate.atToken(token, _applyOverride(code));
  }

  /// Reports a diagnostic at the given offset and length.
  ///
  /// Note: This method cannot check for ignore comments since we only have
  /// offset/length, not an AST node. Use [atNode] when possible.
  void atOffset({
    required int offset,
    required int length,
    required LintCode errorCode,
  }) {
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
