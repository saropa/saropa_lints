/// End-to-end regression for `--find-stale-ignores` / `--fix-stale-ignores`
/// reporting a LIVE `// ignore:` as stale.
///
/// The reporter ([SaropaDiagnosticReporter]) drops a finding that a
/// `// ignore:` comment covers BEFORE it reaches the scan's diagnostic list.
/// The stale detector then saw "no finding on the target line" and called
/// the comment stale, so `--fix-stale-ignores` deleted comments that were
/// still needed. These tests run the real [ScanRunner] (not hand-built
/// diagnostics) so the reporter's own suppression is part of what is tested.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/baseline_config.dart';
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/scan/scan_runner.dart';
import 'package:saropa_lints/src/scan/stale_ignore_detector.dart';
import 'package:saropa_lints/src/scan/stale_ignore_probe.dart';
import 'package:saropa_lints/src/scan/stale_ignore_scan.dart';
import 'package:test/test.dart';

/// Rule used throughout: syntactic, reports on every bare `print(...)`.
const String _rule = 'prefer_logger_over_print';

/// Second real rule for the multi-rule ignore list cases. It does not fire
/// on the fixtures below, so it is always the stale half of a pair.
const String _otherRule = 'avoid_print_error';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stale_ignore_live_');
  });

  tearDown(() {
    // The probe is process-wide; never let one test leak it into the next.
    StaleIgnoreProbe.stop();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes [content] as `lib/<name>` under the temp project.
  String writeFile(String name, String content) {
    final file = File(p.join(tempDir.path, 'lib', name))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.path;
  }

  /// Runs the scan the same way the CLI's stale modes do and returns the
  /// stale ignores it finds across [files]. Syntactic by default for speed;
  /// one test below covers the resolved path the CLI uses.
  Future<List<StaleIgnore>> findStale(
    List<String> files, {
    Set<String>? rules,
    bool resolve = false,
  }) async {
    final run = await runStaleIgnoreScan(
      ScanRunner(
        targetPath: tempDir.path,
        dartFiles: files,
        enabledRuleNames: rules ?? {_rule, _otherRule},
        maxIssues: 0,
        messageSink: (_) {},
      ),
      resolve: resolve,
    );
    expect(run, isNotNull, reason: 'scan must produce a result');
    return detectStaleIgnores(
      diagnostics: run!.diagnostics,
      files: files,
      coverage: run.coverage,
    );
  }

  group('live ignores are never reported stale', () {
    test('standalone ignore above a print the rule would report', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  print('x');
}
''');
      expect(await findStale([path]), isEmpty);
    });

    test('inline ignore on the reported line', () async {
      final path = writeFile('a.dart', '''
void f() {
  print('x'); // ignore: $_rule
}
''');
      expect(await findStale([path]), isEmpty);
    });

    test('ignore with the saropa_lints/ prefix', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: saropa_lints/$_rule
  print('x');
}
''');
      expect(await findStale([path]), isEmpty);
    });

    test('line ignore also covered by ignore_for_file stays', () async {
      final path = writeFile('a.dart', '''
// ignore_for_file: $_rule
void f() {
  // ignore: $_rule
  print('x');
}
''');
      expect(await findStale([path]), isEmpty);
    });

    test('ignore for a rule that did not run is kept', () async {
      // Only _otherRule runs; nothing can be said about _rule's comment.
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  int x = 1;
}
''');
      expect(await findStale([path], rules: {_otherRule}), isEmpty);
    });

    test('ignore in a file the scan did not cover is kept', () async {
      final scanned = writeFile('a.dart', 'void f() {}\n');
      final unscanned = writeFile('b.dart', '''
void g() {
  // ignore: $_rule
  int x = 1;
}
''');
      final run = (await runStaleIgnoreScan(
        ScanRunner(
          targetPath: tempDir.path,
          dartFiles: [scanned],
          enabledRuleNames: {_rule},
          maxIssues: 0,
          messageSink: (_) {},
        ),
        resolve: false,
      ))!;
      // The detector is asked about both files, but only one was walked.
      final stale = detectStaleIgnores(
        diagnostics: run.diagnostics,
        files: [scanned, unscanned],
        coverage: run.coverage,
      );
      expect(stale, isEmpty);
    });

    test('ignore the reporter honors on another line keeps the file', () async {
      // The ignore sits above a multi-line statement. The reporter walks up
      // to the statement and honors it, but the finding is two lines below
      // the comment, not on the line the line-based parser expects.
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  final v = [
    print('x'),
  ];
}
''');
      expect(await findStale([path]), isEmpty);
      // Guard against a vacuous pass: without coverage the line-based match
      // alone calls this comment stale, so the coverage check is what kept it.
      final run = (await runStaleIgnoreScan(
        ScanRunner(
          targetPath: tempDir.path,
          dartFiles: [path],
          enabledRuleNames: {_rule},
          maxIssues: 0,
          messageSink: (_) {},
        ),
        resolve: false,
      ))!;
      expect(
        detectStaleIgnores(diagnostics: run.diagnostics, files: [path]),
        hasLength(1),
      );
    });

    test('ignore on a baselined finding stays', () async {
      // The reporter checks the baseline before comments, so a baselined
      // finding used to vanish and make its comment look stale.
      BaselineManager.initialize(
        BaselineConfig(paths: const <String>['lib/']),
        projectRoot: tempDir.path,
      );
      addTearDown(BaselineManager.reset);
      // Non-vacuous: a normal scan really hides an un-commented finding here.
      final bare = writeFile('bare.dart', "void g() {\n  print('y');\n}\n");
      final normal = ScanRunner(
        targetPath: tempDir.path,
        dartFiles: [bare],
        enabledRuleNames: {_rule},
        maxIssues: 0,
        messageSink: (_) {},
      ).run();
      expect(normal, isEmpty, reason: 'baseline must hide it normally');
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  print('x');
}
''');
      expect(await findStale([path]), isEmpty);
    });

    test('the probe is off again after the scan', () async {
      final path = writeFile('a.dart', 'void f() {}\n');
      await findStale([path]);
      expect(StaleIgnoreProbe.active, isFalse);
    });
  });

  group('resolved scan (the path the CLI uses)', () {
    test('keeps the live comment and reports the dead one', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  print('x');
  // ignore: $_rule
  int y = 1;
}
''');
      final stale = await findStale([path], resolve: true);
      expect(stale.map((s) => s.commentLine), [4]);
    });
  });

  group('genuinely stale ignores are still reported', () {
    test('ignore above a line with no finding', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  int x = 1;
}
''');
      final stale = await findStale([path]);
      expect(stale.map((s) => s.ruleName), [_rule]);
      expect(stale.single.commentLine, 2);
    });

    test('multi-rule list reports only the name that is stale', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule, $_otherRule
  print('x');
}
''');
      final stale = await findStale([path]);
      expect(stale.map((s) => s.ruleName), [_otherRule]);
    });
  });

  group('fixStaleIgnores on a scanned temp file', () {
    test('removes only the stale name from a multi-rule list', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule, $_otherRule
  print('x');
}
''');
      fixStaleIgnores(await findStale([path]));
      final text = File(path).readAsStringSync();
      expect(text, contains('// ignore: $_rule\n'));
      expect(text, isNot(contains(_otherRule)));
      // The pruned comment is now fully live: a second pass finds nothing.
      expect(await findStale([path]), isEmpty);
    });

    test('leaves a live ignore untouched', () async {
      const source =
          '''
void f() {
  // ignore: $_rule
  print('x');
}
''';
      final path = writeFile('a.dart', source);
      final results = fixStaleIgnores(await findStale([path]));
      expect(results, isEmpty);
      expect(File(path).readAsStringSync(), source);
    });

    test('deletes a stale standalone ignore line', () async {
      final path = writeFile('a.dart', '''
void f() {
  // ignore: $_rule
  int x = 1;
}
''');
      fixStaleIgnores(await findStale([path]));
      expect(File(path).readAsStringSync(), isNot(contains('ignore:')));
    });
  });
}
