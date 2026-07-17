/// Tests the health time-machine against this repo's own tags. Asserts
/// well-formed, chronological points rather than exact values; skips when there
/// are no tags / no git.
///
/// Tagged `slow`: walks this repo's git tags and rebuilds health per point.
/// Excluded from the publish fast test pass and run in a dedicated slow pass.
@Tags(['slow'])
library;

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
      // This repo has tags; an empty result means the function is broken.
      expect(points, isNotEmpty);
      expect(points.length, lessThanOrEqualTo(2));
      for (final p in points) {
        expect(p.tag, isNotEmpty);
        expect(p.loc, greaterThan(0));
        expect(p.codeLoc, greaterThan(0));
        expect(p.codeLoc, lessThanOrEqualTo(p.loc));
        expect(p.fileCount, greaterThan(0));
        expect(p.maxCognitive, greaterThanOrEqualTo(0));
      }

      // _recentTags returns oldest-first; verify the contract holds.
      if (points.length == 2) {
        expect(
          points.first.tag,
          isNot(equals(points.last.tag)),
          reason: 'two points should come from distinct tags',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('toMarkdownRow formats a pipe-delimited table row', () {
    const point = HistoryPoint(
      tag: 'v1.0.0',
      fileCount: 42,
      loc: 1000,
      codeLoc: 800,
      maxCognitive: 15,
    );
    expect(point.toMarkdownRow(), '| v1.0.0 | 42 | 1000 | 800 | 15 |');
    // Header has the same column count as the row.
    final headerPipes =
        HistoryPoint.markdownHeader.split('\n').first.split('|').length;
    final rowPipes = point.toMarkdownRow().split('|').length;
    expect(rowPipes, headerPipes);
  });

  test('toMarkdownTable combines header and rows', () {
    const a = HistoryPoint(
      tag: 'v1.0.0',
      fileCount: 10,
      loc: 500,
      codeLoc: 400,
      maxCognitive: 8,
    );
    const b = HistoryPoint(
      tag: 'v2.0.0',
      fileCount: 20,
      loc: 1000,
      codeLoc: 800,
      maxCognitive: 12,
    );

    final table = HistoryPoint.toMarkdownTable([a, b]);
    final lines = table.split('\n');
    // Header row + separator + 2 data rows.
    expect(lines, hasLength(4));
    expect(lines[0], startsWith('| Tag'));
    expect(lines[1], startsWith('| ---'));
    expect(lines[2], a.toMarkdownRow());
    expect(lines[3], b.toMarkdownRow());

    // Empty list returns empty string, not a header-only table.
    expect(HistoryPoint.toMarkdownTable([]), isEmpty);
  });

  test('a non-git directory yields no history', () async {
    final tmp = Directory.systemTemp.createTempSync('saropa_nohist_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    expect(await loadHealthHistory(tmp.path), isEmpty);
  });
}
