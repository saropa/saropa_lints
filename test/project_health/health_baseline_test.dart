/// Tests baseline comparison: regressions (worse) vs improvements (better),
/// and JSON round-trip.
import 'dart:convert';

import 'package:saropa_lints/src/cli/project_health/health_baseline.dart';
import 'package:test/test.dart';

HealthBaseline _b({
  int maxCognitive = 50,
  int deadFiles = 2,
  int deadSymbols = 10,
  double? averageCoverage = 0.6,
}) => HealthBaseline(
  fileCount: 100,
  totalLoc: 10000,
  maxCognitive: maxCognitive,
  deadFiles: deadFiles,
  deadSymbols: deadSymbols,
  averageCoverage: averageCoverage,
);

void main() {
  group('compareBaseline', () {
    test('rising complexity and dead code are regressions', () {
      final cmp = compareBaseline(
        _b(maxCognitive: 50, deadFiles: 2),
        _b(maxCognitive: 80, deadFiles: 5),
      );
      expect(cmp.hasRegression, isTrue);
      expect(cmp.regressions.join(), contains('max cognitive complexity'));
      expect(cmp.regressions.join(), contains('dead files'));
    });

    test('falling coverage is a regression; rising is an improvement', () {
      final worse = compareBaseline(
        _b(averageCoverage: 0.6),
        _b(averageCoverage: 0.4),
      );
      expect(worse.regressions.join(), contains('average coverage'));
      final better = compareBaseline(
        _b(averageCoverage: 0.4),
        _b(averageCoverage: 0.6),
      );
      expect(better.improvements.join(), contains('average coverage'));
      expect(better.hasRegression, isFalse);
    });

    test('improvements are not regressions', () {
      final cmp = compareBaseline(
        _b(maxCognitive: 80, deadSymbols: 20),
        _b(maxCognitive: 50, deadSymbols: 5),
      );
      expect(cmp.hasRegression, isFalse);
      expect(cmp.improvements, isNotEmpty);
    });

    test('identical snapshots have no change', () {
      final cmp = compareBaseline(_b(), _b());
      expect(cmp.regressions, isEmpty);
      expect(cmp.improvements, isEmpty);
    });
  });

  test('JSON round-trips', () {
    final original = _b(maxCognitive: 77, averageCoverage: 0.42);
    final restored = HealthBaseline.fromJson(
      jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
    );
    expect(restored.maxCognitive, 77);
    expect(restored.averageCoverage, closeTo(0.42, 0.0001));
  });
}
