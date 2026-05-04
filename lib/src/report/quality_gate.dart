/// Loads `saropa_quality_gate.yaml` (or JSON), parses conditions, and evaluates
/// them against a violations report **summary** map (not full issue list).
///
/// Used by the `quality_gate` executable. Metric names and operators are matched
/// explicitly in [QualityGateEvaluator._resolveMetric] and [_supportedOperators];
/// unknown metrics resolve to `0` so mis-typed keys fail closed only if the
/// condition compares away from zero.
library;

import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// One threshold row from config: which metric, comparison, bound, and severity.
class QualityGateCondition {
  const QualityGateCondition({
    required this.metric,
    required this.operatorName,
    required this.value,
    required this.onFail,
  });

  /// Summary key family, e.g. `new_critical_issues`, `overall_bugs`.
  final String metric;

  /// Short operator token: `eq`, `ne`, `gt`, `ge`, `lt`, `le`.
  final String operatorName;

  /// Right-hand side of the comparison (numeric).
  final num value;

  /// `fail` exits non-zero on breach; `warn` prints but may still pass overall.
  final String onFail;
}

/// Parsed `quality_gate.conditions` list (possibly empty).
class QualityGateConfig {
  const QualityGateConfig({required this.conditions});

  /// Ordered conditions; invalid entries are dropped at parse time.
  final List<QualityGateCondition> conditions;

  /// True when there is nothing to evaluate (treated as pass by callers).
  bool get isEmpty => conditions.isEmpty;
}

/// A single failed condition after evaluation against live summary numbers.
class QualityGateBreach {
  const QualityGateBreach({
    required this.condition,
    required this.actualValue,
    required this.message,
  });

  /// The condition that was not satisfied.
  final QualityGateCondition condition;

  /// Observed metric value from the summary (left-hand side).
  final num actualValue;

  /// Human-readable message for logs / CI.
  final String message;
}

/// Full evaluation outcome: breaches plus parse-time config errors.
class QualityGateResult {
  const QualityGateResult({required this.breaches, required this.configErrors});

  /// Failed conditions (empty if all passed).
  final List<QualityGateBreach> breaches;

  /// Unsupported operators or other config issues (non-empty ⇒ treat as failure).
  final List<String> configErrors;

  /// True if any breach has `on_fail: fail` or any config error exists.
  bool get hasFailures =>
      breaches.any((b) => b.condition.onFail == 'fail') ||
      configErrors.isNotEmpty;

  /// True when there are only `warn` breaches and no failures/errors.
  bool get hasWarnings =>
      breaches.any((b) => b.condition.onFail == 'warn') && !hasFailures;

  /// Coarse status string for APIs: `fail`, `warn`, or `pass`.
  String get status => hasFailures
      ? 'fail'
      : hasWarnings
      ? 'warn'
      : 'pass';
}

/// Static helpers: parse config from YAML/JSON map or file, then [evaluate].
class QualityGateEvaluator {
  QualityGateEvaluator._();

  /// Operators accepted in config; anything else becomes a [configErrors] entry.
  static const Set<String> _supportedOperators = <String>{
    'eq',
    'ne',
    'gt',
    'ge',
    'lt',
    'le',
  };

  /// Display symbols for breach messages (fallback to raw token if missing).
  static const Map<String, String> _operatorSymbols = <String, String>{
    'eq': '==',
    'ne': '!=',
    'gt': '>',
    'ge': '>=',
    'lt': '<',
    'le': '<=',
  };

