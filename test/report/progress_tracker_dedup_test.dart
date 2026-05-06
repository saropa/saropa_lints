/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `progress_tracker_dedup_test` (progress tracker dedup).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'dart:io' show Directory, Platform;

import 'package:saropa_lints/src/saropa_lint_rule.dart' show ProgressTracker;
import 'package:test/test.dart';

// ProgressTracker file-level dedup of repeated diagnostics.

void main() {
  late Directory tempDir;
  late String filePath;

  setUp(() {
    ProgressTracker.reset();
    tempDir = Directory.systemTemp.createTempSync('progress_tracker_dedup_');
    filePath =
        '${tempDir.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}a.dart';
  });

  tearDown(() {
    ProgressTracker.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('dedup is offset-based (same offset => counted once)', () {
    ProgressTracker.recordFile(filePath);

    ProgressTracker.recordViolation(
      severity: 'WARNING',
      ruleName: 'test_rule',
      line: 10,
      offset: 42,
    );
    ProgressTracker.recordViolation(
      severity: 'WARNING',
      ruleName: 'test_rule',
      line: 10,
      offset: 42,
    );

    final data = ProgressTracker.reportData;
    expect(data.violationsFound, 1);
    expect(data.issuesByFile[filePath], 1);
  });

  test('dedup allows same line with different offsets', () {
    ProgressTracker.recordFile(filePath);

    ProgressTracker.recordViolation(
      severity: 'WARNING',
      ruleName: 'test_rule',
      line: 10,
      offset: 10,
    );
    ProgressTracker.recordViolation(
      severity: 'WARNING',
      ruleName: 'test_rule',
      line: 10,
      offset: 20,
    );

    final data = ProgressTracker.reportData;
    expect(data.violationsFound, 2);
    expect(data.issuesByFile[filePath], 2);
  });
}
