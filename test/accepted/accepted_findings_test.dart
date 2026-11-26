/// Tests for the accepted-findings list (`saropa_accepted.yaml`): parsing and
/// validation, path matching, filtering scan output, stale-entry verdicts,
/// the JSON report, and the in-editor runtime's reload-on-edit.
///
/// Positive tests come first on purpose: a parser that silently returns an
/// empty list would pass every "invalid input hides nothing" test, so each
/// group proves the happy path produces real entries/matches before the
/// rejection cases.
library;

import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:saropa_lints/src/accepted/accepted_findings_check.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_report.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_runtime.dart';
import 'package:saropa_lints/src/scan/scan_cli_args.dart';
import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../../bin/audit.dart' show suppressedByLabel;
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show SuppressionKind, SuppressionTracker;

/// Fixed rule registry so tests do not depend on the live rule set.
const _known = {'avoid_print', 'avoid_dynamic'};

AcceptedFindingsList _parse(String yaml) => AcceptedFindingsList.parse(
  yaml,
  path: '/p/$kAcceptedFindingsFileName',
  known: _known,
);

ScanDiagnostic _diag(String file, String rule, {int line = 1}) =>
    ScanDiagnostic(
      ruleName: rule,
      filePath: file,
      line: line,
      column: 1,
      offset: 0,
      length: 1,
      endLine: line,
      endColumn: 2,
      severity: 'INFO',
      problemMessage: 'msg',
    );

const _validYaml = '''
version: 1
accepted:
  - rule: avoid_print
    file: lib/tool/report.dart
    kind: false_positive
    reason: Command-line output is the purpose of this file.
  - rule: avoid_dynamic
    file: .\\lib\\json.dart
    reason: Decoded JSON.
''';

