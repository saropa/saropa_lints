/// Tests the parallel scan engine with fake workers and fake memory readings:
/// ordering, throttling under pressure, early abort, hang/crash recovery and
/// the in-process fallback.
library;

import 'dart:async';
import 'dart:isolate';

import 'package:saropa_lints/src/scan/parallel_scan_engine.dart';
import 'package:saropa_lints/src/scan/scan_diagnostic.dart';
import 'package:saropa_lints/src/scan/scan_pressure.dart';
import 'package:test/test.dart';

ScanDiagnostic _diag(String file) => ScanDiagnostic(
  ruleName: 'fake_rule',
  filePath: file,
  line: 1,
  column: 1,
  offset: 0,
  length: 1,
  endLine: 1,
  endColumn: 2,
  severity: 'WARNING',
  problemMessage: 'x',
);

/// Worker entry: behavior is driven by the sendable spec map.
///   perFileMs  - simulated work per file
///   hang       - substring of a path that never finishes
///   die        - substring of a path that kills the worker isolate
///   throwOn    - substring of a path whose scan throws
///   failOpen   - true → the worker fails to start
void _fakeWorkerMain(WorkerBootstrap boot) {
  runWorkerLoop(boot, (Object raw) async {
    final spec = raw as Map;
    if (spec['failOpen'] == true) throw StateError('cannot open');
    return (List<String> files) async {
      final out = <ScanDiagnostic>[];
      for (final f in files) {
        final hang = spec['hang'] as String?;
        final die = spec['die'] as String?;
        final throwOn = spec['throwOn'] as String?;
        if (hang != null && f.contains(hang)) {
          await Future<void>.delayed(const Duration(minutes: 5));
        }
        if (die != null && f.contains(die)) {
          Isolate.current.kill(priority: Isolate.immediate);
          await Future<void>.delayed(const Duration(seconds: 5));
        }
        if (throwOn != null && f.contains(throwOn)) {
          throw StateError('boom on $f');
        }
        final ms = spec['perFileMs'] as int? ?? 0;
        if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
        out.add(_diag(f));
      }
      return ChunkOutcome(diagnostics: out);
    };
  });
}

Future<ParallelScanResult> _run(
  List<String> files, {
  Map<String, Object?> spec = const {},
  int jobs = 3,
  int Function()? rss,
  int? Function()? avail,
  Duration chunkTimeout = const Duration(seconds: 30),
  PressureLimits limits = const PressureLimits(
    maxMemoryMb: 1000,
    reserveMb: 500,
  ),
  int abortAfterCriticalTicks = 6,
  int rampUpAfterCalmTicks = 20,
}) {
  return runChunkedScan(
    files: files,
    options: ParallelScanOptions(
      jobs: jobs,
      limits: limits,
      chunkTimeout: chunkTimeout,
      tickInterval: const Duration(milliseconds: 40),
      progress: ProgressStyle.none,
      chunkSize: 5,
      shedCooldownTicks: 1,
      abortAfterCriticalTicks: abortAfterCriticalTicks,
      rampUpAfterCalmTicks: rampUpAfterCalmTicks,
    ),
    spec: spec,
    workerEntry: _fakeWorkerMain,
    inlineScan: (files) async =>
        ChunkOutcome(diagnostics: [for (final f in files) _diag(f)]),
    readRssMb: rss ?? () => 100,
    readAvailableMb: avail ?? () => 8000,
  );
}

List<String> _files(int n) => [for (var i = 0; i < n; i++) 'f$i.dart'];

