/// Tests for the memory_report CLI: parses `[memory]` trend lines written by
/// PluginLogger and summarizes RSS over the logged window.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('memory_report_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  /// Runs `dart run bin/memory_report.dart <projectRoot>` and returns stdout.
  String runReport(String projectRoot) {
    final result = Process.runSync(Platform.resolvedExecutable, [
      p.join(Directory.current.path, 'bin', 'memory_report.dart'),
      projectRoot,
    ]);
    return (result.stdout as String) + (result.stderr as String);
  }

  test('reports "no log found" when plugin.log is absent', () {
    final output = runReport(tempDir.path);
    expect(output, contains('No plugin.log found'));
  });

  test('reports "no memory trend lines" when log has no [memory] lines', () {
    final logDir = Directory(p.join(tempDir.path, 'reports', '.saropa_lints'))
      ..createSync(recursive: true);
    File(
      p.join(logDir.path, 'plugin.log'),
    ).writeAsStringSync('2026-08-28T00:00:00.000Z | Plugin.start()\n');

    final output = runReport(tempDir.path);
    expect(output, contains('No memory trend lines found'));
  });

  test('summarizes min/max/latest RSS from matching lines', () {
    final logDir = Directory(p.join(tempDir.path, 'reports', '.saropa_lints'))
      ..createSync(recursive: true);
    File(p.join(logDir.path, 'plugin.log')).writeAsStringSync(
      '2026-08-28T00:00:00.000Z | [memory] RSS 3000MB (cap 6144MB)\n'
      '2026-08-28T00:00:30.000Z | [memory] RSS 4200MB (cap 6144MB)\n'
      '2026-08-28T00:01:00.000Z | [memory] RSS 3800MB (cap 6144MB)\n',
    );

    final output = runReport(tempDir.path);
    expect(output, contains('Samples: 3'));
    expect(output, contains('Min RSS: 3000MB'));
    expect(output, contains('Max RSS: 4200MB'));
    expect(output, contains('Latest:  2026-08-28T00:01:00.000Z - 3800MB'));
    // 3800 / 6144 = 61.848...% -> rounds to 62%
    expect(output, contains('Latest is 62% of the configured cap.'));
  });

  test('ignores non-memory log lines interleaved with memory lines', () {
    final logDir = Directory(p.join(tempDir.path, 'reports', '.saropa_lints'))
      ..createSync(recursive: true);
    File(p.join(logDir.path, 'plugin.log')).writeAsStringSync(
      '2026-08-28T00:00:00.000Z | Plugin.start() — loading initial config\n'
      '2026-08-28T00:00:30.000Z | [memory] RSS 5000MB (cap 6144MB)\n'
      '2026-08-28T00:01:00.000Z | Plugin.register() — registering rules\n',
    );

    final output = runReport(tempDir.path);
    expect(output, contains('Samples: 1'));
    expect(output, contains('Min RSS: 5000MB'));
    expect(output, contains('Max RSS: 5000MB'));
  });

  test('prints a CAVEAT when the log was rotated mid-session', () {
    final logDir = Directory(p.join(tempDir.path, 'reports', '.saropa_lints'))
      ..createSync(recursive: true);
    File(p.join(logDir.path, 'plugin.log')).writeAsStringSync(
      '2026-08-28T00:00:30.000Z | [memory] RSS 4200MB (cap 6144MB)\n'
      '2026-08-28T00:01:00.000Z | [log-rotated] earlier entries discarded '
      '— file exceeded 524288 bytes.\n'
      '2026-08-28T00:01:30.000Z | [memory] RSS 3800MB (cap 6144MB)\n',
    );

    final output = runReport(tempDir.path);
    expect(output, contains('Samples: 2'));
    expect(
      output,
      contains('CAVEAT: plugin.log was rotated at 2026-08-28T00:01:00.000Z'),
    );
  });

  test('omits the CAVEAT when the log has never been rotated', () {
    final logDir = Directory(p.join(tempDir.path, 'reports', '.saropa_lints'))
      ..createSync(recursive: true);
    File(p.join(logDir.path, 'plugin.log')).writeAsStringSync(
      '2026-08-28T00:00:30.000Z | [memory] RSS 4200MB (cap 6144MB)\n',
    );

    final output = runReport(tempDir.path);
    expect(output, isNot(contains('CAVEAT')));
  });
}
