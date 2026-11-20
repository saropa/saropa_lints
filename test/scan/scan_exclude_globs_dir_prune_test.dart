/// Issue #408: `--exclude-globs` must stop the directory walk from
/// descending into a matched directory, not just filter the resulting file
/// list — otherwise an unreadable subdirectory inside an excluded path
/// (e.g. a `.Trash-0` folder under `flatpak/**`) crashes the scan with a
/// `PathAccessException` even though `--exclude-globs` was told to skip it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('scan_globs_prune_');
  });

  tearDown(() {
    safeDeleteDir(tempDir);
  });

  bool hasFile(List<String> files, String suffix) =>
      files.any((f) => f.replaceAll('\\', '/').endsWith(suffix));

  test('excluded directory is never listed, so an unreadable child inside it '
      'cannot abort the scan', () {
    File(p.join(tempDir.path, 'lib', 'app.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void f() {}\n');
    // A readable stand-in for the unreadable OS trash dir from #408 — the
    // regression is that the walk must never call listSync on anything
    // under `flatpak/**` at all, so an inaccessible child never gets reached.
    File(p.join(tempDir.path, 'flatpak', 'build', 'var', 'run', 'y.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void y() {}\n');

    final files = ScanRunner.discoverDartFiles(
      tempDir.path,
      excludeGlobs: ['**/flatpak/**'],
    );

    expect(hasFile(files, 'lib/app.dart'), isTrue);
    expect(hasFile(files, 'flatpak/build/var/run/y.dart'), isFalse);
  });
}
