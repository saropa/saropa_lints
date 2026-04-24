// Tests for ReportSynthesis — the pure computation module that turns the
// consolidated batch aggregates into concentration / triage / delta views
// consumed by the text report writer.
//
// These tests exercise math and threshold gating only. Text-rendering
// assertions (exact section layout) live alongside AnalysisReporter; this
// file's contract is "given counts + severities + classification sets,
// the synthesis returns the expected structure".

import 'dart:io' show Directory, File, Platform;

import 'package:saropa_lints/src/report/report_synthesis.dart';
import 'package:test/test.dart';

void main() {
  group('ReportSynthesis.buildRuleRows', () {
    test('sorts rows descending by count and derives share', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'rule_a': 100, 'rule_b': 20, 'rule_c': 80},
        ruleSeverities: {
          'rule_a': 'WARNING',
          'rule_b': 'INFO',
          'rule_c': 'ERROR',
        },
        saropaRuleNames: {'rule_a', 'rule_c'},
        fixableRuleNames: {'rule_a'},
      );

      expect(rows.map((r) => r.name).toList(), ['rule_a', 'rule_c', 'rule_b']);
      // 100/200 = 0.5; tolerate fp noise.
      expect(rows[0].share, closeTo(0.5, 1e-9));
      expect(rows[0].severity, 'WARNING');
      expect(rows[0].source, RuleSource.saropa);
      expect(rows[0].fixable, isTrue);
      expect(rows[2].fixable, isFalse);
    });

    test('classifies known dart-lints rules', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'depend_on_referenced_packages': 10},
        ruleSeverities: {'depend_on_referenced_packages': 'WARNING'},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      expect(rows.single.source, RuleSource.dartLints);
    });

    test('classifies unknown non-saropa rules as other', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'some_third_party_rule': 5},
        ruleSeverities: {'some_third_party_rule': 'WARNING'},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      expect(rows.single.source, RuleSource.other);
    });

    test('empty input returns empty list', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: const <String, int>{},
        ruleSeverities: const <String, String>{},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      expect(rows, isEmpty);
    });
  });

  group('ReportSynthesis.buildConcentration', () {
    test('fires dominant-rule trigger when top rule >= cutoff', () {
      // 96.8% matches the real-world contacts project scenario from the
      // bug report: one rule is the entire backlog.
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'top_rule': 22695, 'other_a': 347, 'other_b': 98},
        ruleSeverities: {
          'top_rule': 'WARNING',
          'other_a': 'INFO',
          'other_b': 'WARNING',
        },
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      final c = ReportSynthesis.buildConcentration(rows: rows, total: 23434);
      expect(c.dominantRuleTriggered, isTrue);
      expect(c.residualAfterTopRule, 23434 - 22695);
      expect(c.residualAfterTopThree, 23434 - (22695 + 347 + 98));
      expect(c.top, hasLength(3));
      expect(c.shouldRender, isTrue);
    });

    test('fires top-three trigger even when no single rule dominates', () {
      // Each rule is below the 25% dominant cutoff; aggregated they are
      // above the 80% top-three cutoff. Proves the two gates fire
      // independently — the softer "top three are most of it" signal
      // should still surface the callout.
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'a': 24, 'b': 23, 'c': 23, 'd': 15, 'e': 15},
        ruleSeverities: const <String, String>{},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      final c = ReportSynthesis.buildConcentration(rows: rows, total: 100);
      expect(c.dominantRuleTriggered, isFalse);
      // 24+23+23 = 70% — below the default 80% aggregate cutoff.
      expect(c.topThreeTriggered, isFalse);
      // Widen the aggregate cutoff so the softer signal can fire even
      // below the default — verifies the threshold is actually load-bearing.
      final wider = ReportSynthesis.buildConcentration(
        rows: rows,
        total: 100,
        thresholds: const SynthesisThresholds(topThreeShareCutoff: 0.60),
      );
      expect(wider.topThreeTriggered, isTrue);
      expect(wider.shouldRender, isTrue);
    });

    test('no trigger when distribution is flat', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {'a': 20, 'b': 20, 'c': 20, 'd': 20, 'e': 20},
        ruleSeverities: const <String, String>{},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      final c = ReportSynthesis.buildConcentration(rows: rows, total: 100);
      expect(c.dominantRuleTriggered, isFalse);
      expect(c.topThreeTriggered, isFalse);
      expect(c.shouldRender, isFalse);
    });

    test('empty rows produce safe zero summary', () {
      final c = ReportSynthesis.buildConcentration(
        rows: const <RuleRow>[],
        total: 0,
      );
      expect(c.shouldRender, isFalse);
      expect(c.residualAfterTopRule, 0);
      expect(c.residualAfterTopThree, 0);
    });
  });

  group('ReportSynthesis.buildTriage', () {
    test('splits rules into suppress vs auto-fix groups', () {
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: {
          'non_fix_a': 500,
          'fix_a': 300,
          'non_fix_b': 200,
          'fix_b': 100,
        },
        ruleSeverities: const <String, String>{},
        saropaRuleNames: {'fix_a', 'fix_b'},
        fixableRuleNames: {'fix_a', 'fix_b'},
      );
      final t = ReportSynthesis.buildTriage(
        rows: rows,
        total: 1100,
        hasFileImportance: true,
      );
      expect(t.suppressCandidates.map((r) => r.name).toList(), [
        'non_fix_a',
        'non_fix_b',
      ]);
      expect(t.autoFixableCandidates.map((r) => r.name).toList(), [
        'fix_a',
        'fix_b',
      ]);
      // Residual = total - (non_fix_a + non_fix_b) = 1100 - 700 = 400
      expect(t.residualAfterSuppress, 400);
      expect(t.shouldRender, isTrue);
      expect(t.hasFileImportance, isTrue);
    });

    test('caps each group at maxPerGroup', () {
      final issuesByRule = <String, int>{};
      for (var i = 0; i < 10; i++) {
        issuesByRule['rule_$i'] = 100 - i;
      }
      final rows = ReportSynthesis.buildRuleRows(
        issuesByRule: issuesByRule,
        ruleSeverities: const <String, String>{},
        saropaRuleNames: const <String>{},
        fixableRuleNames: const <String>{},
      );
      final t = ReportSynthesis.buildTriage(
        rows: rows,
        total: rows.fold<int>(0, (s, r) => s + r.count),
        maxPerGroup: 3,
      );
      expect(t.suppressCandidates, hasLength(3));
    });

    test('empty rows → empty plan, nothing to render', () {
      final t = ReportSynthesis.buildTriage(rows: const <RuleRow>[], total: 0);
      expect(t.shouldRender, isFalse);
    });
  });

  group('ReportSynthesis.findPreviousRunTotal', () {
    late Directory tempDir;
    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('report_synthesis_test_');
    });
    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // Helper: write a minimal report log with a parseable total-issues line.
    String writeReport(String filename, int total) {
      final sep = Platform.pathSeparator;
      final path = '${tempDir.path}$sep$filename';
      File(path).writeAsStringSync('''
Saropa Lints Analysis Report
Generated: 2026-04-24T10:00:00Z
Project: d:/src/contacts
======================================================================

OVERVIEW
  Total issues:       $total
  Files analyzed:     100
  Files with issues:  50
  Rules triggered:    10
''');
      return path;
    }

    test('returns null when folder has no prior reports', () {
      writeReport('20260424_093000_saropa_lint_report.log', 1000);
      final delta = ReportSynthesis.findPreviousRunTotal(
        dateFolder: tempDir.path,
        currentReportFilename: '20260424_093000_saropa_lint_report.log',
        currentTotal: 1000,
      );
      expect(delta, isNull);
    });

    test('parses prior total and computes delta', () {
      writeReport('20260424_090000_saropa_lint_report.log', 23434);
      writeReport('20260424_093000_saropa_lint_report.log', 13568);
      final delta = ReportSynthesis.findPreviousRunTotal(
        dateFolder: tempDir.path,
        currentReportFilename: '20260424_093000_saropa_lint_report.log',
        currentTotal: 13568,
      );
      expect(delta, isNotNull);
      expect(delta!.previousTotal, 23434);
      expect(delta.currentTotal, 13568);
      expect(delta.delta, -9866);
      expect(
        delta.previousReportFile,
        '20260424_090000_saropa_lint_report.log',
      );
    });

    test('picks the most recent prior when multiple exist', () {
      writeReport('20260424_080000_saropa_lint_report.log', 50000);
      writeReport('20260424_090000_saropa_lint_report.log', 23434);
      writeReport('20260424_093000_saropa_lint_report.log', 13568);
      final delta = ReportSynthesis.findPreviousRunTotal(
        dateFolder: tempDir.path,
        currentReportFilename: '20260424_093000_saropa_lint_report.log',
        currentTotal: 13568,
      );
      // Lexicographic sort → the 09:00 file is the most recent prior.
      expect(delta!.previousTotal, 23434);
    });

    test('tolerates unparseable prior file by falling back to older one', () {
      // Older file is parseable; newer prior is garbage — synthesis should
      // skip the bad one rather than return null.
      final sep = Platform.pathSeparator;
      File(
        '${tempDir.path}${sep}20260424_090000_saropa_lint_report.log',
      ).writeAsStringSync('no header here, no total line');
      writeReport('20260424_080000_saropa_lint_report.log', 5000);
      final delta = ReportSynthesis.findPreviousRunTotal(
        dateFolder: tempDir.path,
        currentReportFilename: '20260424_093000_saropa_lint_report.log',
        currentTotal: 4000,
      );
      expect(delta, isNotNull);
      expect(delta!.previousTotal, 5000);
    });

    test('returns null when date folder does not exist', () {
      final delta = ReportSynthesis.findPreviousRunTotal(
        dateFolder: '${tempDir.path}${Platform.pathSeparator}nonexistent',
        currentReportFilename: '20260424_093000_saropa_lint_report.log',
        currentTotal: 100,
      );
      expect(delta, isNull);
    });
  });

  group('RunDelta', () {
    test('percentChange guards against zero previous', () {
      const d = RunDelta(
        previousTotal: 0,
        currentTotal: 10,
        previousReportFile: 'x.log',
      );
      expect(d.percentChange, 0.0);
    });

    test('negative delta for improving counts', () {
      const d = RunDelta(
        previousTotal: 100,
        currentTotal: 40,
        previousReportFile: 'x.log',
      );
      expect(d.delta, -60);
      expect(d.percentChange, closeTo(-60.0, 1e-9));
    });
  });
}
