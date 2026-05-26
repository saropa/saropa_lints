/// Tests for hot-spot ranking (multi-axis fire counts, deterministic order)
/// and the Markdown AI-fix worklist export.
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_export_markdown.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/hotspot_ranking.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

FileHealth _file(
  String path,
  int loc, {
  int cognitive = 0,
  double maintainability = 100,
}) => FileHealth(
  path: path,
  bytes: loc * 10,
  loc: loc,
  codeLoc: loc,
  commentLoc: 0,
  blankLoc: 0,
  complexity: FileComplexity(
    functionCount: 1,
    maxCyclomatic: cognitive,
    maxCognitive: cognitive,
    maxVariableCount: 0,
    maxBooleanTerms: 0,
    maxNesting: 0,
    worstLcom: 0,
  ),
  maintainability: maintainability,
);

void main() {
  group('rankHotspots', () {
    test('a file bad on all axes outranks a file bad on one', () {
      final agg = HealthAggregator(topN: 5)
        // worst on size + complexity + maintainability
        ..add(_file('triple.dart', 5000, cognitive: 200, maintainability: 2))
        // only large
        ..add(_file('single.dart', 4000, cognitive: 1, maintainability: 95));
      final spots = rankHotspots(agg);
      expect(spots.first.file.path, 'triple.dart');
      expect(spots.first.fire, 3);
    });

    test('ranking is deterministic across identical runs', () {
      List<String> run() {
        final agg = HealthAggregator(topN: 5)
          ..add(_file('a.dart', 100, cognitive: 50, maintainability: 10))
          ..add(_file('b.dart', 200, cognitive: 5, maintainability: 90));
        return rankHotspots(agg).map((s) => s.file.path).toList();
      }

      expect(run(), run());
    });

    test('fireEmoji repeats the flame per axis', () {
      expect(fireEmoji(3), '🔥🔥🔥');
      expect(fireEmoji(0), '');
    });

    test('dead, churn, and low-coverage each contribute a fire axis', () {
      final agg = HealthAggregator(topN: 5)
        ..add(
          const FileHealth(
            path: 'x.dart',
            bytes: 100,
            loc: 100,
            codeLoc: 100,
            commentLoc: 0,
            blankLoc: 0,
            isUnusedFile: true,
            churn: 50,
            lastCommitDaysAgo: 1,
            busFactorPct: 0.9,
            coveragePct: 0.1,
          ),
        );
      final spot = rankHotspots(agg).firstWhere((s) => s.file.path == 'x.dart');
      expect(spot.reasons, containsAll(['dead', 'churning', 'uncovered']));
    });

    test('well-covered files are not flagged uncovered', () {
      final agg = HealthAggregator(topN: 5)
        ..add(
          const FileHealth(
            path: 'ok.dart',
            bytes: 10,
            loc: 10,
            codeLoc: 10,
            commentLoc: 0,
            blankLoc: 0,
            coveragePct: 0.95,
          ),
        );
      final spot = rankHotspots(
        agg,
      ).firstWhere((s) => s.file.path == 'ok.dart');
      expect(spot.reasons, isNot(contains('uncovered')));
    });
  });

  group('buildHealthMarkdown', () {
    test('emits a checkbox worklist with metrics for each hot spot', () {
      final agg = HealthAggregator(topN: 5)
        ..add(_file('big.dart', 5000, cognitive: 150, maintainability: 3));
      final md = buildHealthMarkdown(
        rankHotspots(agg),
        projectPath: '.',
        generatedAt: DateTime.utc(2026),
        limit: 10,
      );
      expect(md, contains('# Project Health — Hot Spots'));
      expect(md, contains('big.dart'));
      expect(md, contains('- [ ]'));
      expect(md, contains('cognitive 150'));
    });
  });
}
