/// Pins the NDJSON progress event shape `runSizeScan` emits under
/// `ProjectScanProgress` (WP1, `--progress`/`--control` on
/// `bin/project_health.dart`). Mirrors the equivalent
/// `project_vibrancy_cli_test.dart` group ("emits phase + tick progress
/// events") so both CLIs' event contracts are pinned the same way.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_health/scan_progress.dart';
import 'package:saropa_lints/src/cli/project_health/size_scanner.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

/// Distinguishable exception a throwing gate uses to prove cancellation
/// propagates out of `runSizeScan` uncaught (the CLI's `main()` is the only
/// thing that should catch its own `_ScanCanceled`).
class _GateAbort implements Exception {
  const _GateAbort();
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('saropa_health_progress_');
    File(p.join(tmp.path, 'a.dart')).writeAsStringSync('final x = 1;\n');
    File(p.join(tmp.path, 'b.dart')).writeAsStringSync('final y = 2;\n');
  });

  tearDown(() => safeDeleteDir(tmp));

  test('emits a phase(size) event with the eligible-file total, then one '
      'tick(size) per file, then done', () async {
    final events = <Map<String, Object?>>[];
    await runSizeScan(
      SizeScanOptions(
        projectPath: tmp.path,
        progress: ProjectScanProgress(onEvent: events.add, gate: () async {}),
      ),
    );

    // First event is the phase total — the dashboard needs this before any
    // tick to render "0/N" instead of a dead 0% with no denominator.
    expect(events.first, <String, Object?>{
      'event': 'phase',
      'phase': 'size',
      'total': 2,
    });

    final ticks = events.where((e) => e['event'] == 'tick').toList();
    expect(ticks, hasLength(2));
    for (final tick in ticks) {
      expect(tick['phase'], 'size');
      expect(tick['total'], 2);
      expect(tick['file'], isA<String>());
    }
    // done/total sequence is monotonic and starts at 0 (not 1) — the first
    // tick reports "0 of 2 done" (this file not yet measured), matching
    // project_vibrancy's "emit BEFORE parsing" contract.
    expect(ticks.map((e) => e['done']).toList(), <int>[0, 1]);

    // Last event closes the stream so the webview can flip out of the
    // scanning state even for a scan with zero problem rows.
    expect(events.last, <String, Object?>{'event': 'done'});
  });

  test('a throwing gate aborts the scan uncaught (cancel path)', () async {
    // The CLI wires --control cancel to a gate that throws; runSizeScan
    // must let it propagate so bin/project_health.dart's main() can catch
    // and exit clean instead of emitting a partial report.
    expect(
      () => runSizeScan(
        SizeScanOptions(
          projectPath: tmp.path,
          progress: ProjectScanProgress(
            onEvent: (_) {},
            gate: () async => throw const _GateAbort(),
          ),
        ),
      ),
      throwsA(isA<_GateAbort>()),
    );
  });

  test('progress is optional — no events, no behavior change', () async {
    final agg = await runSizeScan(SizeScanOptions(projectPath: tmp.path));
    expect(agg.fileCount, 2);
  });
}
