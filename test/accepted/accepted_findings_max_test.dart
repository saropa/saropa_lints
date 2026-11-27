/// Tests for the optional `max:` count of an accepted-findings entry:
/// validation, which findings stay hidden (by source position), per-run
/// counting, the check report, and the in-editor reporter, which has to hold
/// findings until the walk ends to apply the same order.
library;

import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_check.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_report.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_roots.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_runtime.dart';
import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:test/test.dart';

import '../support/resolved_rule_harness.dart';
import '../support/safe_delete.dart';

const _known = {'avoid_print', 'avoid_dynamic'};

AcceptedFindingsList _parse(String yaml) => AcceptedFindingsList.parse(
  yaml,
  path: '/p/$kAcceptedFindingsFileName',
  known: _known,
);

AcceptedFindingsList _withMax(int max) => _parse(
  'accepted:\n  - {rule: avoid_print, file: a.dart, reason: r, max: $max}\n',
);

/// A finding on [line] of `<root>/a.dart`; offsets grow with the line.
ScanDiagnostic _diag(
  int line, {
  String root = '/p',
  String rule = 'avoid_print',
}) => ScanDiagnostic(
  ruleName: rule,
  filePath: '$root/a.dart',
  line: line,
  column: 1,
  offset: line * 10,
  length: 1,
  endLine: line,
  endColumn: 2,
  severity: 'INFO',
  problemMessage: 'msg',
);

AcceptedFilterResult _filter(List<ScanDiagnostic> diagnostics, int max) =>
    filterAcceptedDiagnostics(
      diagnostics: diagnostics,
      list: _withMax(max),
      projectRoot: '/p',
    );

List<int> _lines(Iterable<ScanDiagnostic> d) => [for (final x in d) x.line];

