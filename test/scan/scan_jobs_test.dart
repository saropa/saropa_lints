/// Tests the worker-count recommendation, machine detection parsing, CLI
/// flag parsing, and an end-to-end check that a parallel scan matches a
/// serial one.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/scan/scan_cli_args.dart';
import 'package:saropa_lints/src/scan/scan_jobs.dart';
import 'package:test/test.dart';

MachineInfo _machine({
  int cores = 8,
  int? avail = 32000,
  int? total = 32000,
  bool ci = false,
  bool cpuContainer = false,
}) => MachineInfo(
  cores: cores,
  availableMemoryMb: avail,
  totalMemoryMb: total,
  isCi: ci,
  cpuLimitedByContainer: cpuContainer,
);

void main() {
  group('parseJobsValue', () {
    test('accepts auto, off and positive integers', () {
      expect(parseJobsValue('auto'), 0);
      expect(parseJobsValue('AUTO'), 0);
      expect(parseJobsValue('off'), 1);
      expect(parseJobsValue('serial'), 1);
      expect(parseJobsValue('4'), 4);
    });
    test('rejects zero, negatives and junk', () {
      expect(parseJobsValue('0'), isNull);
      expect(parseJobsValue('-2'), isNull);
      expect(parseJobsValue('lots'), isNull);
    });
  });

  group('recommendJobs', () {
    test('leaves one core free on interactive machines', () {
      final r = recommendJobs(
        fileCount: 5000,
        cores: 4,
        availableMemoryMb: 64000,
      );
      expect(r.jobs, 3);
      expect(r.limitedBy, 'CPU');
    });
    test('uses every core in CI', () {
      final r = recommendJobs(
        fileCount: 5000,
        cores: 4,
        availableMemoryMb: 64000,
        isCi: true,
      );
      expect(r.jobs, 4);
    });
    test('is capped by memory', () {
      // (2000 * 0.5 - 300) / 300 = 2 workers.
      final r = recommendJobs(
        fileCount: 5000,
        cores: 32,
        availableMemoryMb: 2000,
      );
      expect(r.jobs, 2);
      expect(r.limitedBy, 'memory');
    });
    test('is capped by the ceiling on big machines', () {
      final r = recommendJobs(
        fileCount: 50000,
        cores: 64,
        availableMemoryMb: 256000,
      );
      expect(r.jobs, kMaxRecommendedJobs);
    });
    test('small scans stay serial', () {
      expect(
        recommendJobs(fileCount: 40, cores: 16, availableMemoryMb: 64000).jobs,
        1,
      );
    });
    test('unknown memory still respects CPU and ceiling', () {
      expect(recommendJobs(fileCount: 5000, cores: 4).jobs, 3);
    });
    test('never below one', () {
      expect(
        recommendJobs(fileCount: 0, cores: 1, availableMemoryMb: 10).jobs,
        1,
      );
    });
    test('resolved workers are heavier: fewer, and need more files', () {
      final r = recommendJobs(
        fileCount: 5000,
        cores: 16,
        availableMemoryMb: 64000,
        resolved: true,
      );
      expect(r.jobs, kMaxRecommendedResolvedJobs);
      expect(
        recommendJobs(
          fileCount: 500,
          cores: 16,
          availableMemoryMb: 64000,
          resolved: true,
        ).jobs,
        1,
      );
      // 8 GB free: (8000*0.5-300)/1800 = 2.
      expect(
        recommendJobs(
          fileCount: 5000,
          cores: 16,
          availableMemoryMb: 8000,
          resolved: true,
        ).jobs,
        2,
      );
    });
  });

  group('defaultMaxMemoryMb', () {
    test('has a floor and scales with workers', () {
      expect(defaultMaxMemoryMb(jobs: 1, resolved: false), 1500);
      expect(defaultMaxMemoryMb(jobs: 8, resolved: false), greaterThan(3000));
      expect(defaultMaxMemoryMb(jobs: 1, resolved: true), 4096);
    });
    test('never exceeds 70% of what is free', () {
      expect(
        defaultMaxMemoryMb(jobs: 8, resolved: false, availableMemoryMb: 2000),
        1400,
      );
    });
  });

  group('resolveJobs', () {
    test('unset on a large syntactic scan defaults to auto', () {
      final d = resolveJobs(
        requested: null,
        fileCount: 2000,
        machine: _machine(),
      );
      expect(d.jobs, 7);
      expect(d.notes.single, contains('--jobs 1'));
    });
    test('unset on a small scan stays serial and silent', () {
      final d = resolveJobs(
        requested: null,
        fileCount: 50,
        machine: _machine(),
      );
      expect(d.jobs, 1);
      expect(d.notes, isEmpty);
    });
    test('unset resolved scan stays serial with an opt-in hint', () {
      final d = resolveJobs(
        requested: null,
        fileCount: 5000,
        machine: _machine(),
        resolved: true,
      );
      expect(d.jobs, 1);
      expect(d.notes.single, contains('--jobs 3'));
    });
    test('off forces serial without noise', () {
      final d = resolveJobs(requested: 1, fileCount: 5000, machine: _machine());
      expect(d.jobs, 1);
      expect(d.notes, isEmpty);
    });
    test('auto uses the recommendation and names the container limit', () {
      final d = resolveJobs(
        requested: 0,
        fileCount: 2000,
        machine: _machine(cores: 2, cpuContainer: true, ci: true),
      );
      expect(d.jobs, 2);
      expect(d.notes.single, contains('container limit'));
    });
    test('explicit count above available memory warns about throttling', () {
      final d = resolveJobs(
        requested: 16,
        fileCount: 2000,
        machine: _machine(cores: 16, avail: 2000),
      );
      expect(d.jobs, 16);
      expect(d.notes.single, contains('throttle'));
    });
    test('explicit count is capped at the hard maximum', () {
      final d = resolveJobs(
        requested: 500,
        fileCount: 100000,
        machine: _machine(cores: 64, avail: 1000000),
      );
      expect(d.jobs, kMaxJobs);
    });
    test('count never exceeds the file count', () {
      final d = resolveJobs(
        requested: 8,
        fileCount: 3,
        machine: _machine(cores: 16),
      );
      expect(d.jobs, 3);
    });
    test('incompatible features force serial and say so', () {
      final d = resolveJobs(
        requested: 4,
        fileCount: 2000,
        machine: _machine(),
        incompatibleReason: '--profile records timings per process',
      );
      expect(d.jobs, 1);
      expect(d.notes.single, contains('--jobs ignored'));
    });
  });

  group('container detection parsers', () {
    test('cgroup v2 cpu.max', () {
      expect(parseCgroupCpuMax('max 100000'), isNull);
      expect(parseCgroupCpuMax('200000 100000'), 2);
      expect(parseCgroupCpuMax('150000 100000\n'), 2);
      expect(parseCgroupCpuMax('garbage'), isNull);
    });
    test('cgroup v1 quota/period', () {
      expect(parseCgroupV1Cpu('-1', '100000'), isNull);
      expect(parseCgroupV1Cpu('400000', '100000'), 4);
    });
    test('cgroup memory limits treat max/huge as unlimited', () {
      expect(parseCgroupMemoryBytes('max'), isNull);
      expect(parseCgroupMemoryBytes('9223372036854771712'), isNull);
      expect(parseCgroupMemoryBytes('2147483648'), 2147483648);
    });
    test('CI detection', () {
      expect(detectCi({}), isFalse);
      expect(detectCi({'CI': 'true'}), isTrue);
      expect(detectCi({'GITHUB_ACTIONS': 'true'}), isTrue);
      expect(detectCi({'CI': 'false'}), isFalse);
      expect(detectCi({'CI': '0'}), isFalse);
    });
  });

  group('parseScanArgs resource flags', () {
    ScanCliArgs ok(List<String> a) =>
        (parseScanArgs(['.', ...a]) as ScanParseOk).args;
    test('--jobs / -j', () {
      expect(ok(['--jobs', '4']).jobs, 4);
      expect(ok(['-j', '2']).jobs, 2);
      expect(ok(['--jobs', 'auto']).jobs, 0);
      expect(ok(['--jobs', 'off']).jobs, 1);
      expect(ok([]).jobs, isNull);
    });
    test('--max-memory-mb, --chunk-timeout, --progress, --slow-file-ms', () {
      final a = ok([
        '--max-memory-mb',
        '2048',
        '--chunk-timeout',
        '60',
        '--progress',
        'json',
        '--slow-file-ms',
        '500',
      ]);
      expect(a.maxMemoryMb, 2048);
      expect(a.chunkTimeoutSeconds, 60);
      expect(a.progress, 'json');
      expect(a.slowFileMs, 500);
    });
    test('rejects invalid values', () {
      for (final bad in [
        ['--jobs'],
        ['--jobs', 'x'],
        ['--jobs', '0'],
        ['--max-memory-mb', '10'],
        ['--max-memory-mb'],
        ['--chunk-timeout', '1'],
        ['--progress', 'rainbow'],
        ['--slow-file-ms', '5'],
      ]) {
        expect(
          parseScanArgs(['.', ...bad]),
          isA<ScanParseInvalid>(),
          reason: '$bad',
        );
      }
    });
  });

  group('ScanRunner.runParallel', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('scan_jobs_');
      for (var i = 0; i < 24; i++) {
        File(p.join(dir.path, 'f$i.dart')).writeAsStringSync(
          'import "dart:io";\nvoid f$i() { final x = 1; print(x); }\n',
        );
      }
    });
    tearDown(() => dir.deleteSync(recursive: true));

    ScanRunner make() => ScanRunner(
      targetPath: dir.path,
      tier: 'essential',
      messageSink: (_) {},
    );

    test('matches the serial result, in the same order', () async {
      final serial = make().run()!;
      final parallel = (await make().runParallel(3))!;
      expect(
        parallel.map((d) => d.toString()).toList(),
        serial.map((d) => d.toString()).toList(),
      );
    });

    test('is identical for every worker count', () async {
      final two = (await make().runParallel(2))!;
      final four = (await make().runParallel(4))!;
      expect(
        two.map((d) => d.toString()).toList(),
        four.map((d) => d.toString()).toList(),
      );
    });

    test('jobs <= 1 behaves as run()', () async {
      final serial = make().run()!;
      final one = (await make().runParallel(1))!;
      expect(one.length, serial.length);
      expect(make().lastParallelReport, isNull);
    });

    test('records a report with the memory figures', () async {
      final r = make();
      await r.runParallel(2);
      expect(r.lastParallelReport, isNotNull);
      expect(r.lastParallelReport!.filesScanned, 24);
      expect(r.lastParallelReport!.peakRssMb, greaterThan(0));
    });

    test('forceEngine runs even a single worker through the engine', () async {
      final r = make();
      final d = await r.runParallel(
        1,
        config: const ScanParallelConfig(forceEngine: true),
      );
      expect(d, isNotNull);
      expect(r.lastParallelReport, isNotNull);
    });
  });
}
