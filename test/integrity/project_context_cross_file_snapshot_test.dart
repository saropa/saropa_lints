/// Tests [loadCrossFileSnapshot] defensive parsing and cache invalidation.
///
/// Ensures bad on-disk JSON never throws into callers and that [clearCrossFileSnapshotCache]
/// resets state between runs so one test cannot mask another via cached null/values.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/project_context.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  tearDown(clearCrossFileSnapshotCache);

  test('malformed snapshot JSON returns null without throwing', () {
    // Arrange: file exists but is not valid JSON; cache cleared so load reads disk fresh.
    final root = Directory.systemTemp.createTempSync('saropa_snap_');
    try {
      final snapDir = Directory(p.join(root.path, 'reports', '.saropa_lints'));
      snapDir.createSync(recursive: true);
      File(
        p.join(snapDir.path, 'cross_file_snapshot.json'),
      ).writeAsStringSync('not json {');
      clearCrossFileSnapshotCache();
      expect(loadCrossFileSnapshot(root.path), isNull);
    } finally {
      // Retry-tolerant cleanup: Windows file handles can linger after tests
      safeDeleteDir(root);
      clearCrossFileSnapshotCache();
    }
  });

  test('snapshot object array is rejected (wrong top-level type)', () {
    // Arrange: valid JSON array at top level — loader expects an object map.
    final root = Directory.systemTemp.createTempSync('saropa_snap_');
    try {
      final snapDir = Directory(p.join(root.path, 'reports', '.saropa_lints'));
      snapDir.createSync(recursive: true);
      File(
        p.join(snapDir.path, 'cross_file_snapshot.json'),
      ).writeAsStringSync('[1,2]');
      clearCrossFileSnapshotCache();
      expect(loadCrossFileSnapshot(root.path), isNull);
    } finally {
      safeDeleteDir(root);
      clearCrossFileSnapshotCache();
    }
  });
}
