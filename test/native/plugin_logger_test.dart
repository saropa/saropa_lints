// Tests for [PluginLogger] — the user-visible plugin log at
// `reports/.saropa_lints/plugin.log`.
//
// Background: `developer.log(name: 'saropa_lints')` routes to the analysis
// server's log file (`%LOCALAPPDATA%\.dartServer\logs\` on Windows), which
// users never check. The user-visible log lives inside the consumer
// project alongside `violations.json` so the plugin's diagnostic state is
// trivially inspectable: open the file, read the plain text.
//
// Lifecycle: entries logged before [PluginLogger.setProjectRoot] runs are
// buffered in memory, then flushed to disk once the project root is known
// (triggered by the first analyzed file in [SaropaContext._wrapCallback]).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    PluginLogger.resetForTesting();
  });

  tearDown(() {
    PluginLogger.resetForTesting();
  });

  group('PluginLogger', () {
    test('buffers entries before setProjectRoot is called', () {
      PluginLogger.log('early entry one');
      PluginLogger.log('early entry two');

      expect(PluginLogger.bufferSizeForTesting, 2);
      expect(PluginLogger.logFilePathForTesting, isNull);
    });

    test('setProjectRoot creates the log file and flushes buffered entries',
        () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      try {
        PluginLogger.log('pre-root entry one');
        PluginLogger.log('pre-root entry two');
        expect(PluginLogger.bufferSizeForTesting, 2);

        PluginLogger.setProjectRoot(tempDir.path);

        final expectedPath = p.join(
          tempDir.path,
          'reports',
          '.saropa_lints',
          'plugin.log',
        );
        expect(PluginLogger.logFilePathForTesting, expectedPath);
        expect(PluginLogger.bufferSizeForTesting, 0);

        final contents = File(expectedPath).readAsStringSync();
        expect(contents, contains('session started'));
        expect(contents, contains('pre-root entry one'));
        expect(contents, contains('pre-root entry two'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('log entries after setProjectRoot bypass the buffer and hit disk',
        () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      try {
        PluginLogger.setProjectRoot(tempDir.path);
        expect(PluginLogger.bufferSizeForTesting, 0);

        PluginLogger.log('post-root entry');

        // Buffer must stay empty — the log went directly to disk.
        expect(PluginLogger.bufferSizeForTesting, 0);

        final contents = File(PluginLogger.logFilePathForTesting!)
            .readAsStringSync();
        expect(contents, contains('post-root entry'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('setProjectRoot is idempotent — first root wins', () {
      final firstRoot = Directory.systemTemp.createTempSync('plugin_logger_1_');
      final secondRoot =
          Directory.systemTemp.createTempSync('plugin_logger_2_');
      try {
        PluginLogger.setProjectRoot(firstRoot.path);
        final firstPath = PluginLogger.logFilePathForTesting;

        PluginLogger.setProjectRoot(secondRoot.path);
        expect(
          PluginLogger.logFilePathForTesting,
          firstPath,
          reason: 'Second setProjectRoot call must be ignored',
        );

        // Second directory must NOT have the log file.
        expect(
          File(p.join(
            secondRoot.path,
            'reports',
            '.saropa_lints',
            'plugin.log',
          )).existsSync(),
          isFalse,
        );
      } finally {
        firstRoot.deleteSync(recursive: true);
        secondRoot.deleteSync(recursive: true);
      }
    });

    test('empty projectRoot is a no-op (does not crash)', () {
      PluginLogger.setProjectRoot('');
      expect(PluginLogger.logFilePathForTesting, isNull);
    });

    test('log entries include error and stack trace when provided', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      try {
        PluginLogger.setProjectRoot(tempDir.path);

        try {
          throw StateError('deliberate test error');
        } on StateError catch (e, st) {
          PluginLogger.log('caught an error', error: e, stackTrace: st);
        }

        final contents = File(PluginLogger.logFilePathForTesting!)
            .readAsStringSync();
        expect(contents, contains('caught an error'));
        expect(contents, contains('deliberate test error'));
        expect(contents, contains('stack:'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
