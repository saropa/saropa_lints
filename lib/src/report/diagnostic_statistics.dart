import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:path/path.dart' as path;
import 'package:saropa_lints/saropa_lints.dart' show getRulesFromRegistry;

/// Runtime configuration for diagnostic statistics enhancements.
///
/// Populated by config loading and consumed by report/export writers.
class DiagnosticStatisticsConfig {
  DiagnosticStatisticsConfig._();

  static Map<String, int> _warnThresholds = const <String, int>{};
  static Map<String, int> _failThresholds = const <String, int>{};
  static String? _baselinePath;

  static Map<String, int> get warnThresholds => _warnThresholds;
  static Map<String, int> get failThresholds => _failThresholds;
  static String? get baselinePath => _baselinePath;

  static bool get hasThresholds =>
      _warnThresholds.isNotEmpty || _failThresholds.isNotEmpty;
  static bool get hasBaseline =>
      _baselinePath != null && _baselinePath!.isNotEmpty;

  static void setThresholds({
    required Map<String, int> warn,
    required Map<String, int> fail,
  }) {
    _warnThresholds = Map<String, int>.unmodifiable(warn);
    _failThresholds = Map<String, int>.unmodifiable(fail);
  }

  static void setBaselinePath(String? baselinePath) {
    _baselinePath = baselinePath?.trim().isEmpty ?? true
        ? null
        : baselinePath?.trim();
  }

  static void reset() {
    _warnThresholds = const <String, int>{};
    _failThresholds = const <String, int>{};
    _baselinePath = null;
  }
}

class ThresholdBreach {
  const ThresholdBreach({
    required this.rule,
    required this.count,
    required this.threshold,
  });

  final String rule;
  final int count;
  final int threshold;
}

class ThresholdEvaluation {
  const ThresholdEvaluation({required this.warnings, required this.failures});

  final List<ThresholdBreach> warnings;
  final List<ThresholdBreach> failures;

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasFailures => failures.isNotEmpty;
  bool get hasBreaches => hasWarnings || hasFailures;
}

class BaselineDiff {
  const BaselineDiff({
    required this.enabled,
    required this.baselinePath,
    required this.baselineFound,
    required this.baselineTotal,
    required this.totalNewViolations,
    required this.byRule,
  });

  final bool enabled;
  final String? baselinePath;
  final bool baselineFound;
  final int baselineTotal;
  final int totalNewViolations;
  final Map<String, int> byRule;
}

class DiagnosticStatisticsEvaluation {
  const DiagnosticStatisticsEvaluation({
    required this.thresholds,
    required this.baseline,
  });

  final ThresholdEvaluation thresholds;
  final BaselineDiff baseline;
}

/// Evaluates configured thresholds and baseline deltas.
class DiagnosticStatisticsEvaluator {
  DiagnosticStatisticsEvaluator._();

  static DiagnosticStatisticsEvaluation evaluate({
    required String projectRoot,
    required Map<String, int> issuesByRule,
  }) {
    final thresholds = _evaluateThresholds(issuesByRule);
    final baseline = _evaluateBaseline(projectRoot, issuesByRule);
    return DiagnosticStatisticsEvaluation(
      thresholds: thresholds,
      baseline: baseline,
    );
  }

  static ThresholdEvaluation _evaluateThresholds(
    Map<String, int> issuesByRule,
  ) {
    final thresholdCounts = _buildThresholdCountLookup(issuesByRule);
    final warnings = <ThresholdBreach>[];
    final failures = <ThresholdBreach>[];

    for (final entry in DiagnosticStatisticsConfig.warnThresholds.entries) {
      final count = thresholdCounts[entry.key] ?? 0;
      if (count > entry.value) {
        warnings.add(
          ThresholdBreach(
            rule: entry.key,
            count: count,
            threshold: entry.value,
          ),
        );
      }
    }

    for (final entry in DiagnosticStatisticsConfig.failThresholds.entries) {
      final count = thresholdCounts[entry.key] ?? 0;
      if (count > entry.value) {
        failures.add(
          ThresholdBreach(
            rule: entry.key,
            count: count,
            threshold: entry.value,
          ),
        );
      }
    }

    warnings.sort((a, b) => b.count.compareTo(a.count));
    failures.sort((a, b) => b.count.compareTo(a.count));

    return ThresholdEvaluation(warnings: warnings, failures: failures);
  }

