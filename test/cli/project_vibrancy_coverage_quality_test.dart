/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `project_vibrancy_coverage_quality_test` (project vibrancy coverage quality).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:saropa_lints/src/cli/project_vibrancy_coverage_quality.dart';
import 'package:test/test.dart';

// project_vibrancy_coverage_quality: test-vs-prod staleness heuristics.

void main() {
  group('computeTestDriftFlag', () {
    test('flags when prod is 1–30d old and tests are stale enough', () {
      expect(
        computeTestDriftFlag(
          prodDaysSinceCommit: 5,
          newestLinkedTestDaysSinceCommit: 30,
        ),
        isTrue,
      );
    });

    test('false when prod window is outside 1–30 days', () {
      expect(
        computeTestDriftFlag(
          prodDaysSinceCommit: 0.5,
          newestLinkedTestDaysSinceCommit: 100,
        ),
        isFalse,
      );
      expect(
        computeTestDriftFlag(
          prodDaysSinceCommit: 40,
          newestLinkedTestDaysSinceCommit: 500,
        ),
        isFalse,
      );
    });

    test('false when test staleness is below 6× prod staleness', () {
      expect(
        computeTestDriftFlag(
          prodDaysSinceCommit: 5,
          newestLinkedTestDaysSinceCommit: 29,
        ),
        isFalse,
      );
    });
  });
}
