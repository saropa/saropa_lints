import 'dart:convert' show jsonDecode;
import 'dart:io' show File;

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class QualityGateCondition {
  const QualityGateCondition({
    required this.metric,
    required this.operatorName,
    required this.value,
    required this.onFail,
  });

  final String metric;
  final String operatorName;
  final num value;
  final String onFail;
}

class QualityGateConfig {
  const QualityGateConfig({required this.conditions});

  final List<QualityGateCondition> conditions;

  bool get isEmpty => conditions.isEmpty;
}

class QualityGateBreach {
  const QualityGateBreach({
    required this.condition,
    required this.actualValue,
    required this.message,
  });

  final QualityGateCondition condition;
  final num actualValue;
  final String message;
}

class QualityGateResult {
  const QualityGateResult({required this.breaches, required this.configErrors});

  final List<QualityGateBreach> breaches;
  final List<String> configErrors;

  bool get hasFailures =>
      breaches.any((b) => b.condition.onFail == 'fail') ||
      configErrors.isNotEmpty;

  bool get hasWarnings =>
      breaches.any((b) => b.condition.onFail == 'warn') && !hasFailures;

  String get status => hasFailures
      ? 'fail'
      : hasWarnings
      ? 'warn'
      : 'pass';
}

class QualityGateEvaluator {
  QualityGateEvaluator._();

  static const Set<String> _supportedOperators = <String>{
    'eq',
    'ne',
    'gt',
    'ge',
    'lt',
    'le',
  };

  static const Map<String, String> _operatorSymbols = <String, String>{
    'eq': '==',
    'ne': '!=',
    'gt': '>',
    'ge': '>=',
    'lt': '<',
    'le': '<=',
  };

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

  static bool _isLikelyYaml(String configPath) {
    final lower = configPath.toLowerCase();
    return lower.endsWith('.yaml') || lower.endsWith('.yml');
  }

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

  static List<dynamic> _yamlListToPlainList(YamlList yamlList) {
    return yamlList
        .map((value) {
          if (value is YamlMap) return _yamlMapToPlainMap(value);
          if (value is YamlList) return _yamlListToPlainList(value);
          return value;
        })
        .toList(growable: false);
  }

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
      case 'new_critical_issues':
        return _asNum(newByImpact['critical']);
      case 'new_high_issues':
        return _asNum(newByImpact['high']);
      case 'new_medium_issues':
        return _asNum(newByImpact['medium']);
      case 'new_low_issues':
        return _asNum(newByImpact['low']);
      case 'new_vulnerabilities':
        return _asNum(newByRuleType['vulnerability']);
      case 'new_security_hotspots':
        return _asNum(newByRuleType['securityHotspot']);
      case 'new_code_smells':
        return _asNum(newByRuleType['codeSmell']);
      case 'new_bugs':
        return _asNum(newByRuleType['bug']);
      case 'overall_critical_issues':
        return _asNum(byImpact['critical']);
      case 'overall_high_issues':
        return _asNum(byImpact['high']);
      case 'overall_medium_issues':
        return _asNum(byImpact['medium']);
      case 'overall_low_issues':
        return _asNum(byImpact['low']);
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
