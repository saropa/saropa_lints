/// Issue #405: `--exclude-globs` / `--include-globs` patterns match relative
/// to the scanned folder, not only against the full listed path.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory tempDir;
  late Directory originalCwd;

  setUp(() {
    originalCwd = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('scan_globs_relative_');
    for (final rel in [
      'lib/app.dart',
      'packages/a/lib/x.dart',
      'tool/gen/y.dart',
    ]) {
      final f = File(p.join(tempDir.path, rel))..createSync(recursive: true);
      f.writeAsStringSync('void f() {}\n');
    }
  });

  tearDown(() {
    Directory.current = originalCwd;
    safeDeleteDir(tempDir);
  });

  bool hasFile(List<String> files, String suffix) =>
      files.any((f) => f.replaceAll('\\', '/').endsWith(suffix));

  test('packages/** excludes ./packages/... when scanning "."', () {
    Directory.current = tempDir.path;
    final files = ScanRunner.discoverDartFiles(
      '.',
      excludeGlobs: ['packages/**'],
    );
    expect(hasFile(files, 'packages/a/lib/x.dart'), isFalse);
    expect(hasFile(files, 'lib/app.dart'), isTrue);
  });

  test('packages/** excludes under an absolute target path', () {
    final files = ScanRunner.discoverDartFiles(
      tempDir.path,
      excludeGlobs: ['packages/**'],
    );
    expect(hasFile(files, 'packages/a/lib/x.dart'), isFalse);
    expect(hasFile(files, 'lib/app.dart'), isTrue);
  });

  test('**/packages/** still works', () {
    Directory.current = tempDir.path;
    final files = ScanRunner.discoverDartFiles(
      '.',
      excludeGlobs: ['**/packages/**'],
    );
    expect(hasFile(files, 'packages/a/lib/x.dart'), isFalse);
    expect(hasFile(files, 'lib/app.dart'), isTrue);
  });

  test('a non-matching pattern keeps every file', () {
    Directory.current = tempDir.path;
    final files = ScanRunner.discoverDartFiles('.', excludeGlobs: ['other/**']);
    expect(files, hasLength(3));
  });

  test('a relative include-glob overrides a hardcoded exclusion', () {
    File(p.join(tempDir.path, 'generated', 'z.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void z() {}\n');
    Directory.current = tempDir.path;
    expect(
      hasFile(ScanRunner.discoverDartFiles('.'), 'generated/z.dart'),
      isFalse,
    );
    final files = ScanRunner.discoverDartFiles(
      '.',
      includeGlobs: ['generated/**'],
    );
    expect(hasFile(files, 'generated/z.dart'), isTrue);
  });
}