void main() {
  group('parse', () {
    test('valid entries are kept with kind, reason and list line', () {
      final list = _parse(_validYaml);
      expect(list.problems, isEmpty);
      expect(list.entries, hasLength(2));
      final first = list.entries.first;
      expect(first.rule, 'avoid_print');
      expect(first.file, 'lib/tool/report.dart');
      expect(first.kind, 'false_positive');
      expect(first.line, 3);
      // Backslashes and a leading ./ normalize to the matching form.
      expect(list.entries[1].file, 'lib/json.dart');
      expect(list.entries[1].kind, isNull);
    });

    test('empty file and empty list are valid and hide nothing', () {
      expect(_parse('').problems, isEmpty);
      expect(_parse('# nothing yet\n').entries, isEmpty);
      expect(_parse('version: 1\naccepted:\n').problems, isEmpty);
    });

    test('unparseable YAML is a problem, never an empty success', () {
      final list = _parse('accepted: [unclosed');
      expect(list.entries, isEmpty);
      expect(list.problems, hasLength(1));
      expect(list.problems.single.message, contains('Cannot parse'));
    });

    test('unsupported version hides nothing', () {
      final list = _parse(
        'version: 2\naccepted:\n  - rule: avoid_print\n'
        '    file: a.dart\n    reason: r\n',
      );
      expect(list.entries, isEmpty);
      expect(list.problems.single.message, contains('version'));
    });

    test('each invalid entry is reported and dropped', () {
      final list = _parse('''
accepted:
  - rule: avoid_print
    file: a.dart
  - rule: no_such_rule
    file: a.dart
    reason: r
  - rule: avoid_print
    file: /abs/a.dart
    reason: r
  - rule: avoid_print
    file: lib/*.dart
    reason: r
  - rule: avoid_print
    file: ../a.dart
    reason: r
  - rule: avoid_print
    file: b.dart
    reason: r
    line: 12
  - rule: avoid_print
    file: c.dart
    kind: maybe
    reason: r
  - just a string
''');
      expect(list.entries, isEmpty);
      final messages = list.problems.map((p) => p.message).toList();
      expect(messages, hasLength(8));
      expect(messages[0], contains('reason'));
      expect(messages[1], contains('Unknown rule'));
      expect(messages[5], contains('Unknown key'));
      expect(messages[6], contains('kind'));
      // Problems point at the entry's line in the list file.
      expect(list.problems.first.line, 2);
    });

    test('duplicate entry keeps the first and reports the second', () {
      final list = _parse('''
accepted:
  - {rule: avoid_print, file: a.dart, reason: one}
  - {rule: avoid_print, file: a.dart, reason: two}
''');
      expect(list.entries.single.reason, 'one');
      expect(list.problems.single.message, contains('Duplicate'));
    });
  });

  group('relativeToProject', () {
    test('normalizes the `.` segment a `scan .` target leaves in paths', () {
      expect(relativeToProject('/p/./lib/a.dart', '/p/.'), 'lib/a.dart');
      expect(relativeToProject('/p/lib/a.dart', '/p/.'), 'lib/a.dart');
    });

    test('a relative root matches absolute finding paths', () {
      final abs = '${Directory.current.path}/lib/a.dart';
      expect(relativeToProject(abs, '.'), 'lib/a.dart');
    });

    test('strips the root and normalizes slashes', () {
      expect(relativeToProject('/p/lib/a.dart', '/p'), 'lib/a.dart');
      expect(relativeToProject('/p/lib/a.dart', '/p/'), 'lib/a.dart');
    });

    test('outside the root does not match, and no suffix matching', () {
      expect(relativeToProject('/other/lib/a.dart', '/p'), isNull);
      expect(relativeToProject('/pp/lib/a.dart', '/p'), isNull);
    });

    test('Windows drive-letter casing in the root still matches', () {
      final rel = relativeToProject(r'D:\src\app\lib\a.dart', 'd:/src/app');
      expect(rel, 'lib/a.dart');
    }, testOn: 'windows');
  });

  group('filterAcceptedDiagnostics', () {
    test('hides every finding of the rule in the file, keeps the rest', () {
      final list = _parse(_validYaml);
      final split = filterAcceptedDiagnostics(
        diagnostics: [
          _diag('/p/lib/tool/report.dart', 'avoid_print', line: 3),
          _diag('/p/lib/tool/report.dart', 'avoid_print', line: 40),
          _diag('/p/lib/tool/report.dart', 'avoid_dynamic'),
          _diag('/p/lib/other.dart', 'avoid_print'),
        ],
        list: list,
        projectRoot: '/p',
      );
      expect(split.hidden, hasLength(2));
      expect(split.kept, hasLength(2));
      expect(split.hiddenByEntry[list.entries.first.key], 2);
    });

    test('absent list keeps everything', () {
      final split = filterAcceptedDiagnostics(
        diagnostics: [_diag('/p/a.dart', 'avoid_print')],
        list: AcceptedFindingsList.absent('/p/$kAcceptedFindingsFileName'),
        projectRoot: '/p',
      );
      expect(split.kept, hasLength(1));
      expect(split.hidden, isEmpty);
    });
  });

  group('evaluateAcceptedEntries', () {
    final list = _parse('''
accepted:
  - {rule: avoid_print, file: hit.dart, reason: r}
  - {rule: avoid_print, file: gone.dart, reason: r}
  - {rule: avoid_print, file: clean.dart, reason: r}
  - {rule: avoid_print, file: unscanned.dart, reason: r}
  - {rule: avoid_dynamic, file: clean.dart, reason: r}
''');
    final existing = {'/p/hit.dart', '/p/clean.dart', '/p/unscanned.dart'};

    List<AcceptedEntryState> run({bool complete = true}) =>
        evaluateAcceptedEntries(
          list: list,
          hiddenByEntry: {list.entries.first.key: 3},
          scannedFiles: {'hit.dart', 'clean.dart'},
          rulesRun: {'avoid_print'},
          projectRoot: '/p',
          complete: complete,
          fileExists: existing.contains,
        ).map((s) => s.state).toList();

    test('active, missing file, no finding, and out-of-scope verdicts', () {
      expect(run(), [
        AcceptedEntryState.active,
        AcceptedEntryState.staleFileMissing,
        AcceptedEntryState.staleNoFinding,
        // File not in the scan scope.
        AcceptedEntryState.notChecked,
        // Rule did not run (disabled / lower tier).
        AcceptedEntryState.notChecked,
      ]);
    });

    test('incomplete output never claims "no finding"', () {
      expect(run(complete: false)[2], AcceptedEntryState.notChecked);
      // A missing file is stale whatever the scope.
      expect(run(complete: false)[1], AcceptedEntryState.staleFileMissing);
    });

    test('JSON report carries states, counts and problems', () {
      final statuses = evaluateAcceptedEntries(
        list: list,
        hiddenByEntry: {list.entries.first.key: 3},
        scannedFiles: {'hit.dart', 'clean.dart'},
        rulesRun: {'avoid_print'},
        projectRoot: '/p',
        fileExists: existing.contains,
      );
      final check = AcceptedListCheck(
        root: '/p',
        listPath: list.path,
        statuses: statuses,
        problems: list.problems,
      );
      final json =
          jsonDecode(acceptedCheckToJsonString([check]))
              as Map<String, dynamic>;
      final summary = json['summary'] as Map<String, dynamic>;
      expect(summary['listCount'], 1);
      expect(summary['active'], 1);
      expect(summary['stale'], 2);
      expect(summary['notChecked'], 2);
      expect(summary['hiddenTotal'], 3);
      final only = (json['lists'] as List).single as Map<String, dynamic>;
      expect(only['listPath'], list.path);
      expect((only['entries'] as List).first['state'], 'active');
      expect(acceptedCheckFails([check]), isTrue);
      expect(acceptedCheckFails(const []), isFalse);
    });
  });

  test('acceptedHiddenToJsonMaps tags kind and reason', () {
    final list = _parse(_validYaml);
    final split = filterAcceptedDiagnostics(
      diagnostics: [_diag('/p/lib/tool/report.dart', 'avoid_print')],
      list: list,
      projectRoot: '/p',
    );
    final maps = acceptedHiddenToJsonMaps(split.hidden);
    expect(maps.single['suppressedBy'], 'accepted');
    expect(maps.single['acceptedKind'], 'false_positive');
    expect(maps.single['ruleName'], 'avoid_print');
    expect(suppressedByLabel(SuppressionKind.accepted), 'accepted');
  });

  test('scan --check-accepted sets the flag; default is off', () {
    final on = parseScanArgs(['.', '--check-accepted']);
    expect((on as ScanParseOk).args.checkAccepted, isTrue);
    final off = parseScanArgs(['.']);
    expect((off as ScanParseOk).args.checkAccepted, isFalse);
  });

  test('SuppressionTracker counts accepted as its own kind', () {
    SuppressionTracker.reset();
    SuppressionTracker.record(
      rule: 'avoid_print',
      file: 'a.dart',
      line: 1,
      kind: SuppressionKind.accepted,
    );
    expect(SuppressionTracker.acceptedCount, 1);
    expect(SuppressionTracker.countsByKind['accepted'], 1);
    expect(SuppressionTracker.summary, contains('1 accepted'));
    SuppressionTracker.reset();
  });

  group('AcceptedFindingsRuntime', () {
    // A real registered rule: the runtime validates against the live
    // registry, not the test's fixed set.
    const rule = 'avoid_print_in_release';
    late Directory dir;
    late String tmp;
    setUp(() {
      AcceptedFindingsRuntime.reset();
      dir = Directory.systemTemp.createTempSync('saropa_accepted_');
      tmp = dir.path.replaceAll(r'\', '/');
    });
    tearDown(() {
      AcceptedFindingsRuntime.reset();
      dir.deleteSync(recursive: true);
    });

    /// Creates a project (a directory with a pubspec) under the temp dir.
    String project(String name) {
      final root = '$tmp/$name';
      Directory('$root/lib').createSync(recursive: true);
      File('$root/pubspec.yaml').writeAsStringSync('name: p\n');
      return root;
    }

    /// Writes a one-entry list accepting [rule] in [file] under [root].
    void accept(String root, String file, String reason) {
      File('$root/$kAcceptedFindingsFileName').writeAsStringSync(
        'accepted:\n  - rule: $rule\n    file: $file\n    reason: $reason\n',
      );
    }

    /// The reason of the entry hiding [rule] in [path], or null.
    String? reasonFor(String path) =>
        AcceptedFindingsRuntime.match(path, rule)?.reason;

    test('hides nothing until enabled', () {
      final a = project('a');
      accept(a, 'lib/x.dart', 'A.');
      expect(reasonFor('$a/lib/x.dart'), isNull);
      AcceptedFindingsRuntime.enable();
      expect(reasonFor('$a/lib/x.dart'), 'A.');
      expect(reasonFor('$a/lib/y.dart'), isNull);
    });

    test('each file uses the list of its own project root', () {
      final a = project('a');
      final b = project('b');
      final c = project('c');
      accept(a, 'lib/x.dart', 'A.');
      accept(b, 'lib/y.dart', 'B.');
      AcceptedFindingsRuntime.enable();
      // Interleaved, as one server analyzing both projects would be.
      expect(reasonFor('$a/lib/x.dart'), 'A.');
      expect(reasonFor('$b/lib/y.dart'), 'B.');
      expect(reasonFor('$a/lib/x.dart'), 'A.');
      // Neither list leaks into the other project, or into one without a list.
      expect(reasonFor('$a/lib/y.dart'), isNull);
      expect(reasonFor('$b/lib/x.dart'), isNull);
      expect(reasonFor('$c/lib/x.dart'), isNull);
    });

    test('a nested package uses its own list, not the outer one', () {
      final outer = project('outer');
      final nested = project('outer/example');
      accept(outer, 'example/lib/x.dart', 'Outer.');
      accept(nested, 'lib/y.dart', 'Inner.');
      AcceptedFindingsRuntime.enable();
      // The outer entry names the path but does not reach into the package.
      expect(reasonFor('$nested/lib/x.dart'), isNull);
      expect(reasonFor('$nested/lib/y.dart'), 'Inner.');
    });

    test('picks up a list created or deleted later, per root', () async {
      final a = project('a');
      final b = project('b');
      accept(b, 'lib/x.dart', 'B.');
      AcceptedFindingsRuntime.enable();
      expect(reasonFor('$a/lib/x.dart'), isNull);
      expect(reasonFor('$b/lib/x.dart'), 'B.');

      accept(a, 'lib/x.dart', 'Created.');
      File('$b/$kAcceptedFindingsFileName').deleteSync();
      // Wait out the recheck interval so the throttled stat runs.
      await Future<void>.delayed(
        AcceptedFindingsRuntime.recheckInterval +
            const Duration(milliseconds: 100),
      );
      expect(reasonFor('$a/lib/x.dart'), 'Created.');
      expect(reasonFor('$b/lib/x.dart'), isNull);
    });
  });
}
