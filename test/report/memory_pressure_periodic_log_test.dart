/// Verifies MemoryPressureHandler's periodic RSS trend log — the write side
/// that `dart run saropa_lints:memory_report` (bin/memory_report.dart) reads
/// back. See test/bin/memory_report_test.dart for the read/parse side.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/plugin_logger.dart' show PluginLogger;
import 'package:saropa_lints/src/project_context.dart'
    show MemoryPressureHandler;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'memory_pressure_periodic_log_test_',
    );
    // PluginLogger.setProjectRoot only accepts roots with a pubspec.yaml —
    // it rejects arbitrary directories to avoid polluting non-Dart folders.
    File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: x\n');
  });

  tearDown(() {
    PluginLogger.resetForTesting();
    MemoryPressureHandler.setHardRssLimitMb(0);
    tempDir.deleteSync(recursive: true);
  });

  test('refreshForTesting writes a [memory] RSS line to plugin.log', () {
    PluginLogger.setProjectRoot(tempDir.path);
    // A high cap keeps the valve from tripping (which would clear caches and
    // write its own unrelated log lines) — this test only cares about the
    // periodic trend line, not the hard-relief path.
    MemoryPressureHandler.setHardRssLimitMb(1 << 20);
    MemoryPressureHandler.resetMemoryLogCooldownForTesting();

    MemoryPressureHandler.refreshForTesting();

    final logFile = File(
      p.join(tempDir.path, 'reports', '.saropa_lints', 'plugin.log'),
    );
    expect(logFile.existsSync(), isTrue);
    final content = logFile.readAsStringSync();
    expect(content, contains('[memory] RSS'));
    expect(content, contains('MB (cap 1048576MB)'));
  });

  test('a second refresh within the cooldown window does not log again', () {
    PluginLogger.setProjectRoot(tempDir.path);
    MemoryPressureHandler.setHardRssLimitMb(1 << 20);
    MemoryPressureHandler.resetMemoryLogCooldownForTesting();

    MemoryPressureHandler.refreshForTesting();
    final logFile = File(
      p.join(tempDir.path, 'reports', '.saropa_lints', 'plugin.log'),
    );
    final firstCount = '[memory] RSS'
        .allMatches(logFile.readAsStringSync())
        .length;

    // Immediately refresh again — the 30s cooldown has not elapsed, so this
    // must not append a second [memory] line.
    MemoryPressureHandler.refreshForTesting();
    final secondCount = '[memory] RSS'
        .allMatches(logFile.readAsStringSync())
        .length;

    expect(firstCount, 1);
    expect(secondCount, firstCount);
  });
}
