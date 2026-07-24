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

  group('PluginLogLevel.tryParse', () {
    test('parses valid level names', () {
      expect(PluginLogLevel.tryParse('off'), PluginLogLevel.off);
      expect(PluginLogLevel.tryParse('error'), PluginLogLevel.error);
      expect(PluginLogLevel.tryParse('warning'), PluginLogLevel.warning);
      expect(PluginLogLevel.tryParse('info'), PluginLogLevel.info);
      expect(PluginLogLevel.tryParse('debug'), PluginLogLevel.debug);
    });

    test('is case-insensitive', () {
      expect(PluginLogLevel.tryParse('INFO'), PluginLogLevel.info);
      expect(PluginLogLevel.tryParse('Debug'), PluginLogLevel.debug);
    });

    test('returns null for invalid input', () {
      expect(PluginLogLevel.tryParse(null), isNull);
      expect(PluginLogLevel.tryParse(''), isNull);
      expect(PluginLogLevel.tryParse('verbose'), isNull);
      expect(PluginLogLevel.tryParse('trace'), isNull);
    });
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

    test('no restart-rate warning when all entries are old', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Seed with 15 entries all older than 10 minutes.
        final now = DateTime.now().toUtc();
        final buf = StringBuffer();
        for (var i = 0; i < 15; i++) {
          final ts = now.subtract(Duration(minutes: 20 + i));
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

    test('handles corrupted log file without crashing', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Write garbage — partial lines, no valid timestamps.
        logFile.writeAsStringSync(
          'corrupted\x00binary\ntruncated-2024-01-01T | partial\n'
          '--- saropa_lints plugin session started ---\n',
        );

        PluginLogger.setProjectRoot(tempDir.path);

        expect(PluginLogger.logFilePathForTesting, isNotNull);
        final contents = logFile.readAsStringSync();
        expect(contents, contains('session started'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rotates log file when exceeding size cap', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Write >512KB of content with a recognizable old marker at the start.
        final oldMarker = 'OLD_MARKER_LINE_SHOULD_BE_ROTATED_AWAY';
        final buf = StringBuffer()..writeln(oldMarker);
        // Each line ~80 chars, need ~6500 lines to exceed 512KB.
        for (var i = 0; i < 7000; i++) {
          buf.writeln('${'x' * 70} line $i');
        }
        logFile.writeAsStringSync(buf.toString());
        final sizeBefore = logFile.lengthSync();
        expect(sizeBefore, greaterThan(512 * 1024));

        PluginLogger.setProjectRoot(tempDir.path);

        final sizeAfter = logFile.lengthSync();
        expect(sizeAfter, lessThan(sizeBefore));
        final contents = logFile.readAsStringSync();
        expect(
          contents,
          isNot(contains(oldMarker)),
          reason: 'Old content at the start should be rotated away',
        );
        expect(contents, contains('session started'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rotates CRLF log file without orphaned carriage returns', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Write >512KB of CRLF-terminated lines with a marker at the start.
        final buf = StringBuffer()..writeln('CRLF_OLD_MARKER');
        for (var i = 0; i < 7000; i++) {
          buf.write('${'y' * 70} line $i\r\n');
        }
        logFile.writeAsStringSync(buf.toString());
        expect(logFile.lengthSync(), greaterThan(512 * 1024));

        PluginLogger.setProjectRoot(tempDir.path);

        final contents = logFile.readAsStringSync();
        expect(contents, isNot(contains('CRLF_OLD_MARKER')));
        // First kept line must not start with \r.
        expect(contents.startsWith('\r'), isFalse);
        expect(contents, contains('session started'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rotates single huge line by truncating entirely', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        final logDir = Directory(
          p.join(tempDir.path, 'reports', '.saropa_lints'),
        )..createSync(recursive: true);
        final logFile = File(p.join(logDir.path, 'plugin.log'));

        // Write >512KB as a single line with no newlines.
        logFile.writeAsStringSync('x' * (600 * 1024));

        PluginLogger.setProjectRoot(tempDir.path);

        final contents = logFile.readAsStringSync();
        // The single huge line should have been truncated, leaving only
        // the new session header.
        expect(contents, contains('session started'));
        expect(contents.length, lessThan(600 * 1024));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('log level filters messages below minLevel from disk', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        PluginLogger.setProjectRoot(tempDir.path);
        PluginLogger.minLevel = PluginLogLevel.error;

        PluginLogger.log('info message', level: PluginLogLevel.info);
        PluginLogger.log('debug message', level: PluginLogLevel.debug);
        PluginLogger.log('error message', level: PluginLogLevel.error);

        final contents = File(
          PluginLogger.logFilePathForTesting!,
        ).readAsStringSync();
        expect(contents, contains('error message'));
        expect(contents, isNot(contains('info message')));
        expect(contents, isNot(contains('debug message')));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('log level off suppresses all messages from disk', () {
      final tempDir = Directory.systemTemp.createTempSync('plugin_logger_');
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('name: t');
      try {
        PluginLogger.setProjectRoot(tempDir.path);
        PluginLogger.minLevel = PluginLogLevel.off;

        PluginLogger.log('should not appear', level: PluginLogLevel.error);

        final contents = File(
          PluginLogger.logFilePathForTesting!,
        ).readAsStringSync();
        expect(contents, isNot(contains('should not appear')));
        expect(contents, contains('session started'));
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
