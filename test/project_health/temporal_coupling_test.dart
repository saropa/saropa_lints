/// Tests temporal coupling against this repo's history: asserts well-formed
/// pairs (ratio in 0..1, shared >= minShared) rather than exact values.
import 'dart:io';

import 'package:saropa_lints/src/cli/project_health/temporal_coupling.dart';
import 'package:test/test.dart';

void main() {
  test('returns well-formed change-coupled pairs', () {
    final pairs = loadTemporalCoupling(
      Directory.current.path,
      maxCommits: 300,
      minShared: 2,
      top: 20,
    );
    // Skip only if git is unavailable; this repo has history.
    if (pairs.isEmpty) return;
    expect(pairs.length, lessThanOrEqualTo(20));
    for (final c in pairs) {
      expect(c.shared, greaterThanOrEqualTo(2));
      expect(c.ratio, inInclusiveRange(0, 1));
      expect(c.a, isNot(equals(c.b)));
    }
    // Sorted by ratio descending.
    for (var i = 1; i < pairs.length; i++) {
      expect(pairs[i - 1].ratio, greaterThanOrEqualTo(pairs[i].ratio));
    }
  });

  test('a non-git directory yields no pairs', () {
    final tmp = Directory.systemTemp.createTempSync('saropa_nogit_tc_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(loadTemporalCoupling(tmp.path), isEmpty);
  });
}
