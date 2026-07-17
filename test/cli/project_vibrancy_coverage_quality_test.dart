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

  group('ageScoreFromDays', () {
    // Positive pin for the 2026-07-16 bug fix: the previous formula
    // (`e * -days / 365`, clamped) returned 0 for EVERY positive age, so a
    // passing "returns a number" test would not have caught it — these pin
    // actual curve values.
    test('code touched today scores 100', () {
      expect(ageScoreFromDays(0), closeTo(100.0, 0.001));
    });

    test('one-year-old code scores ~36.8 (exp decay), not 0', () {
      expect(ageScoreFromDays(365), closeTo(36.788, 0.01));
    });

    test('unknown age (no git history) scores neutral 50', () {
      expect(ageScoreFromDays(null), 50.0);
    });
  });

  group('computeFreshCodeFlag', () {
    test('flags complex code rewritten within the 90-day window', () {
      expect(
        computeFreshCodeFlag(medianAgeDays: 10, complexity: 15),
        isTrue,
      );
      // Boundary: exactly 90 days is still inside the window.
      expect(
        computeFreshCodeFlag(medianAgeDays: 90, complexity: 11),
        isTrue,
      );
    });

    test('false when the code is old, however complex', () {
      expect(
        computeFreshCodeFlag(medianAgeDays: 91, complexity: 40),
        isFalse,
      );
    });

    test('false when fresh but simple (complexity at or below 10)', () {
      expect(
        computeFreshCodeFlag(medianAgeDays: 1, complexity: 10),
        isFalse,
      );
    });

    test('null age (no git history) never flags', () {
      // Absence of blame data is not evidence of freshness — a repo without
      // history must not paint every complex function as fresh_code.
      expect(
        computeFreshCodeFlag(medianAgeDays: null, complexity: 40),
        isFalse,
      );
    });
  });
}
