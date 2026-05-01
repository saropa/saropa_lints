/// Tests [QualityGateEvaluator] and [QualityGateConfig]: YAML-like condition trees, metric thresholds,
/// pass/fail aggregation, and temp-directory config files under `setUp`/`tearDown`.
library;

import 'dart:io' show Directory, File;

import 'package:saropa_lints/src/report/quality_gate.dart';
import 'package:test/test.dart';

/// Each `group` targets one evaluator feature (operators, boundaries, error messages).
void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('quality_gate_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('QualityGateEvaluator', () {
    test('passes when all conditions are satisfied', () {
      final config = QualityGateConfig(
        conditions: const <QualityGateCondition>[
          QualityGateCondition(
            metric: 'new_critical_issues',
            operatorName: 'eq',
            value: 0,
            onFail: 'fail',
          ),
          QualityGateCondition(
            metric: 'new_vulnerabilities',
            operatorName: 'eq',
            value: 0,
            onFail: 'fail',
          ),
        ],
      );

      final result = QualityGateEvaluator.evaluate(
        summary: _summary(
          byImpact: const {'critical': 1},
          byRuleType: const {'vulnerability': 1},
          newByImpact: const {'critical': 0},
          newByRuleType: const {'vulnerability': 0},
        ),
        config: config,
      );

      expect(result.status, 'pass');
      expect(result.breaches, isEmpty);
      expect(result.configErrors, isEmpty);
    });

    test('fails when fail-threshold breaches', () {
      final config = QualityGateConfig(
        conditions: const <QualityGateCondition>[
          QualityGateCondition(
            metric: 'new_critical_issues',
            operatorName: 'eq',
            value: 0,
            onFail: 'fail',
          ),
        ],
      );

      final result = QualityGateEvaluator.evaluate(
        summary: _summary(newByImpact: const {'critical': 2}),
        config: config,
      );

      expect(result.status, 'fail');
      expect(result.breaches, hasLength(1));
      expect(result.breaches.first.message, contains('new_critical_issues'));
    });

    test('warns when warn-threshold breaches', () {
      final config = QualityGateConfig(
        conditions: const <QualityGateCondition>[
          QualityGateCondition(
            metric: 'new_security_hotspots',
            operatorName: 'le',
            value: 1,
            onFail: 'warn',
          ),
        ],
      );

      final result = QualityGateEvaluator.evaluate(
        summary: _summary(newByRuleType: const {'securityHotspot': 3}),
        config: config,
      );

      expect(result.status, 'warn');
      expect(result.breaches, hasLength(1));
      expect(result.hasFailures, isFalse);
    });

    test('invalid operators are returned as config errors', () {
      final config = QualityGateConfig(
        conditions: const <QualityGateCondition>[
          QualityGateCondition(
            metric: 'new_critical_issues',
            operatorName: 'bogus',
            value: 0,
            onFail: 'fail',
          ),
        ],
      );

      final result = QualityGateEvaluator.evaluate(
        summary: _summary(),
        config: config,
      );

      expect(result.status, 'fail');
      expect(result.configErrors, isNotEmpty);
    });

    test('parseConfigMap reads valid config entries', () {
      final parsed = QualityGateEvaluator.parseConfigMap({
        'quality_gate': {
          'conditions': [
            {
              'metric': 'new_vulnerabilities',
              'op': 'eq',
              'value': 0,
              'on_fail': 'fail',
            },
            {
              'metric': 'new_security_hotspots',
              'op': 'le',
              'value': 5,
              'on_fail': 'warn',
            },
          ],
        },
      });

      expect(parsed.conditions, hasLength(2));
      expect(parsed.conditions.first.metric, 'new_vulnerabilities');
      expect(parsed.conditions.last.onFail, 'warn');
    });

    test('parseConfigFile reads YAML configs', () {
      final configFile = File('${tempDir.path}/saropa_quality_gate.yaml');
      configFile.writeAsStringSync('''
quality_gate:
  conditions:
    - metric: new_vulnerabilities
      op: eq
      value: 0
      on_fail: fail
    - metric: new_security_hotspots
      op: le
      value: 5
      on_fail: warn
''');

      final parsed = QualityGateEvaluator.parseConfigFile(
        projectRoot: tempDir.path,
        configPath: configFile.path,
      );

      expect(parsed.conditions, hasLength(2));
      expect(parsed.conditions.first.metric, 'new_vulnerabilities');
      expect(parsed.conditions.last.metric, 'new_security_hotspots');
    });
  });
}

Map<String, dynamic> _summary({
  Map<String, int> byImpact = const <String, int>{},
  Map<String, int> byRuleType = const <String, int>{},
  Map<String, int> newByImpact = const <String, int>{},
  Map<String, int> newByRuleType = const <String, int>{},
}) {
  return <String, dynamic>{
    'byImpact': <String, dynamic>{...byImpact},
    'byRuleType': <String, dynamic>{...byRuleType},
    'byRuleStatus': const <String, dynamic>{},
    'newCode': <String, dynamic>{
      'byImpact': <String, dynamic>{...newByImpact},
      'byRuleType': <String, dynamic>{...newByRuleType},
      'byRuleStatus': const <String, dynamic>{},
    },
  };
}