void main() {
  group('runChunkedScan', () {
    test('merges results in input order regardless of worker count', () async {
      final files = _files(60);
      for (final jobs in [1, 2, 4]) {
        final r = await _run(files, jobs: jobs, spec: {'perFileMs': 3});
        expect(
          r.diagnostics.map((d) => d.filePath).toList(),
          files,
          reason: 'jobs=$jobs',
        );
        expect(r.report.filesScanned, 60);
        expect(r.report.aborted, isFalse);
      }
    });

    test('sheds workers under memory pressure and still finishes', () async {
      var ticks = 0;
      final r = await _run(
        _files(80),
        spec: {'perFileMs': 25},
        jobs: 4,
        // Healthy for two ticks, then the machine runs out of free memory.
        avail: () => ++ticks < 3 ? 8000 : 300,
      );
      expect(r.diagnostics.length, 80);
      expect(r.report.minAllowedWorkers, 1);
      expect(r.report.throttleEvents.any((e) => e.to < e.from), isTrue);
      expect(r.report.aborted, isFalse);
    });

    test('ramps back up once pressure eases', () async {
      var ticks = 0;
      final r = await _run(
        _files(200),
        spec: {'perFileMs': 10},
        jobs: 3,
        rampUpAfterCalmTicks: 3,
        avail: () {
          ticks++;
          return (ticks > 2 && ticks < 8) ? 300 : 8000;
        },
      );
      expect(r.diagnostics.length, 200);
      expect(r.report.throttleEvents.any((e) => e.to > e.from), isTrue);
    });

    test(
      'stops early with partial results when one worker still exceeds the budget',
      () async {
        final r = await _run(
          _files(400),
          spec: {'perFileMs': 20},
          jobs: 2,
          rss: () => 5000,
          abortAfterCriticalTicks: 3,
        );
        expect(r.report.aborted, isTrue);
        expect(r.report.abortReason, contains('budget'));
        expect(r.diagnostics.length, lessThan(400));
      },
    );

    test('a hanging file is skipped and the rest still scan', () async {
      final files = _files(20)..[7] = 'hang_me.dart';
      final r = await _run(
        files,
        spec: {'hang': 'hang_me'},
        jobs: 2,
        chunkTimeout: const Duration(milliseconds: 800),
      );
      expect(r.report.skippedFiles, ['hang_me.dart']);
      expect(r.diagnostics.length, 19);
      expect(
        r.diagnostics.map((d) => d.filePath),
        isNot(contains('hang_me.dart')),
      );
    });

    test(
      'a worker that dies mid-chunk is replaced and its chunk retried',
      () async {
        final files = _files(20)..[4] = 'die_here.dart';
        final r = await _run(files, spec: {'die': 'die_here'}, jobs: 2);
        expect(r.report.skippedFiles, ['die_here.dart']);
        expect(r.diagnostics.length, 19);
        expect(r.report.workersRestarted, greaterThan(0));
      },
    );

    test('a scan error on one file skips only that file', () async {
      final files = _files(15)..[3] = 'bad.dart';
      final r = await _run(files, spec: {'throwOn': 'bad'}, jobs: 2);
      expect(r.report.skippedFiles, ['bad.dart']);
      expect(r.diagnostics.length, 14);
    });

    test(
      'falls back to in-process scanning when workers cannot start',
      () async {
        final r = await _run(_files(12), spec: {'failOpen': true}, jobs: 2);
        expect(r.report.usedFallback, isTrue);
        expect(r.diagnostics.map((d) => d.filePath).toList(), _files(12));
      },
    );

    test('emits machine-readable events in json mode', () async {
      final lines = <String>[];
      await runChunkedScan(
        files: _files(30),
        options: ParallelScanOptions(
          jobs: 2,
          limits: const PressureLimits(maxMemoryMb: 1000, reserveMb: 500),
          tickInterval: const Duration(milliseconds: 40),
          progress: ProgressStyle.json,
          onMessage: lines.add,
          chunkSize: 5,
        ),
        spec: const {'perFileMs': 10},
        workerEntry: _fakeWorkerMain,
        inlineScan: (f) async => const ChunkOutcome(diagnostics: []),
        readRssMb: () => 100,
        readAvailableMb: () => 8000,
      );
      final events = lines
          .where((l) => l.startsWith(kScanEventPrefix))
          .toList();
      expect(events.first, contains('"event":"start"'));
      expect(events.last, contains('"event":"summary"'));
    });
  });
}
