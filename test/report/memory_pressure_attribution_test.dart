/// Pins the three defects fixed after commit e0f0b0bc ("hard RSS valve now
/// checks plugin attribution before pausing rules"):
///
///   1. the bystander decision must latch, so the expensive cache walk in
///      _estimateMemoryUsageMb does not repeat on every sample while the
///      analysis server sits above the cap;
///   2. a trip must be able to release again — tripping clears the plugin's
///      caches, which makes the plugin a bystander, so a release path that
///      tested process RSS alone left rules paused forever;
///   3. the physical-RAM probe must be memoized including its failure result,
///      because the failure case is the one that respawns a subprocess.
///
/// Panic behavior (90% of system RAM) is pinned alongside them because both
/// fixes touch the branch it lives in and it must keep bypassing attribution.
library;

import 'package:saropa_lints/src/project_context.dart'
    show MemoryPressureHandler;
import 'package:test/test.dart';

void main() {
  setUp(() {
    // Clears the attribution latch, shed level, baseline and panic threshold
    // so each test starts from a valve that has never sampled anything.
    MemoryPressureHandler.resetShedStateForTesting();
    MemoryPressureHandler.setHardLimitTrippedForTest(false);
    MemoryPressureHandler.setSoftLimitTrippedForTest(false);
    MemoryPressureHandler.resetEstimateCallCountForTesting();
  });

  tearDown(() {
    // Disarm the valve — a non-zero cap left behind would make every rule
    // callback in a later suite a no-op.
    MemoryPressureHandler.setHardRssLimitMb(0);
    MemoryPressureHandler.setHardLimitTrippedForTest(false);
    MemoryPressureHandler.setPanicRssLimitMbForTest(0);
    MemoryPressureHandler.resetShedStateForTesting();
    // Drop the forced-failure switch; leaking it would make every later cap
    // computation silently fall back to the fixed default.
    MemoryPressureHandler.resetPhysicalMemoryProbeForTesting();
  });

  group('Defect 1 — bystander decision latches', () {
    test('over-cap RSS with a tiny plugin does not pause rules', () {
      // A 1 MB cap is below any real process RSS, so the valve sees "over
      // cap" while this test process holds essentially no plugin caches —
      // exactly the bystander condition.
      MemoryPressureHandler.setHardRssLimitMb(1);
      MemoryPressureHandler.refreshForTesting();

      expect(MemoryPressureHandler.isOverHardLimit, isFalse);
    });

    test('subsequent samples do not re-walk the caches', () {
      MemoryPressureHandler.setHardRssLimitMb(1);
      // First sample makes and latches the bystander decision (and may also
      // emit the periodic trend line, which walks the caches itself).
      MemoryPressureHandler.refreshForTesting();

      // Count only what happens after the decision is latched.
      MemoryPressureHandler.resetEstimateCallCountForTesting();
      for (var i = 0; i < 10; i++) {
        MemoryPressureHandler.refreshForTesting();
      }

      // Before the fix this was 10 — one full walk of the string-intern pool
      // and every cache map per sample, forever.
      expect(MemoryPressureHandler.estimateCallCountForTesting, 0);
      expect(MemoryPressureHandler.isOverHardLimit, isFalse);
    });

    test('the panic threshold trips even while the plugin is a bystander', () {
      MemoryPressureHandler.setHardRssLimitMb(1);
      MemoryPressureHandler.setPanicRssLimitMbForTest(1);

      MemoryPressureHandler.refreshForTesting();

      // Panic is an RSS-only test: it must not sit behind the latch, and must
      // not require the plugin to be a meaningful contributor.
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);
    });
  });

  group('Defect 2 — a trip that cleared its caches can release', () {
    test('release fires on attribution while RSS is still over the cap', () {
      MemoryPressureHandler.setHardRssLimitMb(1);
      // Reproduce the post-trip state: relieve(clearAll: true) has emptied the
      // plugin's caches, the flag is set, and the RSS that remains belongs to
      // the analysis server, so it will never fall below the cap.
      MemoryPressureHandler.relieve(clearAll: true);
      MemoryPressureHandler.setHardLimitTrippedForTest(true);
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);

      MemoryPressureHandler.refreshForTesting();

      // Before the fix the release path tested process RSS alone, so this
      // stayed true for the rest of the session and no rule ever ran again.
      expect(MemoryPressureHandler.isOverHardLimit, isFalse);
    });

    test('panic keeps the valve closed regardless of attribution', () {
      MemoryPressureHandler.setHardRssLimitMb(1);
      MemoryPressureHandler.relieve(clearAll: true);
      MemoryPressureHandler.setHardLimitTrippedForTest(true);
      MemoryPressureHandler.setPanicRssLimitMbForTest(1);

      MemoryPressureHandler.refreshForTesting();

      // Near OOM the process stays paused no matter who allocated the memory.
      expect(MemoryPressureHandler.isOverHardLimit, isTrue);
    });

    test('the release check does not re-walk the caches on every sample', () {
      MemoryPressureHandler.setHardRssLimitMb(1);
      MemoryPressureHandler.setHardLimitTrippedForTest(true);
      // The first refresh takes the attribution release and pre-latches the
      // bystander decision it just made, since RSS is still over the cap.
      MemoryPressureHandler.refreshForTesting();
      MemoryPressureHandler.resetEstimateCallCountForTesting();

      for (var i = 0; i < 10; i++) {
        MemoryPressureHandler.refreshForTesting();
      }

      // The valve is open and latched as bystander, so no walk is needed.
      expect(MemoryPressureHandler.estimateCallCountForTesting, 0);
    });
  });

  group('Defect 3 — physical-memory probe is memoized', () {
    test('a failed detection is cached and never re-probed', () {
      MemoryPressureHandler.resetPhysicalMemoryProbeForTesting(
        forceFailure: true,
      );

      expect(MemoryPressureHandler.totalPhysicalMemoryMbForTesting(), -1);
      expect(MemoryPressureHandler.physicalMemoryProbeCountForTesting, 1);

      for (var i = 0; i < 5; i++) {
        MemoryPressureHandler.totalPhysicalMemoryMbForTesting();
      }

      // Before the fix each of these spawned a fresh PowerShell/wmic process.
      expect(MemoryPressureHandler.physicalMemoryProbeCountForTesting, 1);
    });

    test('the adaptive cap call site does not re-probe after failure', () {
      MemoryPressureHandler.resetPhysicalMemoryProbeForTesting(
        forceFailure: true,
      );

      // ramMb: -1 means "caller had no detection", the branch that used to
      // respawn the probe on every call.
      final first = MemoryPressureHandler.adaptiveRssCapForTesting(4096, -1);
      final second = MemoryPressureHandler.adaptiveRssCapForTesting(4096, -1);

      // Undetectable RAM must select the documented fixed fallback.
      expect(first, 4096);
      expect(second, 4096);
      expect(MemoryPressureHandler.physicalMemoryProbeCountForTesting, 1);
    });

    test('a successful detection is probed once', () {
      MemoryPressureHandler.resetPhysicalMemoryProbeForTesting();

      final first = MemoryPressureHandler.totalPhysicalMemoryMbForTesting();
      final second = MemoryPressureHandler.totalPhysicalMemoryMbForTesting();

      expect(second, first);
      expect(MemoryPressureHandler.physicalMemoryProbeCountForTesting, 1);
    });
  });
}
