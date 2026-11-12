/// Tests for #403: the scan reads `analyzer: exclude:` and matches exclude /
/// include globs against the path relative to the project root.
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
    for (final f in [
      'lib/app.dart',
      'packages/a/a.dart',
      'tools/vendor/v.dart',
    ]) {
      File('${tempDir.path}/$f')
        ..createSync(recursive: true)
        ..writeAsStringSync('void f() {}\n');
    }
  });

  tearDown(() => safeDeleteDir(tempDir));

  /// Number of files the runner reports scanning (from its progress message).
  int scannedCount({
    String? target,
    List<String> exclude = const [],
    List<String> include = const [],
    bool noExclude = false,
  }) {
    final messages = <String>[];
    ScanRunner(
      targetPath: target ?? tempDir.path,
      tier: 'essential',
      messageSink: messages.add,
      excludeGlobs: exclude,
      includeGlobs: include,
      noExclude: noExclude,
    ).run();
    final line = messages.firstWhere(
      (m) => m.startsWith('Scanning '),
      orElse: () => 'Scanning 0 files...',
    );
    return int.parse(RegExp(r'Scanning (\d+)').firstMatch(line)!.group(1)!);
  }

  group('loadAnalyzerExcludes', () {
    test('returns the analyzer exclude list', () {
      File('${tempDir.path}/analysis_options.yaml').writeAsStringSync(
        'analyzer:\n  exclude:\n    - "packages/**"\n    - "**/*.g.dart"\n',
      );
      expect(loadAnalyzerExcludes(tempDir.path), [
        'packages/**',
        '**/*.g.dart',
      ]);
    });

    test('returns empty when file, section or YAML is missing or bad', () {
      expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
      final f = File('${tempDir.path}/analysis_options.yaml');
      f.writeAsStringSync('linter:\n  rules: []\n');
      expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
      f.writeAsStringSync('analyzer: [unclosed\n');
      expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
    });
  });

  group('exclude globs are relative to the project root', () {
    test('baseline scans all three files', () {
      expect(scannedCount(), 3);
    });

    test('packages/** matches with an absolute target', () {
      expect(scannedCount(exclude: ['packages/**']), 2);
    });

    test('packages/** matches with a relative target', () {
      // A project folder inside the current directory gives a relative
      // target without `..` segments.
      final local = Directory.current.createTempSync('tmp_scan_403_');
      try {
        File('${local.path}/lib/app.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('void f() {}\n');
        File('${local.path}/packages/a/a.dart')
          ..createSync(recursive: true)
          ..writeAsStringSync('void f() {}\n');
        final rel = p.relative(local.path, from: Directory.current.path);
        final messages = <String>[];
        // Explicit files resolve against the absolute root, which keeps the
        // run valid for a relative target (directory discovery on a
        // relative target is a separate, existing limitation).
        ScanRunner(
          targetPath: rel,
          dartFiles: ['lib/app.dart', 'packages/a/a.dart'],
          tier: 'essential',
          messageSink: messages.add,
          excludeGlobs: ['packages/**'],
        ).run();
        expect(messages, contains('Scanning 1 files...'));
      } finally {
        safeDeleteDir(local);
      }
    });

    test('**/packages/** still matches', () {
      expect(scannedCount(exclude: ['**/packages/**']), 2);
    });

    test('a pattern naming a parent of the root does not match', () {
      final parentName = tempDir.parent.path.split('/').last;
      expect(scannedCount(exclude: ['**/$parentName/**']), 3);
    });

    test('include globs override excludes', () {
      expect(
        scannedCount(exclude: ['packages/**'], include: ['packages/a/**']),
        3,
      );
    });

    test('--no-exclude still leaves user excludes in force', () {
      expect(scannedCount(exclude: ['packages/**'], noExclude: true), 2);
    });
  });
}
