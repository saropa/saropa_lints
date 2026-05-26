/// Tests the refactoring-ROI score and ranking: complex + churning + uncovered
/// files outrank quiet, covered ones, and the score is deterministic.
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

FileHealth _f(
  String path, {
  int loc = 100,
  int cognitive = 0,
  int? churn,
  double? coverage,
}) => FileHealth(
  path: path,
  bytes: loc * 10,
  loc: loc,
  codeLoc: loc,
  commentLoc: 0,
  blankLoc: 0,
  churn: churn,
  coveragePct: coverage,
  complexity: FileComplexity(
    functionCount: 1,
    maxCyclomatic: cognitive,
    maxCognitive: cognitive,
    maxVariableCount: 0,
    maxBooleanTerms: 0,
    maxNesting: 0,
    worstLcom: 0,
  ),
);

void main() {
  group('roiOf', () {
    test(
      'complex + churning + uncovered scores higher than quiet + covered',
      () {
        final risky = _f(
          'risky.dart',
          cognitive: 100,
          churn: 40,
          coverage: 0.1,
        );
        final calm = _f('calm.dart', cognitive: 5, churn: 1, coverage: 0.95);
        expect(
          HealthAggregator.roiOf(risky),
          greaterThan(HealthAggregator.roiOf(calm)),
        );
      },
    );

    test('higher churn raises ROI, all else equal', () {
      final hi = _f('a.dart', cognitive: 30, churn: 50, coverage: 0.5);
      final lo = _f('b.dart', cognitive: 30, churn: 2, coverage: 0.5);
      expect(
        HealthAggregator.roiOf(hi),
        greaterThan(HealthAggregator.roiOf(lo)),
      );
    });

    test('lower coverage raises ROI, all else equal', () {
      final uncovered = _f('a.dart', cognitive: 30, coverage: 0.1);
      final covered = _f('b.dart', cognitive: 30, coverage: 0.9);
      expect(
        HealthAggregator.roiOf(uncovered),
        greaterThan(HealthAggregator.roiOf(covered)),
      );
    });
  });

  group('topByRoi', () {
    test('ranks risky files first, deterministically', () {
      List<String> run() {
        final agg = HealthAggregator(topN: 5)
          ..add(_f('calm.dart', cognitive: 5, churn: 1, coverage: 0.95))
          ..add(_f('risky.dart', cognitive: 100, churn: 40, coverage: 0.1))
          ..add(_f('mid.dart', cognitive: 30, churn: 10, coverage: 0.5));
        return agg.topByRoi().map((f) => f.path).toList();
      }

      expect(run().first, 'risky.dart');
      expect(run(), run()); // deterministic
    });
  });
}
