/// Tests for #403: the scan reads `analyzer: exclude:` from the project's
/// `analysis_options.yaml`. Relative glob matching itself is covered by
/// `scan_exclude_globs_relative_test.dart` (#405).
library;

import 'dart:io';

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

  test('returns the analyzer exclude list', () {
    options().writeAsStringSync(
      'analyzer:\n  exclude:\n    - "packages/**"\n    - "**/*.g.dart"\n',
    );
    expect(loadAnalyzerExcludes(tempDir.path), ['packages/**', '**/*.g.dart']);
  });

  test('returns empty when file, section or YAML is missing or bad', () {
    expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
    options().writeAsStringSync('linter:\n  rules: []\n');
    expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
    options().writeAsStringSync('analyzer: [unclosed\n');
    expect(loadAnalyzerExcludes(tempDir.path), isEmpty);
  });

  test('analyzer excludes drop matching files from the scan', () {
    options().writeAsStringSync(
      'analyzer:\n  exclude:\n    - "packages/**"\n',
    );
    final messages = <String>[];
    ScanRunner(
      targetPath: tempDir.path,
      tier: 'essential',
      messageSink: messages.add,
      excludeGlobs: loadAnalyzerExcludes(tempDir.path),
    ).run();
    expect(messages, contains('Scanning 1 files...'));
  });
}
