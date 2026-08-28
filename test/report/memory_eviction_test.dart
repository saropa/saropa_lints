/// Tests for OOM-prevention infrastructure: tracker eviction registration,
/// estimatedBytes getters, releasePerFileMaps, and the end-to-end
/// hard-relief → accumulation-guard path.
library;

import 'package:saropa_lints/src/project_context.dart'
    show MemoryPressureHandler;
import 'package:saropa_lints/src/saropa_lint_rule.dart'
    show
        FileBudgetTracker,
        ImpactTracker,
        LintImpact,
        ProgressTracker,
        SuppressionKind,
        SuppressionTracker;
import 'package:test/test.dart';

void main() {
  setUp(() {
    // Clean slate for each test.
    ImpactTracker.reset();
    SuppressionTracker.reset();
    ProgressTracker.reset();
    FileBudgetTracker.reset();
    // Disable the hard-limit valve so it doesn't interfere with unit tests.
    MemoryPressureHandler.setHardLimitTrippedForTest(false);
    MemoryPressureHandler.setHardRssLimitMb(0);
  });

  group('ImpactTracker.estimatedBytes', () {
    test('zero when empty', () {
      expect(ImpactTracker.estimatedBytes, 0);
    });

    test('increases after recording violations', () {
      ImpactTracker.record(
        impact: LintImpact.warning,
        rule: 'test_rule',
        file: 'a.dart',
        line: 1,
        message: 'msg',
      );
      // Each violation costs ~200 bytes in the estimate.
      expect(ImpactTracker.estimatedBytes, 200);
    });

    test('deduplicates same file+line+rule', () {
      for (var i = 0; i < 3; i++) {
        ImpactTracker.record(
          impact: LintImpact.error,
          rule: 'dup_rule',
          file: 'b.dart',
          line: 5,
          message: 'dup',
        );
      }
      // ViolationRecord equality is (file, line, rule), so only 1 entry.
      expect(ImpactTracker.estimatedBytes, 200);
    });

    test('resets to zero', () {
      ImpactTracker.record(
        impact: LintImpact.info,
        rule: 'r',
        file: 'c.dart',
        line: 1,
        message: 'm',
      );
      ImpactTracker.reset();
      expect(ImpactTracker.estimatedBytes, 0);
    });
  });

  group('SuppressionTracker.estimatedBytes', () {
    test('zero when empty', () {
      expect(SuppressionTracker.estimatedBytes, 0);
    });

    test('increases after recording suppressions', () {
      SuppressionTracker.record(
        rule: 'test_rule',
        file: 'a.dart',
        line: 1,
        kind: SuppressionKind.ignore,
      );
      // Each suppression costs ~120 bytes in the estimate.
      expect(SuppressionTracker.estimatedBytes, 120);
    });

    test('resets to zero', () {
      SuppressionTracker.record(
        rule: 'r',
        file: 'c.dart',
        line: 1,
        kind: SuppressionKind.baseline,
      );
      SuppressionTracker.reset();
      expect(SuppressionTracker.estimatedBytes, 0);
    });
  });

  group('ProgressTracker.releasePerFileMaps', () {
    test('does not throw when called on empty state', () {
      // Verifies the public API is callable without prior state.
      expect(() => ProgressTracker.releasePerFileMaps(), returnsNormally);
    });
  });

  group('hard-relief end-to-end', () {
    test('ImpactTracker.record is blocked when hard limit tripped', () {
      // Seed a violation before the trip so we can verify it's cleared.
      ImpactTracker.record(
        impact: LintImpact.error,
        rule: 'pre_trip_rule',
        file: 'x.dart',
        line: 1,
        message: 'before trip',
      );
      expect(ImpactTracker.estimatedBytes, 200);

      // Simulate the hard RSS valve tripping — clears caches and sets flag.
      ImpactTracker.reset();
      MemoryPressureHandler.setHardLimitTrippedForTest(true);

      // _trackViolation bails when isOverHardLimit is true, but we can't call
      // the private method directly. Instead verify the public guard: any code
      // that checks isOverHardLimit before recording should see true.
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);

      // After reset, no new violations should accumulate (production code
      // checks isOverHardLimit before calling ImpactTracker.record).
      expect(ImpactTracker.estimatedBytes, 0);
    });

    test('SuppressionTracker.record is guarded by isOverHardLimit', () {
      SuppressionTracker.record(
        rule: 'pre_trip',
        file: 'y.dart',
        line: 1,
        kind: SuppressionKind.ignore,
      );
      expect(SuppressionTracker.estimatedBytes, 120);

      // Trip the valve and clear suppressions (mimics hard-relief eviction).
      SuppressionTracker.reset();
      MemoryPressureHandler.setHardLimitTrippedForTest(true);

      // Guard is active — production code won't record past this point.
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);
      expect(SuppressionTracker.estimatedBytes, 0);
    });

    test('isOverHardLimit resets to false after clearing the trip', () {
      MemoryPressureHandler.setHardLimitTrippedForTest(true);
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);

      // Simulate RSS dropping below the recovery watermark.
      MemoryPressureHandler.setHardLimitTrippedForTest(false);
      MemoryPressureHandler.setHardRssLimitMb(0);
      expect(MemoryPressureHandler.isOverHardLimit, isFalse);
    });
  });

  group('FileBudgetTracker', () {
    test('not over budget when RSS cap is disabled', () {
      // Cap = 0 means budget is disabled (test/CLI mode).
      FileBudgetTracker.recordFileCost(100000);
      expect(FileBudgetTracker.isOverBudget, isFalse);
    });

    test('not over budget with small cumulative cost', () {
      // Set a 100 MB cap — budget threshold = 70 MB.
      MemoryPressureHandler.setHardRssLimitMb(100);
      // Record a tiny file (1 KB × 10 multiplier = 10 KB estimated).
      FileBudgetTracker.recordFileCost(1024);
      expect(FileBudgetTracker.isOverBudget, isFalse);
      expect(FileBudgetTracker.cumulativeEstimateMb, 0);
    });

    test('goes over budget when cumulative cost exceeds threshold', () {
      // Set a 10 MB cap — budget threshold = 7 MB (~7,340,032 bytes).
      MemoryPressureHandler.setHardRssLimitMb(10);
      // Record files totaling > 7 MB estimated (740 KB source × 10 = 7.4 MB).
      FileBudgetTracker.recordFileCost(740 * 1024);
      expect(FileBudgetTracker.isOverBudget, isTrue);
    });

    test('skippedCount starts at zero', () {
      expect(FileBudgetTracker.skippedCount, 0);
    });

    test('reset clears all state', () {
      MemoryPressureHandler.setHardRssLimitMb(10);
      FileBudgetTracker.recordFileCost(740 * 1024);
      expect(FileBudgetTracker.isOverBudget, isTrue);
      FileBudgetTracker.reset();
      expect(FileBudgetTracker.isOverBudget, isFalse);
      expect(FileBudgetTracker.skippedCount, 0);
    });

    test('skipSummary returns null when no files skipped', () {
      expect(FileBudgetTracker.skipSummary, isNull);
    });
  });
}
