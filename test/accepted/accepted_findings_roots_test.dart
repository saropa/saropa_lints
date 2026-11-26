/// Tests for per-package accepted-findings lists in CLI producers: the shared
/// root rule, multi-list filtering, list discovery for `--check-accepted`,
/// and the per-list check.
///
/// These guard the mismatch this code fixes: the analyzer plugin matched a
/// file against its nearest package's list while the CLI producers used one
/// list at the scan target, so a nested package's entries hid findings in the
/// editor only. Each test builds real directories, because the root rule is a
/// file-system walk.
library;

import 'dart:convert' show jsonDecode;
import 'dart:io';

import 'package:saropa_lints/src/accepted/accepted_findings_check.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_list.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_report.dart';
import 'package:saropa_lints/src/accepted/accepted_findings_roots.dart';
import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:test/test.dart';

/// Fixed registry so list validation does not depend on the live rule set.
const _known = {'avoid_print', 'avoid_dynamic'};

ScanDiagnostic _diag(String file, String rule) => ScanDiagnostic(
  ruleName: rule,
  filePath: file,
  line: 1,
  column: 1,
  offset: 0,
  length: 1,
  endLine: 1,
  endColumn: 2,
  severity: 'INFO',
  problemMessage: 'msg',
);

void main() {
  late Directory dir;
  late String tmp;
  late String outer;
  late String nested;

  /// Creates a package (folder with pubspec.yaml and lib/) at [rel].
  String package(String rel) {
    final root = '$tmp/$rel';
    Directory('$root/lib').createSync(recursive: true);
    File('$root/pubspec.yaml').writeAsStringSync('name: p\n');
    return root;
  }

  /// Writes a list at [folder] with `(rule, file, reason)` entries.
  void writeList(String folder, List<(String, String, String)> entries) {
    Directory(folder).createSync(recursive: true);
    File('$folder/$kAcceptedFindingsFileName').writeAsStringSync(
      'accepted:\n${entries.map((e) => '  - {rule: ${e.$1}, file: ${e.$2}, '
          'reason: ${e.$3}}\n').join()}',
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_accepted_roots_');
    // Canonical form, so expectations compare equal to helper output.
    tmp = canonicalRoot(dir.path);
    outer = package('outer');
    nested = package('outer/example');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('acceptedRootFor returns the nearest package, nested first', () {
    expect(acceptedRootFor('$outer/lib/a.dart'), outer);
    expect(acceptedRootFor('$nested/lib/a.dart'), nested);
    // A list file in a package folder belongs to that package.
    expect(acceptedRootForDir(nested), nested);
    expect(acceptedRootForDir('$outer/lib'), outer);
  });

  group('filterAcceptedByNearestRoot', () {
    test('each finding uses its own package list', () {
      writeList(outer, [
        ('avoid_print', 'lib/a.dart', 'Outer.'),
        // Names a nested package's file: never applies.
        ('avoid_print', 'example/lib/b.dart', 'Outer reach.'),
      ]);
      writeList(nested, [('avoid_print', 'lib/a.dart', 'Inner.')]);
      final split = filterAcceptedByNearestRoot([
        _diag('$outer/lib/a.dart', 'avoid_print'),
        _diag('$nested/lib/a.dart', 'avoid_print'),
        _diag('$nested/lib/b.dart', 'avoid_print'),
        _diag('$outer/lib/a.dart', 'avoid_dynamic'),
      ], lists: AcceptedListSet(known: _known));
      // Positive first: both lists hid their own file.
      expect(
        split.hidden.map((h) => h.entry.reason),
        unorderedEquals(['Outer.', 'Inner.']),
      );
      expect(split.kept.map((d) => d.filePath), [
        '$nested/lib/b.dart',
        '$outer/lib/a.dart',
      ]);
      // Same entry key in both lists, counted per package.
      final key = accKey('lib/a.dart', 'avoid_print');
      expect(split.hiddenByEntryAt(outer)[key], 1);
      expect(split.hiddenByEntryAt(nested)[key], 1);
    });

    test('keeps everything when no package has a list', () {
      final split = filterAcceptedByNearestRoot([
        _diag('$outer/lib/a.dart', 'avoid_print'),
      ], lists: AcceptedListSet(known: _known));
      expect(split.kept, hasLength(1));
      expect(split.hidden, isEmpty);
    });
  });

  group('discoverAcceptedLists', () {
    test('finds nested packages and stray lists, skips dependency dirs', () {
      // Dependency and build copies must not be reported as this project's.
      package('outer/build/copy');
      package('outer/.dart_tool/dep');
      package('outer/node_modules/dep');
      writeList('$outer/build/copy', [('avoid_print', 'lib/a.dart', 'x')]);
      writeList('$outer/tool', [('avoid_print', 'lib/a.dart', 'x')]);
      final found = discoverAcceptedLists(outer);
      expect(found.roots, unorderedEquals([outer, nested]));
      expect(found.strayLists, ['$outer/tool/$kAcceptedFindingsFileName']);
    });

    test('a target inside a package includes that package', () {
      final found = discoverAcceptedLists('$outer/lib');
      expect(found.roots, [outer]);
    });
  });

  group('checkAcceptedLists', () {
    List<AcceptedListCheck> run() {
      final lists = AcceptedListSet(known: _known);
      final split = filterAcceptedByNearestRoot([
        _diag('$nested/lib/a.dart', 'avoid_print'),
      ], lists: lists);
      return checkAcceptedLists(
        target: outer,
        lists: lists,
        split: split,
        scannedFiles: ['$nested/lib/a.dart', '$nested/lib/c.dart'],
        rulesRun: {'avoid_print'},
        complete: true,
      );
    }

    setUp(() {
      File('$nested/lib/a.dart').writeAsStringSync('');
      File('$nested/lib/b.dart').writeAsStringSync('');
      File('$nested/lib/c.dart').writeAsStringSync('');
      writeList(outer, [('avoid_print', 'example/lib/b.dart', 'Reach.')]);
      writeList(nested, [
        ('avoid_print', 'lib/a.dart', 'Hit.'),
        ('avoid_print', 'lib/c.dart', 'Fixed since.'),
      ]);
      writeList('$outer/tool', [('avoid_print', 'lib/a.dart', 'Stray.')]);
    });

    test('judges each list against its own package', () {
      final checks = run();
      final byPath = {for (final c in checks) c.listPath: c};
      expect(byPath.keys, hasLength(3));
      final inner = byPath['$nested/$kAcceptedFindingsFileName']!;
      expect(inner.statuses.map((s) => s.state), [
        AcceptedEntryState.active,
        AcceptedEntryState.staleNoFinding,
      ]);
      expect(inner.problems, isEmpty);
      // The outer entry names a nested package's file: a problem, not judged.
      final top = byPath['$outer/$kAcceptedFindingsFileName']!;
      expect(top.statuses, isEmpty);
      expect(top.problems.single.message, contains('example/'));
      final stray = byPath['$outer/tool/$kAcceptedFindingsFileName']!;
      expect(stray.problems.single.message, contains('No pubspec.yaml'));
      expect(acceptedCheckFails(checks), isTrue);
    });

    test('JSON lists every list with its root and totals', () {
      final json =
          jsonDecode(acceptedCheckToJsonString(run())) as Map<String, dynamic>;
      expect(json['version'], 2);
      final lists = json['lists'] as List;
      expect(lists, hasLength(3));
      expect(
        lists.map((l) => (l as Map)['projectRoot']),
        containsAll([outer, nested]),
      );
      final summary = json['summary'] as Map<String, dynamic>;
      expect(summary['listCount'], 3);
      expect(summary['active'], 1);
      expect(summary['stale'], 1);
      expect(summary['problemCount'], 2);
      expect(
        acceptedCheckToText(run()).last,
        '3 lists, 2 entries, 1 stale, 2 invalid.',
      );
    });
  });

  test('no list anywhere: empty report that passes', () {
    final lists = AcceptedListSet(known: _known);
    final checks = checkAcceptedLists(
      target: outer,
      lists: lists,
      split: filterAcceptedByNearestRoot(const [], lists: lists),
      scannedFiles: const [],
      rulesRun: const {},
      complete: true,
    );
    expect(checks, isEmpty);
    expect(acceptedCheckFails(checks), isFalse);
    expect(acceptedCheckToText(checks).single, contains('No '));
  });
}
