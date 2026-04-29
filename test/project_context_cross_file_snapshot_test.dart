import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/project_context.dart';
import 'package:test/test.dart';

void main() {
  tearDown(clearCrossFileSnapshotCache);

  test('malformed snapshot JSON returns null without throwing', () {
    final root = Directory.systemTemp.createTempSync('saropa_snap_');
    try {
      final snapDir = Directory(p.join(root.path, 'reports', '.saropa_lints'));
      snapDir.createSync(recursive: true);
      File(p.join(snapDir.path, 'cross_file_snapshot.json'))
          .writeAsStringSync('not json {');
      clearCrossFileSnapshotCache();
      expect(loadCrossFileSnapshot(root.path), isNull);
    } finally {
      root.deleteSync(recursive: true);
      clearCrossFileSnapshotCache();
    }
  });

  test('snapshot object array is rejected (wrong top-level type)', () {
    final root = Directory.systemTemp.createTempSync('saropa_snap_');
    try {
      final snapDir = Directory(p.join(root.path, 'reports', '.saropa_lints'));
      snapDir.createSync(recursive: true);
      File(p.join(snapDir.path, 'cross_file_snapshot.json'))
          .writeAsStringSync('[1,2]');
      clearCrossFileSnapshotCache();
      expect(loadCrossFileSnapshot(root.path), isNull);
    } finally {
      root.deleteSync(recursive: true);
      clearCrossFileSnapshotCache();
    }
  });
}
