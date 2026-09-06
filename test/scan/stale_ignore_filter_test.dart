/// Regression tests pinning EXACTLY which diagnostics the scan CLI suppresses
/// via `// ignore:` / `// ignore_for_file:` directives, and which it does not.
///
/// WHY THIS FILE EXISTS
/// --------------------
/// The scan CLI deliberately does NOT honor ignore directives during rule
/// execution — every rule reports unconditionally. Suppression is applied
/// afterwards by [filterIgnoredDiagnostics] (see `bin/scan.dart`, which calls
/// it on the raw diagnostic list before any output path). That split is
/// load-bearing: [detectStaleIgnores] needs the UNFILTERED set so it can ask
/// "did this rule actually fire on the line this ignore protects?".
///
/// Until this file was written, nothing pinned that behavior in either
/// direction. The gap was silent: a change that moved suppression upstream
/// into rule execution would look like a cleanup, would pass every existing
/// test, and would break stale-ignore detection catastrophically — with no
/// diagnostics surviving on ignored lines, every ignore in a project would be
/// reported as stale and `--fix-stale-ignores` would strip them all.
///
/// Every test below therefore pins one edge of the contract. The two most
/// valuable are:
///  - "a DIFFERENT rule on an ignored line is NOT suppressed" (the easiest
///    case to get wrong, since a naive implementation keys suppression on the
///    line alone rather than on the (line, rule) pair), and
///  - "the unfiltered set stays available to stale detection" (the regression
///    described above).
library;

import 'dart:io';

import 'package:saropa_lints/src/rule_name_utils.dart' show allSaropaRuleNames;
import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:saropa_lints/src/scan/stale_ignore_detector.dart';
import 'package:test/test.dart';