void main() {
  group('parse max', () {
    test('a positive whole number is kept; absent means unlimited', () {
      expect(_withMax(3).entries.single.max, 3);
      final unlimited = _parse(
        'accepted:\n  - {rule: avoid_print, file: a.dart, reason: r}\n',
      );
      expect(unlimited.entries.single.max, isNull);
    });

    test('anything else invalidates the entry, so it hides nothing', () {
      for (final value in ['0', '-1', '1.5', '2.0', '"2"', 'two', '', '[1]']) {
        final list = _parse(
          'accepted:\n  - rule: avoid_print\n    file: a.dart\n'
          '    reason: r\n    max: $value\n',
        );
        expect(list.entries, isEmpty, reason: 'max: $value');
        expect(
          list.problems.single.message,
          '`max` must be a positive whole number.',
          reason: 'max: $value',
        );
      }
    });
  });

  group('which findings stay hidden', () {
    test('the first max by source position, whatever the input order', () {
      for (final order in [
        [1, 2, 3, 4],
        [4, 3, 2, 1],
        [3, 1, 4, 2],
      ]) {
        final split = _filter([for (final l in order) _diag(l)], 2);
        expect(_lines(split.hidden.map((h) => h.diagnostic))..sort(), [1, 2]);
        // Kept findings stay in input order.
        expect(_lines(split.kept), order.where((l) => l > 2).toList());
        expect(split.aboveMax, hasLength(2));
      }
    });

    test('at or under max everything is hidden', () {
      final split = _filter([_diag(1), _diag(2)], 2);
      expect(split.kept, isEmpty);
      expect(split.aboveMax, isEmpty);
    });

    test('counts do not carry over to the next analysis of the file', () {
      for (var run = 0; run < 3; run++) {
        expect(_lines(_filter([_diag(1), _diag(2)], 1).kept), [2]);
      }
    });

    test('a repeated position counts once and shares its verdict', () {
      final split = _filter([_diag(1), _diag(1), _diag(2)], 1);
      expect(_lines(split.kept), [2]);
      expect(split.hidden, hasLength(2));
    });

    test('a comment-ignored finding does not use up the count', () {
      final dir = Directory.systemTemp.createTempSync('saropa_max_ignore_');
      addTearDown(() => safeDeleteDir(dir));
      final root = canonicalRoot(dir.path);
      // A registered saropa rule: ignore comments are only parsed for those.
      const rule = 'avoid_print_in_release';
      File('$root/a.dart').writeAsStringSync('x; // ignore: $rule\ny;\nz;\n');
      final split = filterAcceptedDiagnostics(
        diagnostics: [
          for (var l = 1; l <= 3; l++) _diag(l, root: root, rule: rule),
        ],
        list: AcceptedFindingsList.parse(
          'accepted:\n  - {rule: $rule, file: a.dart, reason: r, max: 1}\n',
          path: '$root/$kAcceptedFindingsFileName',
        ),
        projectRoot: root,
      );
      expect(_lines(split.hidden.map((h) => h.diagnostic)), [2]);
      expect(_lines(split.kept), [1, 3]);
    });

    test('each package applies its own max to the same relative path', () {
      final dir = Directory.systemTemp.createTempSync('saropa_max_roots_');
      addTearDown(() => safeDeleteDir(dir));
      final roots = <String>[];
      for (final (name, max) in [('one', 1), ('two', 2)]) {
        final root = canonicalRoot('${dir.path}/$name');
        Directory(root).createSync();
        File('$root/pubspec.yaml').writeAsStringSync('name: $name\n');
        File('$root/$kAcceptedFindingsFileName').writeAsStringSync(
          'accepted:\n  - {rule: avoid_print, file: a.dart, reason: r, '
          'max: $max}\n',
        );
        roots.add(root);
      }
      final split = filterAcceptedByNearestRoot([
        for (final root in roots)
          for (var l = 1; l <= 3; l++) _diag(l, root: root),
      ], lists: AcceptedListSet(known: _known));
      final key = accKey('a.dart', 'avoid_print');
      expect(split.hiddenByEntryAt(roots[0])[key], 1);
      expect(split.aboveMaxByEntryAt(roots[0])[key], 2);
      expect(split.hiddenByEntryAt(roots[1])[key], 2);
      expect(split.aboveMaxByEntryAt(roots[1])[key], 1);
      expect(_lines(split.kept), [2, 3, 3]);
    });
  });

  test('check report carries max and the above-max count without failing', () {
    final list = _withMax(1);
    final split = _filter([_diag(1), _diag(2), _diag(3)], 1);
    final statuses = evaluateAcceptedEntries(
      list: list,
      hiddenByEntry: split.hiddenByEntry,
      aboveMaxByEntry: split.aboveMaxByEntry,
      scannedFiles: {'a.dart'},
      rulesRun: {'avoid_print'},
      projectRoot: '/p',
      fileExists: (_) => true,
    );
    final check = AcceptedListCheck(
      root: '/p',
      listPath: list.path,
      statuses: statuses,
      problems: const [],
    );
    final json =
        jsonDecode(acceptedCheckToJsonString([check])) as Map<String, dynamic>;
    final entry =
        ((json['lists'] as List).single as Map)['entries'] as List<dynamic>;
    expect((entry.single as Map)['max'], 1);
    expect((entry.single as Map)['hiddenCount'], 1);
    expect((entry.single as Map)['aboveMaxCount'], 2);
    expect((json['summary'] as Map)['aboveMaxTotal'], 2);
    expect(
      acceptedCheckToText([check]).join('\n'),
      contains('hides 1 (max 1; 2 above max reported)'),
    );
    expect(acceptedCheckFails([check]), isFalse);
  });

  group('in-editor reporter', () {
    const rule = 'prefer_try_parse_for_dynamic_data';
    // Three findings, on lines 2, 3 and 4.
    const code = '''
void f(String s) {
  int.parse(s);
  int.parse(s);
  int.parse(s);
}''';
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('saropa_max_plugin_');
      AcceptedFindingsRuntime.reset();
      BaselineManager.reset();
      ProjectContext.clearCache();
    });

    tearDown(() {
      AcceptedFindingsRuntime.reset();
      BaselineManager.reset();
      safeDeleteDir(dir);
    });

    /// A package whose list accepts [rule] with [max] in every fixture path
    /// this isolate's harness can generate.
    Directory package(String name, int max) {
      final root = Directory('${dir.path}/$name')..createSync();
      File('${root.path}/pubspec.yaml').writeAsStringSync('name: $name\n');
      final entries = StringBuffer('accepted:\n');
      for (var i = 0; i < 12; i++) {
        entries.write(
          '  - rule: $rule\n'
          '    file: lib/__rule_harness__/h${pid}_$i/fixture.dart\n'
          '    reason: Test.\n'
          '    max: $max\n',
        );
      }
      File(
        '${root.path}/$kAcceptedFindingsFileName',
      ).writeAsStringSync('$entries');
      return root;
    }

    Future<List<int>> lines(Directory root, String source) async => [
      for (final d in await runRuleResolved(
        PreferTryParseForDynamicDataRule(),
        source,
        projectRoot: root,
      ))
        d.line,
    ]..sort();

    test('hides the first max and reports the rest, on every pass', () async {
      final a = package('a', 2);
      AcceptedFindingsRuntime.enable();
      expect(await lines(a, code), [4]);
      expect(await lines(a, code), [4]);
    });

    // The analysis server keeps running while the list is edited.
    test(
      'a raised max applies without a restart, to that package only',
      () async {
        final a = package('a', 1);
        final b = package('b', 1);
        AcceptedFindingsRuntime.enable();
        expect(await lines(a, code), [3, 4]);
        expect(await lines(b, code), [3, 4]);

        final list = File('${a.path}/$kAcceptedFindingsFileName');
        // Wait out the recheck interval first, so the rewrite also gets a
        // later modification time than the first load saw.
        await Future<void>.delayed(
          AcceptedFindingsRuntime.recheckInterval +
              const Duration(milliseconds: 100),
        );
        list.writeAsStringSync(
          list.readAsStringSync().replaceAll('max: 1', 'max: 3'),
        );
        expect(await lines(a, code), isEmpty);
        expect(await lines(b, code), [3, 4]);
      },
    );

    test('an ignored finding does not use up the count', () async {
      final a = package('a', 1);
      AcceptedFindingsRuntime.enable();
      final ignored = code.replaceFirst(
        '  int.parse(s);',
        '  int.parse(s); // ignore: $rule',
      );
      // Line 2 is ignored, line 3 is the one accepted, line 4 reports.
      expect(await lines(a, ignored), [4]);
    });
  });
}
