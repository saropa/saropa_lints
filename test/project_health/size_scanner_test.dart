/// End-to-end tests for the streaming size scanner: only `.dart` files are
/// measured, build/VCS dirs are skipped, exclude globs apply, paths are posix,
/// and rows stream to the sink.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/git_signals.dart';
import 'package:saropa_lints/src/cli/project_health/health_model.dart';
import 'package:saropa_lints/src/cli/project_health/size_scanner.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('saropa_health_');
    File(p.join(tmp.path, 'a.dart')).writeAsStringSync('final x = 1;\n// c\n');
    Directory(p.join(tmp.path, 'sub')).createSync();
    File(
      p.join(tmp.path, 'sub', 'b.dart'),
    ).writeAsStringSync('void main() {}\n');
    File(p.join(tmp.path, 'readme.md')).writeAsStringSync('# not dart\n');
    Directory(p.join(tmp.path, 'build')).createSync();
    File(
      p.join(tmp.path, 'build', 'gen.dart'),
    ).writeAsStringSync('var z = 0;\n');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('measures only dart files, skips non-dart and build/', () async {
    final rows = <FileHealth>[];
    final agg = await runSizeScan(
      SizeScanOptions(
        projectPath: tmp.path,
        onRow: (row) async => rows.add(row),
      ),
    );
    expect(agg.fileCount, 2); // a.dart + sub/b.dart
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.path).toSet(), {'a.dart', 'sub/b.dart'});
  });

  test('line split is correct for a measured file', () async {
    final rows = <FileHealth>[];
    await runSizeScan(
      SizeScanOptions(
        projectPath: tmp.path,
        onRow: (row) async => rows.add(row),
      ),
    );
    final a = rows.firstWhere((r) => r.path == 'a.dart');
    expect(a.loc, 2);
    expect(a.codeLoc, 1);
    expect(a.commentLoc, 1);
    expect(a.bytes, greaterThan(0));
  });

  test('exclude glob removes matching paths', () async {
    final agg = await runSizeScan(
      SizeScanOptions(projectPath: tmp.path, excludeGlobs: ['sub/**']),
    );
    expect(agg.fileCount, 1); // only a.dart remains
  });

  test('skips generated and gen-l10n files so hot spots stay actionable', () async {
    // Generated/locale files dominate size and hot-spot rankings while being
    // unimprovable — the scanner must drop them, matching Code Health.
    File(p.join(tmp.path, 'model.g.dart')).writeAsStringSync('var g = 0;\n');
    File(p.join(tmp.path, 'm.freezed.dart')).writeAsStringSync('var f = 0;\n');
    Directory(p.join(tmp.path, 'l10n')).createSync();
    File(
      p.join(tmp.path, 'l10n', 'app_localizations_fr.dart'),
    ).writeAsStringSync('var fr = 0;\n');
    Directory(p.join(tmp.path, 'service', 'l10n')).createSync(recursive: true);
    File(
      p.join(tmp.path, 'service', 'l10n', 'remote_app_localizations.dart'),
    ).writeAsStringSync('var r = 0;\n');

    final rows = <FileHealth>[];
    final agg = await runSizeScan(
      SizeScanOptions(
        projectPath: tmp.path,
        onRow: (row) async => rows.add(row),
      ),
    );
    // Only the two hand-written files survive (a.dart + sub/b.dart).
    expect(agg.fileCount, 2);
    expect(rows.map((r) => r.path).toSet(), {'a.dart', 'sub/b.dart'});
  });

  test('missing project directory yields an empty aggregate', () async {
    final agg = await runSizeScan(
      SizeScanOptions(projectPath: p.join(tmp.path, 'nope')),
    );
    expect(agg.fileCount, 0);
  });

  test('attaches dead-weight, coverage, and git overlays by path', () async {
    final rows = <FileHealth>[];
    await runSizeScan(
      SizeScanOptions(
        projectPath: tmp.path,
        unusedFiles: {'a.dart'},
        deadSymbols: {'a.dart': 3},
        coverage: {'a.dart': 0.42},
        gitSignals: {
          'a.dart': const GitSignal(
            churn: 7,
            lastCommitDaysAgo: 2,
            busFactorPct: 0.8,
          ),
        },
        onRow: (row) async => rows.add(row),
      ),
    );
    final a = rows.firstWhere((r) => r.path == 'a.dart');
    expect(a.isUnusedFile, isTrue);
    expect(a.deadSymbols, 3);
    expect(a.coveragePct, 0.42);
    expect(a.churn, 7);
    // A file with no overlay entry carries no overlay data.
    final b = rows.firstWhere((r) => r.path == 'sub/b.dart');
    expect(b.isUnusedFile, isFalse);
    expect(b.coveragePct, isNull);
    expect(b.churn, isNull);
  });
}
