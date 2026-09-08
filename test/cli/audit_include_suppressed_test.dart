/// Tests for the `audit --include-suppressed` flag's pure-logic pieces:
/// [suppressedByLabel] and [suppressedDiagnosticMaps] from `bin/audit.dart`.
///
/// These exercise the merge logic in isolation from the full scan pipeline
/// (which requires a resolved analysis context and is covered instead by
/// manual CLI verification — see the flag's rollout notes in CHANGELOG.md).
/// What matters here is the two guarantees the flag makes:
///   (a) with [SuppressionTracker.captureDetails] off (the flag absent, the
///       default), a captured suppression carries no detail and is dropped
///       — the default output path never includes anything from this file;
///   (b) with it on, a suppression is re-emitted as a diagnostic-shaped map
///       tagged with the correct `suppressedBy` string for its kind.
library;

import 'package:test/test.dart';

// ignore: avoid_relative_lib_imports
import '../../bin/audit.dart' show suppressedByLabel, suppressedDiagnosticMaps;
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show SuppressionKind, SuppressionTracker;

void main() {
  // Every test starts and ends with a clean tracker so ordering between
  // tests (and other test files touching the same process-wide static
  // state) can't leak a stray record or a stuck captureDetails flag.
  setUp(() {
    SuppressionTracker.reset();
    SuppressionTracker.captureDetails = false;
  });
  tearDown(() {
    SuppressionTracker.reset();
    SuppressionTracker.captureDetails = false;
  });

  group('suppressedByLabel', () {
    test('maps each SuppressionKind to its public JSON string', () {
      // ignoreForFile -> 'ignore_for_file' matches the actual comment
      // syntax (// ignore_for_file:) rather than the Dart enum spelling —
      // this is the one mapping worth pinning explicitly.
      expect(suppressedByLabel(SuppressionKind.ignore), 'ignore');
      expect(
        suppressedByLabel(SuppressionKind.ignoreForFile),
        'ignore_for_file',
      );
      expect(suppressedByLabel(SuppressionKind.baseline), 'baseline');
    });
  });

  group('suppressedDiagnosticMaps', () {
    test('flag absent (captureDetails off): suppressions are captured with no '
        'detail, so nothing is emitted — the default output path is '
        'unaffected by any suppression that occurred during the scan', () {
      // captureDetails stays false here — this is what happens when
      // --include-suppressed is never passed: SuppressionTracker.record
      // is still called by the reporter on every suppression (it always
      // is, flag or not), but drops the detail fields at record() time.
      SuppressionTracker.record(
        rule: 'no_empty_block',
        file: '/proj/lib/a.dart',
        line: 10,
        kind: SuppressionKind.ignore,
        severity: 'WARNING',
        problemMessage: '[no_empty_block] ...',
        correctionMessage: 'Add a body or remove the block.',
        impact: 'warning',
      );

      final maps = suppressedDiagnosticMaps(minSeverity: null, minImpact: null);

      // No severity survived being recorded without captureDetails, so
      // suppressedDiagnosticMaps' null-severity guard drops the record.
      expect(maps, isEmpty);
    });

    test('flag present (captureDetails on): a suppressed finding is re-emitted '
        'as a diagnostic-shaped map tagged with suppressedBy', () {
      SuppressionTracker.captureDetails = true;
      SuppressionTracker.record(
        rule: 'no_empty_block',
        file: '/proj/lib/a.dart',
        line: 10,
        kind: SuppressionKind.ignore,
        column: 3,
        endLine: 10,
        endColumn: 20,
        severity: 'WARNING',
        problemMessage: '[no_empty_block] Empty block found.',
        correctionMessage: 'Add a body or remove the block.',
        impact: 'warning',
      );

      final maps = suppressedDiagnosticMaps(minSeverity: null, minImpact: null);

      expect(maps, hasLength(1));
      final entry = maps.single;
      expect(entry['ruleName'], 'no_empty_block');
      expect(entry['filePath'], '/proj/lib/a.dart');
      expect(entry['line'], 10);
      expect(entry['column'], 3);
      expect(entry['endLine'], 10);
      expect(entry['endColumn'], 20);
      expect(entry['severity'], 'WARNING');
      expect(entry['impact'], 'warning');
      expect(entry['problemMessage'], '[no_empty_block] Empty block found.');
      expect(entry['correctionMessage'], 'Add a body or remove the block.');
      // The one field a normal (non-suppressed) diagnostic never carries.
      expect(entry['suppressedBy'], 'ignore');
    });

    test('defaults column/endLine/endColumn when the reporter could not '
        'resolve a span (token/offset paths without a node)', () {
      SuppressionTracker.captureDetails = true;
      SuppressionTracker.record(
        rule: 'avoid_print_in_production',
        file: '/proj/lib/b.dart',
        line: 5,
        kind: SuppressionKind.baseline,
        // column/endLine/endColumn intentionally omitted.
        severity: 'ERROR',
        problemMessage: '[avoid_print_in_production] ...',
        impact: 'error',
      );

      final entry = suppressedDiagnosticMaps(
        minSeverity: null,
        minImpact: null,
      ).single;

      expect(entry['column'], 1);
      expect(entry['endLine'], 5);
      expect(entry['endColumn'], 1);
      expect(entry['suppressedBy'], 'baseline');
    });

    test('min-severity / min-impact post-filters apply to suppressed '
        'findings the same way they apply to real ones', () {
      SuppressionTracker.captureDetails = true;
      SuppressionTracker.record(
        rule: 'rule_a',
        file: '/proj/lib/a.dart',
        line: 1,
        kind: SuppressionKind.ignore,
        severity: 'INFO',
        problemMessage: '[rule_a] ...',
        impact: 'info',
      );
      SuppressionTracker.record(
        rule: 'rule_b',
        file: '/proj/lib/a.dart',
        line: 2,
        kind: SuppressionKind.ignore,
        severity: 'ERROR',
        problemMessage: '[rule_b] ...',
        impact: 'error',
      );

      final filtered = suppressedDiagnosticMaps(
        minSeverity: 'warning',
        minImpact: null,
      );

      expect(filtered, hasLength(1));
      expect(filtered.single['ruleName'], 'rule_b');
    });
  });
}
