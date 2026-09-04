// Tests the auto-migration of legacy plugin-block keys (log_level, lane,
// memory_mode, rule_packs) to analysis_options_custom.yaml.
//
// Background: the Dart SDK's plugin-block validator hardcodes the allowed
// keys under `plugins > saropa_lints:`. Custom keys like `log_level` trigger
// `unsupported_option` warnings that are fatal under `--fatal-warnings`,
// breaking CI pipelines. The auto-migration strips these keys from the
// plugin block and writes them to the custom file at plugin load time.

/// Tests for [_autoMigrateLegacyPluginKeys] in config_loader.dart.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/config_loader.dart'
    show loadNativePluginConfigFromProjectRoot, resetLegacyMigrationForTesting;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:test/test.dart';

import '../support/safe_delete.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    // Each test gets a fresh temp directory and a reset migration guard.
    tmpDir = Directory.systemTemp.createTempSync('auto_migrate_test_');
    resetLegacyMigrationForTesting();
    PluginLogger.resetForTesting();
  });

  tearDown(() {
    resetLegacyMigrationForTesting();
    PluginLogger.resetForTesting();
    safeDeleteDir(tmpDir);
  });

  /// Writes [content] into `analysis_options.yaml` inside [dir].
  void writeMain(Directory dir, String content) {
    File(p.join(dir.path, 'analysis_options.yaml')).writeAsStringSync(content);
  }

  /// Reads `analysis_options.yaml` from [dir], or null if absent.
  String readMain(Directory dir) {
    return File(p.join(dir.path, 'analysis_options.yaml')).readAsStringSync();
  }

  /// Reads `analysis_options_custom.yaml` from [dir], or empty if absent.
  String readCustom(Directory dir) {
    final f = File(p.join(dir.path, 'analysis_options_custom.yaml'));
    return f.existsSync() ? f.readAsStringSync() : '';
  }

  /// Writes [content] into `analysis_options_custom.yaml` inside [dir].
  void writeCustom(Directory dir, String content) {
    File(
      p.join(dir.path, 'analysis_options_custom.yaml'),
    ).writeAsStringSync(content);
  }

  group('auto-migrate legacy plugin keys', () {
    test('migrates scalar log_level from plugin block to custom file', () {
      // Arrange: legacy config with log_level under plugins > saropa_lints:.
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    log_level: debug
    diagnostics:
      avoid_print: true
''');

      // Act: trigger config load from the temp project root.
      loadNativePluginConfigFromProjectRoot(tmpDir.path);

      // Assert: log_level stripped from main file.
      final main = readMain(tmpDir);
      expect(main, isNot(contains('log_level')));
      // Assert: log_level written to custom file.
      final custom = readCustom(tmpDir);
      expect(custom, contains('log_level: debug'));
      // Assert: diagnostics block is preserved.
      expect(main, contains('avoid_print: true'));
    });

    test('migrates multiple scalar keys', () {
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    log_level: info
    lane: full
    memory_mode: balanced
    diagnostics:
      avoid_print: true
''');

      loadNativePluginConfigFromProjectRoot(tmpDir.path);

      final main = readMain(tmpDir);
      expect(main, isNot(contains('log_level')));
      expect(main, isNot(contains('lane:')));
      expect(main, isNot(contains('memory_mode')));

      final custom = readCustom(tmpDir);
      expect(custom, contains('log_level: info'));
      expect(custom, contains('lane: full'));
      expect(custom, contains('memory_mode: balanced'));
    });

    test('migrates rule_packs block from plugin block to custom file', () {
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    rule_packs:
      enabled:
        - collection_compat
        - dart_sdk_3_2
    diagnostics:
      avoid_print: true
''');

      loadNativePluginConfigFromProjectRoot(tmpDir.path);

      final main = readMain(tmpDir);
      expect(main, isNot(contains('rule_packs')));
      expect(main, isNot(contains('collection_compat')));

      final custom = readCustom(tmpDir);
      expect(custom, contains('rule_packs:'));
      expect(custom, contains('collection_compat'));
      expect(custom, contains('dart_sdk_3_2'));
    });

    test('skips keys already present in custom file', () {
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    log_level: debug
    diagnostics:
      avoid_print: true
''');
      // Pre-existing custom file with log_level already set.
      writeCustom(tmpDir, 'log_level: warning\n');

      loadNativePluginConfigFromProjectRoot(tmpDir.path);

      // Legacy key still stripped from main file.
      final main = readMain(tmpDir);
      expect(main, isNot(contains('log_level')));

      // Custom file keeps its original value, not overwritten.
      final custom = readCustom(tmpDir);
      expect(custom, contains('log_level: warning'));
      expect(custom, isNot(contains('log_level: debug')));
    });

    test('no-op when no legacy keys present', () {
      final original = '''
plugins:
  saropa_lints:
    version: "15.2.12"
    diagnostics:
      avoid_print: true
''';
      writeMain(tmpDir, original);

      loadNativePluginConfigFromProjectRoot(tmpDir.path);

      // Main file unchanged.
      final main = readMain(tmpDir);
      expect(main, equals(original));
      // No custom file created.
      final custom = readCustom(tmpDir);
      expect(custom, isEmpty);
    });

    test('runs only once per session (guard flag)', () {
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    log_level: debug
    diagnostics:
      avoid_print: true
''');

      // First call migrates.
      loadNativePluginConfigFromProjectRoot(tmpDir.path);
      expect(readCustom(tmpDir), contains('log_level: debug'));

      // Re-add the legacy key to simulate a second project.
      writeMain(tmpDir, '''
plugins:
  saropa_lints:
    version: "15.2.12"
    lane: full
    diagnostics:
      avoid_print: true
''');

      // Second call is a no-op (guard flag prevents re-migration).
      loadNativePluginConfigFromProjectRoot(tmpDir.path);
      final main = readMain(tmpDir);
      expect(
        main,
        contains('lane: full'),
        reason: 'guard flag should prevent second migration',
      );
    });
  });
}
