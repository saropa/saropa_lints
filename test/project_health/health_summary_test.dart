/// Tests the natural-language exec summary and the what-if cleanup simulator.
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/health_summary.dart';
import 'package:test/test.dart';

FileHealth _f(String path, int loc, {bool dead = false}) => FileHealth(
  path: path,
  bytes: loc * 10,
  loc: loc,
  codeLoc: loc,
  commentLoc: 0,
  blankLoc: 0,
  isUnusedFile: dead,
);

void main() {
  group('buildExecSummary', () {
    test('states files, lines, and the top hotspot', () {
      final agg = HealthAggregator()
        ..add(_f('a.dart', 1000))
        ..add(_f('b.dart', 2000));
      final s = buildExecSummary(agg, topHotspot: 'b.dart');
      expect(s, contains('2 files'));
      expect(s, contains('3,000 lines'));
      expect(s, contains('b.dart'));
    });

    test('mentions dead weight when present', () {
      final agg = HealthAggregator()
        ..add(_f('live.dart', 900))
        ..add(_f('dead.dart', 100, dead: true));
      expect(buildExecSummary(agg), contains('unused file'));
    });
  });

  group('buildWhatIf', () {
    test('quantifies removal payoff when dead files exist', () {
      final agg = HealthAggregator()
        ..add(_f('live.dart', 800))
        ..add(_f('dead.dart', 200, dead: true));
      final w = buildWhatIf(agg)!;
      expect(w, contains('200 lines'));
      expect(w, contains('20.0%')); // 200 of 1000
    });

    test('is null when nothing is dead', () {
      final agg = HealthAggregator()..add(_f('live.dart', 800));
      expect(buildWhatIf(agg), isNull);
    });
  });
}
