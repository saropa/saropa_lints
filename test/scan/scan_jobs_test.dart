/// Tests the `--jobs` worker-count recommendation and parsing, plus an
/// end-to-end check that a parallel scan matches a serial one.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/scan/scan_cli_args.dart';
import 'package:saropa_lints/src/scan/scan_jobs.dart';
import 'package:test/test.dart';

void main() {
  group('parseJobsValue', () {
    test('accepts auto and positive integers', () {
      expect(parseJobsValue('auto'), 0);
      expect(parseJobsValue('AUTO'), 0);
      expect(parseJobsValue('4'), 4);
    });
    test('rejects zero, negatives and junk', () {
      expect(parseJobsValue('0'), isNull);
      expect(parseJobsValue('-2'), isNull);
      expect(parseJobsValue('lots'), isNull);
    });
  });

  group('recommendJobs', () {
    test('leaves one core free', () {
      final r = recommendJobs(
        fileCount: 5000,
        cores: 4,
        availableMemoryMb: 64000,
      );
      expect(r.jobs, 3);
      expect(r.limitedBy, 'CPU');
    });
    test('is capped by memory', () {
      // 1200 MB * 0.5 / 300 MB = 2 workers.
      final r = recommendJobs(
        fileCount: 5000,
        cores: 32,
        availableMemoryMb: 1200,
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
  });

  group('resolveJobs', () {
    test('unset stays serial and hints on large scans', () {
      final d = resolveJobs(
        requested: null,
        fileCount: 2000,
        cores: 8,
        availableMemoryMb: 32000,
      );
      expect(d.jobs, 1);
      expect(d.notes.single, contains('--jobs 7'));
    });
    test('unset is silent on small scans', () {
      final d = resolveJobs(
        requested: null,
        fileCount: 50,
        cores: 8,
        availableMemoryMb: 32000,
      );
      expect(d.jobs, 1);
      expect(d.notes, isEmpty);
    });
    test('auto uses the recommendation', () {
      final d = resolveJobs(
        requested: 0,
        fileCount: 2000,
        cores: 4,
        availableMemoryMb: 32000,
      );
      expect(d.jobs, 3);
    });
    test('explicit count above available memory warns', () {
      final d = resolveJobs(
        requested: 16,
        fileCount: 2000,
        cores: 16,
        availableMemoryMb: 2000,
      );
      expect(d.jobs, 16);
      expect(d.notes.single, contains('swapping'));
    });
    test('explicit count is capped at the hard maximum', () {
      final d = resolveJobs(
        requested: 500,
        fileCount: 100000,
        cores: 64,
        availableMemoryMb: 1000000,
      );
      expect(d.jobs, kMaxJobs);
    });
    test('count never exceeds the file count', () {
      final d = resolveJobs(
        requested: 8,
        fileCount: 3,
        cores: 16,
        availableMemoryMb: 64000,
      );
      expect(d.jobs, 3);
    });
    test('incompatible features force serial and say so', () {
      final d = resolveJobs(
        requested: 4,
        fileCount: 2000,
        cores: 8,
        incompatibleReason: '--profile records timings per process',
      );
      expect(d.jobs, 1);
      expect(d.notes.single, contains('--jobs ignored'));
    });
  });

  group('parseScanArgs --jobs', () {
    test('parses a number, -j and auto', () {
      expect((parseScanArgs(['.', '--jobs', '4']) as ScanParseOk).args.jobs, 4);
      expect((parseScanArgs(['.', '-j', '2']) as ScanParseOk).args.jobs, 2);
      expect(
        (parseScanArgs(['.', '--jobs', 'auto']) as ScanParseOk).args.jobs,
        0,
      );
      expect((parseScanArgs(['.']) as ScanParseOk).args.jobs, isNull);
    });
    test('rejects a missing or invalid value', () {
      expect(parseScanArgs(['.', '--jobs']), isA<ScanParseInvalid>());
      expect(parseScanArgs(['.', '--jobs', 'x']), isA<ScanParseInvalid>());
      expect(parseScanArgs(['.', '--jobs', '0']), isA<ScanParseInvalid>());
    });
  });

  group('ScanRunner.runParallel', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('scan_jobs_');
      for (var i = 0; i < 12; i++) {
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

    test('jobs <= 1 behaves as run()', () async {
      final serial = make().run()!;
      final one = (await make().runParallel(1))!;
      expect(one.length, serial.length);
    });
  });
}
