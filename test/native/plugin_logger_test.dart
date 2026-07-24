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

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `plugin_logger_test` (plugin logger).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.

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

    test(
      'setProjectRoot creates the log file and flushes buffered entries',
      () {
        final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
        // setProjectRoot requires pubspec.yaml to identify a Dart project.
        File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
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
      },
    );

    test('log entries after setProjectRoot bypass the buffer and hit disk', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        PluginLogger.setProjectRoot(tempDir.path);
        expect(PluginLogger.bufferSizeForTesting, 0);

        PluginLogger.log('post-root entry');

        // Buffer must stay empty — the log went directly to disk.
        expect(PluginLogger.bufferSizeForTesting, 0);

        final contents = File(
          PluginLogger.logFilePathForTesting!,
        ).readAsStringSync();
        expect(contents, contains('post-root entry'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('setProjectRoot is idempotent — first root wins', () {
      final firstRoot = Directory.systemTemp.createTempSync('plugin_logger_1_');
      File(p.join(firstRoot.path, 'pubspec.yaml')).writeAsStringSync('name: a');
      final secondRoot = Directory.systemTemp.createTempSync(
        'plugin_logger_2_',
      );
      File(p.join(secondRoot.path, 'pubspec.yaml')).writeAsStringSync(
        'name: b',
      );
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
          File(
            p.join(secondRoot.path, 'reports', '.saropa_lints', 'plugin.log'),
          ).existsSync(),
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

    test('setProjectRoot rejects directories without pubspec.yaml', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      try {
        PluginLogger.log('should stay buffered');
        PluginLogger.setProjectRoot(tempDir.path);

        expect(
          PluginLogger.logFilePathForTesting,
          isNull,
          reason: 'Non-Dart directory must be rejected',
        );
        expect(PluginLogger.bufferSizeForTesting, 1);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('emits restart-rate warning when threshold exceeded', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Seed the log with 12 recent "session started" entries — above the
        // threshold of 10 within 10 minutes.
        final now = DateTime.now().toUtc();
        final buf = StringBuffer();
        for (var i = 0; i < 12; i++) {
          final ts = now.subtract(Duration(minutes: i));
          buf.writeln(
            '${ts.toIso8601String()} | '
            '--- saropa_lints plugin session started ---',
          );
        }
        logFile.writeAsStringSync(buf.toString());

        PluginLogger.setProjectRoot(tempDir.path);

        final contents = logFile.readAsStringSync();
        expect(contents, contains('WARNING:'));
        expect(contents, contains('plugin restarts in last'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('no restart-rate warning when below threshold', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Seed with only 3 recent sessions — below threshold.
        final now = DateTime.now().toUtc();
        final buf = StringBuffer();
        for (var i = 0; i < 3; i++) {
          final ts = now.subtract(Duration(minutes: i));
          buf.writeln(
            '${ts.toIso8601String()} | '
            '--- saropa_lints plugin session started ---',
          );
        }
        logFile.writeAsStringSync(buf.toString());

        PluginLogger.setProjectRoot(tempDir.path);

        final contents = logFile.readAsStringSync();
        expect(contents, isNot(contains('WARNING:')));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('log entries include error and stack trace when provided', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        PluginLogger.setProjectRoot(tempDir.path);

        try {
          throw StateError('deliberate test error');
        } on StateError catch (e, st) {
          PluginLogger.log('caught an error', error: e, stackTrace: st);
        }

        final contents = File(
          PluginLogger.logFilePathForTesting!,
        ).readAsStringSync();
        expect(contents, contains('caught an error'));
        expect(contents, contains('deliberate test error'));
        expect(contents, contains('stack:'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
