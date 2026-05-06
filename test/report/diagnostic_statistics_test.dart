/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `diagnostic_statistics_test` (diagnostic statistics).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'dart:convert' show JsonEncoder;
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as path;
import 'package:saropa_lints/src/report/diagnostic_statistics.dart';
import 'package:test/test.dart';

// diagnostic_statistics: severity counts, config reset, and temp violations.json handling.

void main() {
  group('DiagnosticStatisticsEvaluator', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('saropa_stats_test_');
      DiagnosticStatisticsConfig.reset();
    });

    tearDown(() {
      DiagnosticStatisticsConfig.reset();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('evaluates warn/fail threshold breaches', () {
      DiagnosticStatisticsConfig.setThresholds(
        warn: {'avoid_print': 50},
        fail: {'avoid_hardcoded_credentials': 0},
      );

      final result = DiagnosticStatisticsEvaluator.evaluate(
        projectRoot: tempDir.path,
        issuesByRule: {'avoid_print': 60, 'avoid_hardcoded_credentials': 1},
      );

      expect(result.thresholds.warnings, hasLength(1));
      expect(result.thresholds.warnings.single.rule, 'avoid_print');
      expect(result.thresholds.failures, hasLength(1));
      expect(
        result.thresholds.failures.single.rule,
        'avoid_hardcoded_credentials',
      );
    });

    test('supports metadata threshold keys for ruleType and ruleStatus', () {
      DiagnosticStatisticsConfig.setThresholds(
        warn: {'ruleType.vulnerability': 0},
        fail: {'ruleStatus.ready': 0},
      );

      final result = DiagnosticStatisticsEvaluator.evaluate(
        projectRoot: tempDir.path,
        issuesByRule: {'avoid_hardcoded_credentials': 1},
      );

      expect(result.thresholds.warnings, hasLength(1));
      expect(result.thresholds.warnings.single.rule, 'ruleType.vulnerability');
      expect(result.thresholds.failures, hasLength(1));
      expect(result.thresholds.failures.single.rule, 'ruleStatus.ready');
    });

    test('computes baseline deltas from a baseline snapshot file', () {
      final baselinePath = path.join(tempDir.path, 'diag_baseline.json');
      final baselineFile = File(baselinePath);
      baselineFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'issuesByRule': {'rule_a': 3, 'rule_b': 10},
        }),
      );
      DiagnosticStatisticsConfig.setBaselinePath(baselinePath);

      final result = DiagnosticStatisticsEvaluator.evaluate(
        projectRoot: tempDir.path,
        issuesByRule: {'rule_a': 5, 'rule_b': 8, 'rule_c': 4},
      );

      expect(result.baseline.enabled, isTrue);
      expect(result.baseline.baselineFound, isTrue);
      expect(result.baseline.totalNewViolations, 6);
      expect(result.baseline.byRule, {'rule_a': 2, 'rule_c': 4});
    });

    test('supports baseline files in violations.json shape', () {
      final baselinePath = path.join(tempDir.path, 'violations.json');
      File(baselinePath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'summary': {
            'issuesByRule': {'rule_x': 1},
          },
        }),
      );
      DiagnosticStatisticsConfig.setBaselinePath(baselinePath);

      final result = DiagnosticStatisticsEvaluator.evaluate(
        projectRoot: tempDir.path,
        issuesByRule: {'rule_x': 2},
      );

      expect(result.baseline.totalNewViolations, 1);
      expect(result.baseline.byRule, {'rule_x': 1});
    });
  });
}