  static Map<String, int> _buildThresholdCountLookup(
    Map<String, int> issuesByRule,
  ) {
    final counts = <String, int>{...issuesByRule};
    if (issuesByRule.isEmpty) return counts;

    final rules = getRulesFromRegistry(issuesByRule.keys.toSet());
    for (final rule in rules) {
      final ruleName = rule.code.lowerCaseName;
      final issueCount = issuesByRule[ruleName];
      if (issueCount == null || issueCount <= 0) continue;
      final ruleType = rule.ruleType?.name ?? 'unspecified';
      final ruleStatus = rule.ruleStatus.name;
      final ruleTypeKey = 'ruleType.$ruleType';
      final ruleStatusKey = 'ruleStatus.$ruleStatus';
      counts[ruleTypeKey] = (counts[ruleTypeKey] ?? 0) + issueCount;
      counts[ruleStatusKey] = (counts[ruleStatusKey] ?? 0) + issueCount;
    }
    return counts;
  }

  static BaselineDiff _evaluateBaseline(
    String projectRoot,
    Map<String, int> issuesByRule,
  ) {
    final configuredPath = DiagnosticStatisticsConfig.baselinePath;
    if (configuredPath == null || configuredPath.isEmpty) {
      return const BaselineDiff(
        enabled: false,
        baselinePath: null,
        baselineFound: false,
        baselineTotal: 0,
        totalNewViolations: 0,
        byRule: <String, int>{},
      );
    }

    final resolvedPath = path.normalize(
      path.isAbsolute(configuredPath)
          ? configuredPath
          : path.join(projectRoot, configuredPath),
    );
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return BaselineDiff(
        enabled: true,
        baselinePath: resolvedPath,
        baselineFound: false,
        baselineTotal: 0,
        totalNewViolations: 0,
        byRule: const <String, int>{},
      );
    }

    final baselineCounts = _readBaselineRuleCounts(file);
    final deltas = <String, int>{};
    var totalNew = 0;

    for (final entry in issuesByRule.entries) {
      final diff = entry.value - (baselineCounts[entry.key] ?? 0);
      if (diff > 0) {
        deltas[entry.key] = diff;
        totalNew += diff;
      }
    }

    return BaselineDiff(
      enabled: true,
      baselinePath: resolvedPath,
      baselineFound: true,
      baselineTotal: baselineCounts.values.fold(0, (sum, count) => sum + count),
      totalNewViolations: totalNew,
      byRule: Map<String, int>.unmodifiable(deltas),
    );
  }

  static Map<String, int> _readBaselineRuleCounts(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return const <String, int>{};
      final map = Map<String, dynamic>.from(decoded.cast<String, dynamic>());

      // Accept either a dedicated baseline snapshot format:
      // { "issuesByRule": { ... } }
      // or a full violations.json shape:
      // { "summary": { "issuesByRule": { ... } } }
      final direct = map['issuesByRule'];
      if (direct is Map) {
        return _toIntMap(direct);
      }

      final summary = map['summary'];
      if (summary is Map) {
        final nested = summary['issuesByRule'];
        if (nested is Map) {
          return _toIntMap(nested);
        }
      }
    } on Object {
      return const <String, int>{};
    }

    return const <String, int>{};
  }

  static Map<String, int> _toIntMap(Map<dynamic, dynamic> raw) {
    final out = <String, int>{};
    raw.forEach((key, value) {
      if (key is! String || value is! int) return;
      out[key] = value;
    });
    return out;
  }
}