/// Real saropa rule names. The parser in `stale_ignore_detector.dart` only
/// tracks directives naming rules present in [allSaropaRuleNames], so the
/// fixtures MUST use genuine names — an invented name would make every test
/// here pass vacuously.
const String ruleA = 'avoid_print_error';
const String ruleB = 'prefer_member_ordering';
const String ruleC = 'prefer_sorted_parameters';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('stale_ignore_filter_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Writes [content] to a `.dart` file in the temp dir and returns its path.
  String writeFile(String name, String content) {
    final file = File('${tempDir.path}${Platform.pathSeparator}$name');
    file.writeAsStringSync(content);
    return file.path;
  }

  /// Builds a diagnostic at [line] for [rule] in [path]. Only ruleName,
  /// filePath and line participate in suppression; the rest are filler so the
  /// test does not depend on fields the filter never reads.
  ScanDiagnostic diag(String rule, String path, int line) => ScanDiagnostic(
    ruleName: rule,
    filePath: path,
    line: line,
    column: 1,
    offset: 0,
    length: 1,
    endLine: line,
    endColumn: 2,
    severity: 'WARNING',
    problemMessage: 'test diagnostic',
  );

  group('fixture sanity', () {
    // Guards against a silent rot mode: if any of these rules is renamed or
    // retired, the parser drops the directive and every suppression test below
    // would still pass — but for the wrong reason (nothing suppressed because
    // nothing was parsed). Fail loudly here instead.
    test('fixture rule names exist in the saropa registry', () {
      expect(allSaropaRuleNames, contains(ruleA));
      expect(allSaropaRuleNames, contains(ruleB));
      expect(allSaropaRuleNames, contains(ruleC));
    });
  });

  group('filterIgnoredDiagnostics — line-level // ignore:', () {
    test('standalone directive suppresses the NEXT line', () {
      // Dart convention: a comment occupying the whole line applies to the
      // line below it. Line 1 is the comment, line 2 is the protected code.
      final path = writeFile('standalone.dart', '''
// ignore: $ruleA
final x = 1;
final y = 2;
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [
          diag(ruleA, path, 2), // protected by the directive above
          diag(ruleA, path, 3), // one line past the protection window
        ],
        files: [path],
      );

      // Only the line-3 diagnostic survives: the ignore covers line 2 alone,
      // never a range.
      expect(result.map((d) => d.line), [3]);
    });

    test('inline directive suppresses THAT line, not the next', () {
      // When code precedes the `//`, the directive applies to its own line.
      // Pinning "not the next line" matters because standalone and inline
      // share one regex; an off-by-one in the standalone branch would leak.
      final path = writeFile('inline.dart', '''
final x = 1; // ignore: $ruleA
final y = 2;
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, path, 1), diag(ruleA, path, 2)],
        files: [path],
      );

      expect(result.map((d) => d.line), [2]);
    });

    test('a DIFFERENT rule on an ignored line is NOT suppressed', () {
      // The highest-value case in this file. Suppression is keyed on the
      // (line, ruleName) pair. An implementation that suppressed everything
      // reported on a line carrying any ignore comment would hide unrelated,
      // genuine defects — the worst possible failure mode for a linter.
      final path = writeFile('other_rule.dart', '''
final x = 1; // ignore: $ruleA
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, path, 1), diag(ruleB, path, 1)],
        files: [path],
      );

      expect(result, hasLength(1));
      expect(result.single.ruleName, ruleB);
    });

    test('multi-rule directive suppresses each rule named and no others', () {
      // Comma-separated lists are parsed per name. Pins both halves: the two
      // named rules go, the third (unnamed) rule stays.
      final path = writeFile('multi.dart', '''
final x = 1; // ignore: $ruleA, $ruleB
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [
          diag(ruleA, path, 1),
          diag(ruleB, path, 1),
          diag(ruleC, path, 1),
        ],
        files: [path],
      );

      expect(result.map((d) => d.ruleName), [ruleC]);
    });
  });

  group('filterIgnoredDiagnostics — // ignore_for_file:', () {
    test('suppresses the named rule across the whole file', () {
      // File-level directives are position independent: the diagnostics below
      // sit on lines far from the comment and must still be suppressed.
      final path = writeFile('for_file.dart', '''
// ignore_for_file: $ruleA
final a = 1;
final b = 2;
final c = 3;
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [
          diag(ruleA, path, 2),
          diag(ruleA, path, 4),
          diag(ruleB, path, 3), // different rule — must survive
        ],
        files: [path],
      );

      expect(result, hasLength(1));
      expect(result.single.ruleName, ruleB);
    });

    test('does not leak suppression into another scanned file', () {
      // A per-file map keyed by path; a bug that merged all files' directives
      // into one global set would silence real findings elsewhere.
      final suppressed = writeFile('a.dart', '''
// ignore_for_file: $ruleA
final a = 1;
''');
      final untouched = writeFile('b.dart', 'final b = 1;\n');

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, suppressed, 2), diag(ruleA, untouched, 1)],
        files: [suppressed, untouched],
      );

      expect(result, hasLength(1));
      expect(result.single.filePath, untouched);
    });
  });

  group('filterIgnoredDiagnostics — pass-through cases', () {
    test('files absent from the scanned list are not filtered', () {
      // Documented contract: the filter reads ignore directives only from the
      // files it was told were scanned. A diagnostic for a file outside that
      // list passes through untouched even though the file on disk carries a
      // matching directive. This keeps the filter from doing surprise I/O on
      // paths the caller never asked about.
      final scanned = writeFile('scanned.dart', 'final s = 1;\n');
      final unscanned = writeFile('unscanned.dart', '''
final u = 1; // ignore: $ruleA
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, unscanned, 1)],
        files: [scanned],
      );

      expect(result, hasLength(1));
      expect(result.single.filePath, unscanned);
    });

    test('a file with no directives passes through unchanged', () {
      final path = writeFile('clean.dart', 'final c = 1;\n');
      final input = [diag(ruleA, path, 1), diag(ruleB, path, 1)];

      final result = filterIgnoredDiagnostics(
        diagnostics: input,
        files: [path],
      );

      expect(result, hasLength(2));
    });

    test('a directive naming a non-saropa rule suppresses nothing', () {
      // The parser only tracks names present in the saropa registry, so a
      // core-Dart-lint ignore must not accidentally match a saropa rule and
      // must not throw on an unknown name.
      final path = writeFile('foreign.dart', '''
final x = 1; // ignore: unnecessary_this
''');

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, path, 1)],
        files: [path],
      );

      expect(result, hasLength(1));
    });

    test('does not mutate the caller-supplied diagnostic list', () {
      // bin/scan.dart keeps the raw list alive for stale detection after
      // calling the filter. In-place mutation would corrupt that second use.
      final path = writeFile('nomutate.dart', '''
final x = 1; // ignore: $ruleA
''');
      final input = [diag(ruleA, path, 1), diag(ruleB, path, 1)];

      final result = filterIgnoredDiagnostics(
        diagnostics: input,
        files: [path],
      );

      expect(input, hasLength(2), reason: 'input list must be untouched');
      expect(result, hasLength(1));
    });
  });

  group('filterIgnoredDiagnostics — path normalization', () {
    test('matches despite separator and drive-letter casing differences', () {
      // The scan pipeline mixes path shapes: analyzer-reported paths, CLI
      // arguments, and `p.normalize` output can disagree on `\` vs `/` and on
      // drive-letter case (Windows). A mismatch here would be SILENT — the
      // lookup key simply misses and the ignore appears not to work, with no
      // error anywhere. Build a deliberately mangled variant of the real path
      // and require the filter to still suppress.
      final path = writeFile('normalize.dart', '''
final x = 1; // ignore: $ruleA
''');

      var mangled = path.replaceAll('/', r'\');
      // Uppercase the drive letter when present (Windows-only shape; on POSIX
      // this is a no-op and the backslash swap alone exercises the separator
      // half of the normalization).
      if (mangled.length >= 2 && mangled[1] == ':') {
        mangled = mangled[0].toUpperCase() + mangled.substring(1);
      }

      final result = filterIgnoredDiagnostics(
        diagnostics: [diag(ruleA, mangled, 1)],
        files: [path],
      );

      expect(result, isEmpty);
    });
  });

  group('unfiltered set stays available to stale-ignore detection', () {
    test('a live ignore is NOT stale while its diagnostic still fires', () {
      // This is the regression guard for "suppression must stay downstream".
      // detectStaleIgnores is fed the RAW diagnostics; because the rule still
      // fires on the ignored line, the ignore is live and must not be
      // reported. Simultaneously, filterIgnoredDiagnostics removes it from
      // user-facing output. Both facts hold at once — that is the whole point
      // of the two-stage design.
      final path = writeFile('live.dart', '''
final x = 1; // ignore: $ruleA
''');
      final raw = [diag(ruleA, path, 1)];

      expect(
        detectStaleIgnores(diagnostics: raw, files: [path]),
        isEmpty,
        reason: 'rule still fires on the ignored line, so the ignore is live',
      );
      expect(
        filterIgnoredDiagnostics(diagnostics: raw, files: [path]),
        isEmpty,
        reason: 'user-facing output must still honor the ignore',
      );
    });

    test(
      'feeding the FILTERED set to stale detection reports a false stale',
      () {
        // Demonstrates, rather than merely asserts, why suppression must not
        // move into rule execution. Passing the already-filtered list to
        // detectStaleIgnores makes a perfectly live ignore look stale — exactly
        // what would happen project-wide if rules stopped reporting on ignored
        // lines. If a future refactor makes this test fail (i.e. stale detection
        // becomes insensitive to the input set), the two-stage contract has
        // changed and this file must be revisited deliberately.
        final path = writeFile('false_stale.dart', '''
final x = 1; // ignore: $ruleA
''');
        final raw = [diag(ruleA, path, 1)];
        final filtered = filterIgnoredDiagnostics(
          diagnostics: raw,
          files: [path],
        );

        final stale = detectStaleIgnores(diagnostics: filtered, files: [path]);
        expect(stale, hasLength(1));
        expect(stale.single.ruleName, ruleA);
      },
    );
  });
}
