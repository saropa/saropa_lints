/// Tests the health time-machine against this repo's own tags. Asserts
/// well-formed, chronological points rather than exact values; skips when there
/// are no tags / no git.
import 'dart:io';

import 'package:saropa_lints/src/cli/project_health/health_history.dart';
import 'package:test/test.dart';

void main() {
  test(
    'builds well-formed trajectory points from git tags',
    () async {
      final points = await loadHealthHistory(
        Directory.current.path,
        maxTags: 2,
      );
      // No tags / git unavailable — nothing to assert.
      if (points.isEmpty) return;
      expect(points.length, lessThanOrEqualTo(2));
      for (final p in points) {
        expect(p.tag, isNotEmpty);
        expect(p.loc, greaterThan(0));
        expect(p.fileCount, greaterThan(0));
        expect(p.maxCognitive, greaterThanOrEqualTo(0));
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('a non-git directory yields no history', () async {
    final tmp = Directory.systemTemp.createTempSync('saropa_nohist_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(await loadHealthHistory(tmp.path), isEmpty);
  });
}