  /// Parse `quality_gate` from an already-decoded JSON-like map.
  ///
  /// Skips list entries missing metric, op, numeric value, or valid `on_fail`.
  static QualityGateConfig parseConfigMap(Map<String, dynamic> rawConfig) {
    final root = rawConfig['quality_gate'];
    if (root is! Map) return const QualityGateConfig(conditions: []);
    final conditionsRaw = root['conditions'];
    if (conditionsRaw is! List) return const QualityGateConfig(conditions: []);

    final conditions = <QualityGateCondition>[];
    for (final item in conditionsRaw) {
      if (item is! Map) continue;
      final metric = item['metric']?.toString().trim();
      final op = item['op']?.toString().trim();
      final onFailRaw = item['on_fail']?.toString().trim().toLowerCase();
      final valueRaw = item['value'];
      final numericValue = valueRaw is num
          ? valueRaw
          : num.tryParse('$valueRaw');

      if (metric == null || metric.isEmpty) continue;
      if (op == null || op.isEmpty) continue;
      if (numericValue == null) continue;
      if (onFailRaw != 'fail' && onFailRaw != 'warn') continue;

      conditions.add(
        QualityGateCondition(
          metric: metric,
          operatorName: op,
          value: numericValue,
          onFail: onFailRaw!,
        ),
      );
    }

    return QualityGateConfig(conditions: conditions);
  }

  /// Load config from [configPath] relative to [projectRoot] unless absolute.
  ///
  /// Returns empty config if file missing or unreadable (callers may exit 0).
  static QualityGateConfig parseConfigFile({
    required String projectRoot,
    required String configPath,
  }) {
    final resolved = path.normalize(
      path.isAbsolute(configPath)
          ? configPath
          : path.join(projectRoot, configPath),
    );
    final file = File(resolved);
    if (!file.existsSync()) {
      return const QualityGateConfig(conditions: []);
    }
    try {
      final content = file.readAsStringSync();
      if (_isLikelyYaml(configPath)) {
        final parsedYaml = loadYaml(content);
        if (parsedYaml is! YamlMap) {
          return const QualityGateConfig(conditions: []);
        }

        final map = _yamlMapToPlainMap(parsedYaml);
        return parseConfigMap(map);
      }

      final raw = jsonDecode(content);
      if (raw is! Map) return const QualityGateConfig(conditions: []);
      return parseConfigMap(
        Map<String, dynamic>.from(raw.cast<String, dynamic>()),
      );
    } on Object {
      return const QualityGateConfig(conditions: []);
    }
  }

  /// Heuristic: extension decides YAML vs JSON decode path.
  static bool _isLikelyYaml(String configPath) {
    final lower = configPath.toLowerCase();
    return lower.endsWith('.yaml') || lower.endsWith('.yml');
  }

