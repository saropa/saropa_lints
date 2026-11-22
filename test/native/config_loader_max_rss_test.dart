// Tests the `max_rss_mb` key in analysis_options_custom.yaml: the discoverable,
// extension-writable way to set the analyzer plugin's hard memory cap (the
// env var SAROPA_LINTS_MAX_RSS_MB stays the override).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show MemoryPressureHandler;
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory dir;

  void load(String custom) {
    File(
      p.join(dir.path, 'analysis_options.yaml'),
    ).writeAsStringSync('plugins:\n  saropa_lints:\n    version: any\n');
    File(
      p.join(dir.path, 'analysis_options_custom.yaml'),
    ).writeAsStringSync(custom);
    loadNativePluginConfigFromProjectRoot(dir.path);
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('saropa_rss_');
    PluginLogger.resetForTesting();
    MemoryPressureHandler.setConfiguredHardRssMb(null);
  });

  tearDown(() {
    MemoryPressureHandler.setConfiguredHardRssMb(null);
    PluginLogger.resetForTesting();
    safeDeleteDir(dir);
  });

  test('absent key leaves the adaptive default in charge', () {
    load('log_level: info\n');
    expect(MemoryPressureHandler.configuredHardRssMb, isNull);
  });

  test('a valid value is recorded', () {
    load('max_rss_mb: 2560\n');
    expect(MemoryPressureHandler.configuredHardRssMb, 2560);
  });

  test('0 disables the cap and is recorded as 0', () {
    load('max_rss_mb: 0\n');
    expect(MemoryPressureHandler.configuredHardRssMb, 0);
  });

  test('a commented key is ignored', () {
    load('# max_rss_mb: 2560\n');
    expect(MemoryPressureHandler.configuredHardRssMb, isNull);
  });

  test('values too low to analyze with are raised to the minimum', () {
    load('max_rss_mb: 200\n');
    expect(
      MemoryPressureHandler.configuredHardRssMb,
      MemoryPressureHandler.minConfiguredRssMb,
    );
  });

  test('junk is ignored, not applied', () {
    load('max_rss_mb: lots\n');
    expect(MemoryPressureHandler.configuredHardRssMb, isNull);
    load('max_rss_mb: -5\n');
    expect(MemoryPressureHandler.configuredHardRssMb, isNull);
  });

  test('removing the key clears a previously configured cap', () {
    load('max_rss_mb: 3000\n');
    expect(MemoryPressureHandler.configuredHardRssMb, 3000);
    load('log_level: info\n');
    expect(MemoryPressureHandler.configuredHardRssMb, isNull);
  });
}
