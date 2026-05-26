/// Tests for the bounded streaming aggregator: folder rollups, project totals,
/// and deterministic top-N selection.
import 'package:saropa_lints/src/cli/project_health/health_aggregator.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:test/test.dart';

FileHealth _file(String path, int loc, int bytes) => FileHealth(
  path: path,
  bytes: bytes,
  loc: loc,
  codeLoc: loc,
  commentLoc: 0,
  blankLoc: 0,
);

void main() {
  group('HealthAggregator', () {
    test('totals sum across all files', () {
      final agg = HealthAggregator()
        ..add(_file('lib/a.dart', 10, 100))
        ..add(_file('lib/src/b.dart', 20, 200))
        ..add(_file('c.dart', 5, 50));
      expect(agg.fileCount, 3);
      expect(agg.totalLoc, 35);
      expect(agg.totalBytes, 350);
    });

    test('folder rollups accumulate into every ancestor including root', () {
      final agg = HealthAggregator()
        ..add(_file('lib/a.dart', 10, 100))
        ..add(_file('lib/src/b.dart', 20, 200))
        ..add(_file('c.dart', 5, 50));
      final byPath = {for (final f in agg.folders()) f.path: f};

      expect(byPath['.']!.fileCount, 3);
      expect(byPath['.']!.loc, 35);
      expect(byPath['lib']!.fileCount, 2); // a.dart + src/b.dart
      expect(byPath['lib']!.loc, 30);
      expect(byPath['lib/src']!.fileCount, 1);
      expect(byPath['lib/src']!.loc, 20);
    });

    test('top-N keeps the largest by LOC, descending, and bounds memory', () {
      final agg = HealthAggregator(topN: 2)
        ..add(_file('a.dart', 10, 10))
        ..add(_file('b.dart', 30, 10))
        ..add(_file('c.dart', 20, 10));
      final top = agg.topByLoc();
      expect(top.map((f) => f.path), ['b.dart', 'c.dart']); // 30, 20; a dropped
    });

    test('top-N by bytes is independent of top-N by LOC', () {
      final agg = HealthAggregator(topN: 1)
        ..add(_file('big-loc.dart', 100, 10))
        ..add(_file('big-bytes.dart', 5, 9999));
      expect(agg.topByLoc().single.path, 'big-loc.dart');
      expect(agg.topByBytes().single.path, 'big-bytes.dart');
    });

    test('selection is deterministic across identical runs', () {
      List<String> run() {
        final agg = HealthAggregator(topN: 2)
          ..add(_file('a.dart', 10, 10))
          ..add(_file('b.dart', 30, 10))
          ..add(_file('c.dart', 20, 10));
        return agg.topByLoc().map((f) => f.path).toList();
      }

      expect(run(), run());
    });
  });
}