  /// Recursively convert [YamlMap] to plain `Map<String, dynamic>` for parsing.
  static Map<String, dynamic> _yamlMapToPlainMap(YamlMap yamlMap) {
    final result = <String, dynamic>{};
    for (final entry in yamlMap.entries) {
      final key = '${entry.key}';
      final value = entry.value;
      if (value is YamlMap) {
        result[key] = _yamlMapToPlainMap(value);
      } else if (value is YamlList) {
        result[key] = _yamlListToPlainList(value);
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  /// Nested YAML lists to plain Dart lists (maps inside lists recurse).
  static List<dynamic> _yamlListToPlainList(YamlList yamlList) {
    return yamlList
        .map((value) {
          if (value is YamlMap) return _yamlMapToPlainMap(value);
          if (value is YamlList) return _yamlListToPlainList(value);
          return value;
        })
        .toList(growable: false);
  }

  /// Evaluate every condition; unsupported ops append to [configErrors] instead of breaching.
  static QualityGateResult evaluate({
    required Map<String, dynamic> summary,
    required QualityGateConfig config,
  }) {
    if (config.isEmpty) {
      return const QualityGateResult(
        breaches: <QualityGateBreach>[],
        configErrors: <String>[],
      );
    }

    final breaches = <QualityGateBreach>[];
    final configErrors = <String>[];

    for (final condition in config.conditions) {
      final op = condition.operatorName;
      if (!_supportedOperators.contains(op)) {
        configErrors.add(
          'Unsupported operator "${condition.operatorName}" for metric "${condition.metric}".',
        );
        continue;
      }

      final actual = _resolveMetric(summary, condition.metric);
      final passed = _compare(actual, op, condition.value);
      if (passed) continue;

      final symbol = _operatorSymbols[op] ?? op;
      breaches.add(
        QualityGateBreach(
          condition: condition,
          actualValue: actual,
          message:
              '${condition.metric} ($actual) must be $symbol ${condition.value}',
        ),
      );
    }

    return QualityGateResult(breaches: breaches, configErrors: configErrors);
  }

  /// Map a metric name to a number from nested summary sections (`byImpact`, `newCode`, …).
  static num _resolveMetric(Map<String, dynamic> summary, String metric) {
    final byImpact = (summary['byImpact'] as Map?) ?? const <String, dynamic>{};
    final byRuleType =
        (summary['byRuleType'] as Map?) ?? const <String, dynamic>{};
    final byRuleStatus =
        (summary['byRuleStatus'] as Map?) ?? const <String, dynamic>{};
    final newCode = (summary['newCode'] as Map?) ?? const <String, dynamic>{};
    final newByImpact =
        (newCode['byImpact'] as Map?) ?? const <String, dynamic>{};
    final newByRuleType =
        (newCode['byRuleType'] as Map?) ?? const <String, dynamic>{};
    final newByRuleStatus =
        (newCode['byRuleStatus'] as Map?) ?? const <String, dynamic>{};

    switch (metric) {
      // New severity-keyed metrics (post-LintImpact-collapse, 2026-05-03).
      case 'new_errors':
      case 'new_critical_issues': // Back-compat alias for the old 5-bucket name.
        return _asNum(newByImpact['error']);
      case 'new_warnings':
      case 'new_high_issues': // Back-compat alias.
      case 'new_medium_issues': // Back-compat alias (medium merged into warning).
        return _asNum(newByImpact['warning']);
      case 'new_info':
      case 'new_low_issues': // Back-compat alias (low merged into info).
        return _asNum(newByImpact['info']);
      case 'new_vulnerabilities':
        return _asNum(newByRuleType['vulnerability']);
      case 'new_security_hotspots':
        return _asNum(newByRuleType['securityHotspot']);
      case 'new_code_smells':
        return _asNum(newByRuleType['codeSmell']);
      case 'new_bugs':
        return _asNum(newByRuleType['bug']);
      case 'overall_errors':
      case 'overall_critical_issues': // Back-compat alias.
        return _asNum(byImpact['error']);
      case 'overall_warnings':
      case 'overall_high_issues': // Back-compat alias.
      case 'overall_medium_issues': // Back-compat alias.
        return _asNum(byImpact['warning']);
      case 'overall_info':
      case 'overall_low_issues': // Back-compat alias.
        return _asNum(byImpact['info']);
      case 'overall_vulnerabilities':
        return _asNum(byRuleType['vulnerability']);
      case 'overall_security_hotspots':
        return _asNum(byRuleType['securityHotspot']);
      case 'overall_code_smells':
        return _asNum(byRuleType['codeSmell']);
      case 'overall_bugs':
        return _asNum(byRuleType['bug']);
      case 'overall_beta_rules':
        return _asNum(byRuleStatus['beta']);
      case 'new_beta_rules':
        return _asNum(newByRuleStatus['beta']);
      default:
        return 0;
    }
  }

  static num _asNum(Object? value) => value is num ? value : 0;

  /// Compare [actual] to [expected] using [operatorName]; unknown op returns true (no breach).
  static bool _compare(num actual, String operatorName, num expected) {
    switch (operatorName) {
      case 'eq':
        return actual == expected;
      case 'ne':
        return actual != expected;
      case 'gt':
        return actual > expected;
      case 'ge':
        return actual >= expected;
      case 'lt':
        return actual < expected;
      case 'le':
        return actual <= expected;
      default:
        return true;
    }
  }
}
