/// Pins the spawn-free physical-RAM probe used at plugin start.
///
/// `Plugin.start()` arms the memory subsystem, which needs total RAM. On
/// Windows that used to spawn PowerShell (~360 ms), which delayed every plugin
/// isolate enough for `dart analyze <parent folder>` to exit before the second
/// package reported. These tests check the in-process kernel32 probe returns
/// the real figure, that the memoized probe the plugin calls goes through it
/// (fast, no spawn), and that non-Windows platforms skip FFI entirely.
library;

import 'dart:io';

import 'package:saropa_lints/src/project_context.dart'
    show MemoryPressureHandler;
import 'package:saropa_lints/src/windows_physical_memory.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() {
    // The memoized probe is process-global; clear it so later suites probe
    // again instead of inheriting this file's value or counter.
    MemoryPressureHandler.resetPhysicalMemoryProbeForTesting();
  });

  group('windowsTotalPhysicalMemoryMb', () {
    test('returns null off Windows without touching FFI', () {
      // Only meaningful on non-Windows hosts (testOn below); on Windows the
      // next tests cover the real call.
      expect(windowsTotalPhysicalMemoryMb(), isNull);
    }, testOn: '!windows');

    test('returns the same total as the PowerShell CIM probe', () {
      final mb = windowsTotalPhysicalMemoryMb();
      expect(mb, isNotNull, reason: 'GlobalMemoryStatusEx call failed');
      // Cross-check against the old process-based source of truth, so a wrong
      // struct offset (which would still yield "some number") is caught.
      final cim = Process.runSync('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      // PowerShell missing on the host is an environment gap, not a probe
      // defect; the plausibility bounds below still apply.
      final cimBytes = cim.exitCode == 0
          ? int.tryParse((cim.stdout as String).trim())
          : null;
      if (cimBytes != null) {
        // Both read the same kernel counter; allow 1 MB for rounding.
        expect((mb! - cimBytes ~/ (1 << 20)).abs(), lessThanOrEqualTo(1));
      }
      // Any real Windows machine has between 256 MB and 64 TB.
      expect(mb, inInclusiveRange(256, 64 * 1024 * 1024));
    }, testOn: 'windows');
  });

  group('memoized probe used by Plugin.start()', () {
    test('Windows probe finishes without a process spawn', () {
      MemoryPressureHandler.resetPhysicalMemoryProbeForTesting();
      final sw = Stopwatch()..start();
      final mb = MemoryPressureHandler.totalPhysicalMemoryMbForTesting();
      sw.stop();
      expect(mb, greaterThan(0));
      // The PowerShell spawn this replaces took ~360 ms. 150 ms leaves room
      // for a loaded CI host while still failing if the probe falls back to
      // spawning a process.
      expect(sw.elapsedMilliseconds, lessThan(150));
      // Same value as the direct FFI call proves the FFI path answered.
      expect(mb, windowsTotalPhysicalMemoryMb());
      expect(MemoryPressureHandler.physicalMemoryProbeCountForTesting, 1);
    }, testOn: 'windows');
  });
}
