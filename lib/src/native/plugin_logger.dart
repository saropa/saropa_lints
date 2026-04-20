// ignore_for_file: depend_on_referenced_packages

/// User-visible plugin log, written to
/// `<projectRoot>/reports/.saropa_lints/plugin.log`.
///
/// **Why this exists.** `developer.log(name: 'saropa_lints', ...)` routes to
/// the analysis server's log file (typically
/// `%LOCALAPPDATA%\.dartServer\logs\` on Windows) — a location most users
/// never look at. When the plugin fails silently (e.g. the analyzer-launched
/// `Directory.current` bug), the user has no visible surface to diagnose the
/// problem. This logger fixes that by mirroring every significant log event
/// to a plain-text file inside the consumer's project, next to the existing
/// `violations.json` report.
///
/// **Lifecycle problem and the fix.** At plugin `start()` time the project
/// root is not yet known (see `config_loader`), so the log file path cannot
/// be resolved. Early log events are buffered in memory (capped at
/// [_maxBufferSize] entries — enough for startup diagnostics, not unbounded).
/// Once [setProjectRoot] is called from
/// [SaropaContext._ensureConfigLoadedFromProjectRoot] — which happens on the
/// first visitor invocation that has a usable file path — the buffer is
/// flushed to disk and subsequent calls write directly.
///
/// **What gets logged.** Config-loader silent-failure paths (missing
/// `analysis_options.yaml`, missing diagnostics block), successful project-
/// root reloads (with resolved path), plugin start/register milestones.
/// Never throws — logging failures are swallowed so the plugin stays
/// healthy even if disk is read-only or permissions are wrong.
library;

import 'dart:developer' as developer;
import 'dart:io' show Directory, File, FileMode, Platform;

/// Writes plugin diagnostics to a user-visible file alongside `violations.json`.
///
/// All methods are static — a single shared logger for the whole plugin.
/// Thread-safety: Dart is single-threaded per isolate; the analysis server
/// calls plugin code on one isolate, so no locking needed.
final class PluginLogger {
  PluginLogger._();

  /// Max entries to buffer before a project root is known. Early bootstrap
  /// produces far fewer than this — the cap only protects against runaway
  /// retry loops or pathological configurations where the root is never
  /// discovered. Older entries are dropped, newer kept, so the user sees
  /// the most recent failure modes.
  static const int _maxBufferSize = 500;

  /// In-memory buffer for log entries recorded before [setProjectRoot] runs.
  static final List<_LogEntry> _buffer = [];

  /// Absolute path of the log file once the project root is known.
  /// Null means entries still go into `_buffer`.
  static String? _logFilePath;

  /// Records a log event. Always mirrors to `developer.log` (for analysis-
  /// server log continuity), then either appends to the user-visible log
  /// file or buffers the entry for later flush.
  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    // Always send to developer.log so it still shows in the analysis server
    // log file for advanced users / CI log harvesting.
    developer.log(
      message,
      name: 'saropa_lints',
      error: error,
      stackTrace: stackTrace,
    );

    final entry = _LogEntry(
      // Fix: prefer_utc_for_storage — log entries are persisted to file and
      // may be read from any time zone; UTC keeps ordering stable.
      timestamp: DateTime.now().toUtc(),
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );

    final path = _logFilePath;
    if (path == null) {
      // No project root yet. Buffer with size cap — drop oldest when full
      // so the buffer can't grow unbounded on pathological retry loops.
      if (_buffer.length >= _maxBufferSize) {
        _buffer.removeAt(0);
      }
      _buffer.add(entry);
      return;
    }

    _appendToFile(path, entry);
  }

  /// Initializes the log file path from a discovered [projectRoot] and
  /// flushes any buffered entries. Idempotent — subsequent calls with a
  /// different root are ignored (the first real root wins, matching the
  /// one-shot config-reload guard in [SaropaContext]).
  ///
  /// Safe to call before or after [log]. Never throws.
  static void setProjectRoot(String projectRoot) {
    if (projectRoot.isEmpty) return;
    if (_logFilePath != null) return; // first root wins

    try {
      final sep = Platform.pathSeparator;
      final dirPath = '$projectRoot${sep}reports$sep.saropa_lints';
      Directory(dirPath).createSync(recursive: true);

      final path = '$dirPath${sep}plugin.log';
      _logFilePath = path;

      // Write a session header so multiple sessions are visually separable
      // in the (append-only) log file when tailing.
      _appendToFile(
        path,
        _LogEntry(
          // Fix: prefer_utc_for_storage — session header persists to the log.
          timestamp: DateTime.now().toUtc(),
          message: '--- saropa_lints plugin session started ---',
        ),
      );

      // Flush everything buffered before the root was known.
      for (final entry in _buffer) {
        _appendToFile(path, entry);
      }
      _buffer.clear();
    } on Exception catch (e, st) {
      // Disk full, permissions denied, read-only filesystem — the plugin
      // must not die. Fall back to developer.log only; the worst case is
      // the user has no visible log, same as the old behavior.
      developer.log(
        'PluginLogger.setProjectRoot failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
    // Object fallback (avoid_catch_exception_alone): the logger must never
    // crash the analysis isolate, even on programmer-error subclasses of Error.
    on Object catch (e, st) {
      developer.log(
        'PluginLogger.setProjectRoot failed (Error)',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Writes one line for [entry] to [path] in append mode. Never throws —
  /// logging is best-effort; if the write fails we simply drop the entry
  /// rather than crash the analysis isolate.
  static void _appendToFile(String path, _LogEntry entry) {
    try {
      // Fix: prefer_utc_for_storage — explicit .toUtc() at serialization so
      // the rule sees UTC normalization adjacent to the storage write.
      final line = StringBuffer()
        ..write(entry.timestamp.toUtc().toIso8601String())
        ..write(' | ')
        ..write(entry.message);
      // Field promotion does not cross property access; default to empty
      // string to avoid printing literal 'null' (avoid_nullable_interpolation).
      final err = entry.error;
      if (err != null && err.isNotEmpty) {
        line.write('\n  error: $err');
      }
      final st = entry.stackTrace;
      if (st != null && st.isNotEmpty) {
        line.write('\n  stack: $st');
      }
      line.writeln();
      File(path).writeAsStringSync(
        line.toString(),
        mode: FileMode.append,
        flush: true, // fsync: the user may read the file immediately
      );
    } on Exception catch (e, st) {
      // Acknowledge via developer.log (avoid_swallowing_exceptions). Never
      // throw from a logger — the analysis isolate must continue.
      developer.log(
        '_appendToFile failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
    // Object fallback (avoid_catch_exception_alone) — same rationale: never
    // throw from the logger, even for Error subclasses.
    on Object catch (e, st) {
      developer.log(
        '_appendToFile failed (Error)',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
  }

  // =========================================================================
  // Test hooks
  // =========================================================================

  /// Resets the logger to its pre-setProjectRoot state. Test-only. Do NOT
  /// call from production code — the plugin lifecycle is start-once per
  /// analysis-server session.
  static void resetForTesting() {
    _logFilePath = null;
    _buffer.clear();
  }

  /// Exposes the resolved log file path for assertions. Null when
  /// [setProjectRoot] has not yet succeeded. Test-only.
  static String? get logFilePathForTesting => _logFilePath;

  /// Exposes the pending-buffer size for assertions. Test-only.
  static int get bufferSizeForTesting => _buffer.length;
}

/// A single log entry captured either directly to file or buffered in
/// memory before the project root is known. Plain data — no behavior.
final class _LogEntry {
  _LogEntry({
    required this.timestamp,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String message;
  final String? error;
  final String? stackTrace;
}
