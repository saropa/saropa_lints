/// Tests cycle-cut selection: picks the stable→volatile edge (highest
/// fanIn(from) - fanIn(to)) and dedups equivalent cycles.
import 'package:saropa_lints/src/cli/project_health/cycle_cut.dart';
import 'package:test/test.dart';

void main() {
  group('suggestCycleCuts', () {
    test('cuts the edge from the most-depended-on to the least', () {
      // a is stable (fanIn 10), c is volatile (fanIn 1). Cycle a->b->c->a.
      // The SDP-violating edge is a->b? No: pick max fanIn(from)-fanIn(to).
      // fanIn: a=10, b=5, c=1. Edges: a->b (10-5=5), b->c (5-1=4), c->a (1-10=-9).
      // Best = a->b.
      final fan = {'a': 10, 'b': 5, 'c': 1};
      final cuts = suggestCycleCuts(
        [
          ['a', 'b', 'c'],
        ],
        fanIn: (n) => fan[n]!,
        toRel: (n) => n,
      );
      expect(cuts, hasLength(1));
      expect(cuts.single.from, 'a');
      expect(cuts.single.to, 'b');
      expect(cuts.single.cycle, ['a', 'b', 'c']);
    });

    test('deduplicates cycles that are the same set of files', () {
      final cuts = suggestCycleCuts(
        [
          ['a', 'b'],
          ['b', 'a'], // same cycle, rotated
        ],
        fanIn: (_) => 1,
        toRel: (n) => n,
      );
      expect(cuts, hasLength(1));
    });

    test('ignores degenerate cycles shorter than 2', () {
      final cuts = suggestCycleCuts(
        [
          ['a'],
        ],
        fanIn: (_) => 1,
        toRel: (n) => n,
      );
      expect(cuts, isEmpty);
    });
  });
}
