/// Tests for #403: the scan reads `analyzer: exclude:` from the nearest
/// `analysis_options.yaml` at or above the scanned folder. Relative glob
/// matching itself is covered by `scan_exclude_globs_relative_test.dart` (#405).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('scan_analyzer_exclude_');
    for (final f in ['lib/app.dart', 'packages/a/a.dart']) {
      File('${tempDir.path}/$f')
        ..createSync(recursive: true)
        ..writeAsStringSync('void f() {}\n');
    }
  });

  tearDown(() => safeDeleteDir(tempDir));

  File options() => File('${tempDir.path}/analysis_options.yaml');

  /// Number of files a scan of [target] reports, using analyzer excludes.
  int scannedCount(String target) {
    final messages = <String>[];
    ScanRunner(
      targetPath: target,
      tier: 'essential',
      messageSink: messages.add,
      excludeGlobs: loadAnalyzerExcludes(target),
    ).run();
    final line = messages.firstWhere((m) => m.startsWith('Scanning '));
    return int.parse(RegExp(r'Scanning (\d+)').firstMatch(line)!.group(1)!);
  }

  test('returns absolute globs from the analyzer exclude list', () {
    options().writeAsStringSync(
      'analyzer:\n  exclude:\n    - "packages/**"\n    - "**/*.g.dart"\n',
    );
    final base = tempDir.path.replaceAll('\\', '/');
    expect(loadAnalyzerExcludes(tempDir.path), [
      '$base/packages/**',
      '$base/**/*.g.dart',
      '$base/**/*.g.dart/**',
    ]);
  });

  test('normalizes patterns such as ./packages/**', () {
    options().writeAsStringSync(
      'analyzer:\n  exclude:\n    - "./packages/**"\n',
    );
    final base = tempDir.path.replaceAll('\\', '/');
    expect(loadAnalyzerExcludes(tempDir.path), ['$base/packages/**']);
    expect(scannedCount(tempDir.path), 1);
  });

  test('a folder pattern without /** also excludes its contents', () {
    options().writeAsStringSync('analyzer:\n  exclude:\n    - "packages/a"\n');
    expect(scannedCount(tempDir.path), 1);
  });

  test('relative target keeps relative paths and the exclude applies', () {
    // Directory discovery on a relative target is the closest working case:
    // a full run() with a relative target fails in the analyzer file system
    // (existing limitation), so this checks the discovered file list.
    final local = Directory.current.createTempSync('tmp_scan_403_');
    try {
      for (final f in ['lib/app.dart', 'packages/a/a.dart']) {
        File('${local.path}/$f')
          ..createSync(recursive: true)
          ..writeAsStringSync('void f() {}\n');
      }
      File(
        '${local.path}/analysis_options.yaml',
      ).writeAsStringSync('analyzer:\n  exclude:\n    - "packages/**"\n');
      final rel = p.relative(local.path, from: Directory.current.path);
      final files = ScanRunner.discoverDartFiles(
        rel,
        excludeGlobs: loadAnalyzerExcludes(rel),
      );
      expect(files, [p.join(rel, 'lib', 'app.dart')]);
      expect(p.isRelative(files.single), isTrue);
    } finally {
      safeDeleteDir(local);
    }
  });

  test(
    'returns empty for a missing section or bad YAML; skips non-strings',
    () {
      options().writeAsStringSync('linter:\n  rules: []\n');
      expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
      options().writeAsStringSync('analyzer: [unclosed\n');
      expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
      options().writeAsStringSync(
        'analyzer:\n  exclude:\n    - 42\n    - "packages/**"\n    - {a: b}\n',
      );
      expect(loadAnalyzerExcludes(tempDir.path), hasLength(1));
    },
  );

  test('negative control: no excludes scans both files', () {
    options().writeAsStringSync('linter:\n  rules: []\n');
    expect(scannedCount(tempDir.path), 2);
  });

  test('analyzer excludes drop matching files from the scan', () {
    options().writeAsStringSync('analyzer:\n  exclude:\n    - "packages/**"\n');
    expect(scannedCount(tempDir.path), 1);
  });

  test('subfolder target uses the options file above it', () {
    options().writeAsStringSync(
      'analyzer:\n  exclude:\n    - "packages/a/**"\n',
    );
    File('${tempDir.path}/packages/b/b.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void f() {}\n');
    // Scanning packages/ finds a.dart and b.dart; the root pattern drops a.
    expect(scannedCount('${tempDir.path}/packages'), 1);
  });

  test('discoverDartFiles (stale-ignore file list) honors the excludes', () {
    options().writeAsStringSync('analyzer:\n  exclude:\n    - "packages/**"\n');
    final files = ScanRunner.discoverDartFiles(
      tempDir.path,
      excludeGlobs: loadAnalyzerExcludes(tempDir.path),
    );
    expect(files, hasLength(1));
    expect(files.single, endsWith('lib/app.dart'));
  });
}
