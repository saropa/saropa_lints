import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:saropa_lints/src/cli/project_health/perf_gravity.dart';
import 'package:test/test.dart';

/// Tests for per-feature performance gravity — especially the property that the
/// score is INDEPENDENT of file count (the corrected behavior; the tool this was
/// adapted from divided by file count, so harmless files lowered the score).
void main() {
  group('gravityScore', () {
    test('zero weight scores zero', () {
      expect(gravityScore(0), 0);
      expect(gravityScore(-5), 0);
    });

    test('is monotonic non-decreasing in weight', () {
      var previous = -1;
      for (final w in [10, 25, 50, 87, 100, 150, 200, 400]) {
        final score = gravityScore(w);
        expect(score, greaterThanOrEqualTo(previous));
        previous = score;
      }
    });

    test('maps reference weights to the documented bands', () {
      // One medium pattern (50) → MEDIUM; one worst pattern (100) → HIGH;
      // two worst (200) → CRITICAL. Pins the decay constant.
      expect(gravityBand(gravityScore(50)), GravityBand.medium);
      expect(gravityBand(gravityScore(100)), GravityBand.high);
      expect(gravityBand(gravityScore(200)), GravityBand.critical);
    });

    test('saturates at 100 and never exceeds it', () {
      expect(gravityScore(100000), lessThanOrEqualTo(100));
      expect(gravityScore(100000), greaterThan(95));
    });
  });

  group('featureOf', () {
    test('extracts the folder under a features root', () {
      expect(featureOf('lib/features/checkout/page.dart'), 'checkout');
      expect(featureOf('lib/modules/billing/x/y.dart'), 'billing');
      expect(featureOf('lib/feature/home/home.dart'), 'home');
    });

    test('falls back to the top-level lib directory', () {
      expect(featureOf('lib/widgets/button.dart'), 'widgets');
    });

    test('buckets files outside lib under their first segment', () {
      expect(featureOf('bin/tool.dart'), 'bin');
    });
  });

  group(
    'PerfGravityAggregator — file-count independence (the dilution fix)',
    () {
      test('same weight scores the same regardless of pattern-free files', () {
        // Feature A: one file carrying weight 100.
        final lean = PerfGravityAggregator()
          ..add(
            'lib/features/a/page.dart',
            const PerfFileScan(weight: 100, patternCount: 1),
          );

        // Feature B: the identical pattern plus four harmless files.
        final padded = PerfGravityAggregator()
          ..add(
            'lib/features/b/page.dart',
            const PerfFileScan(weight: 100, patternCount: 1),
          )
          ..add('lib/features/b/e1.dart', PerfFileScan.empty)
          ..add('lib/features/b/e2.dart', PerfFileScan.empty)
          ..add('lib/features/b/e3.dart', PerfFileScan.empty)
          ..add('lib/features/b/e4.dart', PerfFileScan.empty);

        final leanScore = lean.features().single.score;
        final paddedFeature = padded.features().single;

        // Adding 4 empty files must NOT change the score, only the file count.
        expect(paddedFeature.score, leanScore);
        expect(paddedFeature.fileCount, 5);
        expect(paddedFeature.patternCount, 1);
      });

      test('omits pattern-free features and sorts worst-first', () {
        final agg = PerfGravityAggregator()
          ..add('lib/features/clean/a.dart', PerfFileScan.empty)
          ..add(
            'lib/features/mild/a.dart',
            const PerfFileScan(weight: 50, patternCount: 1),
          )
          ..add(
            'lib/features/severe/a.dart',
            const PerfFileScan(weight: 200, patternCount: 2),
          );

        final features = agg.features();
        expect(features.map((f) => f.feature), ['severe', 'mild']);
        expect(agg.hasFindings, isTrue);
      });

      test('reports no findings when nothing carries a pattern', () {
        final agg = PerfGravityAggregator()
          ..add('lib/features/a/x.dart', PerfFileScan.empty);
        expect(agg.hasFindings, isFalse);
        expect(agg.features(), isEmpty);
      });
    },
  );

  group('scanPerfGravity', () {
    test('detects a compound pattern and ignores a bare widget', () {
      // BackdropFilter inside a ListView — a compound pattern (weight > 0).
      final bad = parseString(
        content:
            "Widget b() => ListView(children: [BackdropFilter(filter: f, child: x)]);",
        throwIfDiagnostics: false,
      ).unit;
      final badScan = scanPerfGravity(bad);
      expect(badScan.patternCount, 1);
      expect(badScan.weight, greaterThan(0));

      // The same widget on its own is intentionally not scored.
      final ok = parseString(
        content: "Widget b() => BackdropFilter(filter: f, child: x);",
        throwIfDiagnostics: false,
      ).unit;
      expect(scanPerfGravity(ok).patternCount, 0);
    });
  });
}
