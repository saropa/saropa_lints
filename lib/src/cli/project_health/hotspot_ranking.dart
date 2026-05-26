/// Hot-spot ranking: 🔥 the files that are bad on MULTIPLE axes at once.
///
/// Operates on the aggregator's bounded top-N lists (not the full row set), so
/// it stays memory-flat. A file's fire count = how many distinct "badness"
/// axes it tops (size, complexity, low maintainability). Files topping several
/// axes are the real refactoring priorities — this is the dashboard's headline.
library;

import 'health_aggregator.dart';
import 'health_model.dart';

/// A flagged file plus why it was flagged.
class Hotspot {
  Hotspot(this.file);

  final FileHealth file;

  /// Distinct axes this file tops, e.g. `large`, `complex`, `low-maintainability`.
  final List<String> reasons = [];

  /// One 🔥 per axis topped (capped at the number of axes considered).
  int get fire => reasons.length;
}

/// Ranks hot spots from [agg]'s top-N lists. Size is always available; the
/// complexity axes contribute only when the complexity section ran. Returns
/// files sorted by fire count (desc), then LOC (desc), then path (stable).
List<Hotspot> rankHotspots(HealthAggregator agg) {
  final byPath = <String, Hotspot>{};
  void mark(List<FileHealth> files, String reason) {
    for (final f in files) {
      (byPath[f.path] ??= Hotspot(f)).reasons.add(reason);
    }
  }

  // Bytes is intentionally omitted as an axis: it is highly correlated with LOC,
  // so counting both would double-weight "big file" and distort fire counts.
  mark(agg.topByLoc(), 'large');
  mark(agg.topByCognitive(), 'complex');
  mark(agg.worstMaintainability(), 'low-maintainability');
  mark(agg.deadFiles(), 'dead');
  mark(agg.topByChurn(), 'churning');
  // Coverage axis is threshold-gated: a file in the bottom-N is only "uncovered"
  // if it is actually poorly covered, not merely the least-covered of a well-
  // tested project.
  for (final f in agg.lowestCoverage()) {
    if ((f.coveragePct ?? 1.0) < 0.5) {
      (byPath[f.path] ??= Hotspot(f)).reasons.add('uncovered');
    }
  }

  final spots = byPath.values.toList();
  spots.sort((a, b) {
    final byFire = b.fire.compareTo(a.fire);
    if (byFire != 0) return byFire;
    final byLoc = b.file.loc.compareTo(a.file.loc);
    if (byLoc != 0) return byLoc;
    return a.file.path.compareTo(b.file.path); // stable tiebreak
  });
  return spots;
}

/// `🔥` repeated [count] times (empty for 0). Used in text/markdown output.
String fireEmoji(int count) => '🔥' * count;
