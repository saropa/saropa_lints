import 'dart:io' show Directory;

import 'package:saropa_lints/src/report/batch_data.dart';
import 'package:saropa_lints/src/report/report_consolidator.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String projectRoot;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('report_consolidator_test_');
    projectRoot = tempDir.path;
  });

  tearDown(() {
    ReportConsolidator.cleanupSession(projectRoot);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ReportConsolidator path deduplication', () {
    test('same violation with absolute and relative path counts once', () {
      final sessionId = ReportConsolidator.initSession(projectRoot);
      final rootNorm = projectRoot.replaceAll('\\', '/');

      final violationRel = ViolationRecord(
        rule: 'test_rule',
        file: 'lib/foo.dart',
        line: 10,
        message: 'Test message',
      );
      final violationAbs = ViolationRecord(
        rule: 'test_rule',
        file: '$rootNorm/lib/foo.dart',
        line: 10,
        message: 'Test message',
      );

      final batch1 = BatchData(
        sessionId: sessionId,
        isolateId: 'iso1',
        updatedAt: DateTime.now(),
        config: null,
        analyzedFiles: ['lib/foo.dart'],
        issuesByFile: {'lib/foo.dart': 1},
        issuesByRule: {'test_rule': 1},
        ruleSeverities: {'test_rule': 'WARNING'},
        severityCounts: const SeverityCounts(error: 0, warning: 1, info: 0),
        violations: {
          LintImpact.high: [violationRel],
        },
      );
      final batch2 = BatchData(
        sessionId: sessionId,
        isolateId: 'iso2',
        updatedAt: DateTime.now(),
        config: null,
        analyzedFiles: ['$rootNorm/lib/foo.dart'],
        issuesByFile: {'$rootNorm/lib/foo.dart': 1},
        issuesByRule: {'test_rule': 1},
        ruleSeverities: {'test_rule': 'WARNING'},
        severityCounts: const SeverityCounts(error: 0, warning: 1, info: 0),
        violations: {
          LintImpact.high: [violationAbs],
        },
      );

      ReportConsolidator.writeBatch(projectRoot, batch1);
      ReportConsolidator.writeBatch(projectRoot, batch2);

      final consolidated = ReportConsolidator.consolidate(
        projectRoot,
        sessionId,
      );

      expect(consolidated, isNotNull);
      expect(consolidated!.total, 1);
      expect(consolidated.filesWithIssues, 1);
      expect(consolidated.filesAnalyzed, 1);

      final list = consolidated.violations[LintImpact.high];
      expect(list, isNotNull);
      expect(list!.length, 1);
      expect(list.single.file, 'lib/foo.dart');
      expect(list.single.rule, 'test_rule');
      expect(list.single.line, 10);
    });
  });
}
