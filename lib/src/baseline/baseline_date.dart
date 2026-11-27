import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/native/plugin_logger.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Date-based baseline for ignoring violations in code older than a specified date.
///
/// Uses `git blame` to determine when each line was last committed. Lines
/// committed before the baseline date are "legacy" and their findings hidden.
///
/// ## Usage
///
/// ```yaml
/// # analysis_options_custom.yaml
/// baseline:
///   date: "2025-01-15"  # Ignore violations in code unchanged since this date
/// ```
///
/// ## Why the lookup is synchronous
///
/// Diagnostics are reported from synchronous visitor callbacks, and the
/// analyzer plugin API offers no awaited per-file hook before them. An async
/// preload therefore cannot be correct on a file's first analysis (nothing in
/// the plugin, language server or scan CLI ever called it, so `date:` hid
/// nothing). Blame runs with [Process.runSync] the first time a finding in a
/// file reaches the date check.
///
/// ## Cost
///
/// One `git blame` process per analyzed file that has at least one finding not
/// already hidden by `file:` or `paths:`, repeated only when that file's
/// content changes. Files without such findings never start git.
/// [Process.runSync] has no timeout, so a stalled git stalls the analysis.
///
/// ## Anything git cannot date still reports
///
/// Git missing, no repository, untracked file, uncommitted line: all report.
class BaselineDate {
  BaselineDate(this.baselineDate, {String? gitPath})
    : _gitPath = gitPath ?? 'git';

  /// The cutoff date - violations in code unchanged since this date are ignored.
  final DateTime baselineDate;

  /// Path to git executable.
  final String _gitPath;

  /// Blame answers by file path. Commit dates, not old/new verdicts, are
  /// stored, so an edited `date:` reuses them without a new git run.
  static final Map<String, _FileDateCache> _cache = {};

  /// Git executables that could not be started. Without this, a machine with
  /// no git would retry the failing spawn once for every file.
  static final Set<String> _unstartable = {};

  /// Synchronous form of [isOlderThanBaseline], used by the reporter.
  ///
  /// [content] is the text being analyzed. Passing it keeps line numbers right
  /// for unsaved editor buffers; when null the file on disk is read.
  bool isLineOld(String filePath, int line, {String? content}) {
    if (filePath.isEmpty || line < 1) return false;
    final committed = _lineDates(filePath, content)[line];
    return committed != null && committed.isBefore(baselineDate);
  }

  /// Whether the line was last committed before [baselineDate].
  ///
  /// Returns false if [filePath] is null/empty, [line] < 1, or git cannot
  /// date the line. [projectRoot] is accepted for source compatibility; blame
  /// runs beside the file, so nested repositories and submodules resolve.
  Future<bool> isOlderThanBaseline(
    String? filePath,
    int line, {
    String? projectRoot,
  }) async => filePath != null && isLineOld(filePath, line);

  /// Warms the cache for [filePath]. Optional: the checks load on demand.
  /// No-op if [filePath] is null or empty.
  Future<void> preloadFile(String? filePath, {String? projectRoot}) async {
    if (filePath != null && filePath.isNotEmpty) _lineDates(filePath, null);
  }

  /// Lines of [filePath] last committed before [baselineDate]. Null when git
  /// dates no line (untracked file, no repository), so a caller can tell
  /// "no old lines" from "could not tell".
  Future<List<int>?> oldLines(String filePath, {String? projectRoot}) async {
    final dates = _lineDates(filePath, null);
    if (dates.isEmpty) return null;
    return [
      for (final e in dates.entries)
        if (e.value.isBefore(baselineDate)) e.key,
    ]..sort();
  }

  /// Clear the cache (tests, memory relief); answers reload on demand.
  static void clearCache() {
    _cache.clear();
    _unstartable.clear();
  }

  /// Commit date per line of [filePath], from the cache or one blame run.
  Map<int, DateTime> _lineDates(String filePath, String? content) {
    try {
      final text = content ?? _readDisk(filePath);
      if (text == null) return const {};
      final cached = _cache[filePath];
      // Length plus hash identifies the content without retaining it. A
      // changed file must be blamed again: its line numbers have moved.
      if (cached != null &&
          cached.length == text.length &&
          cached.hash == text.hashCode) {
        return cached.lineDates;
      }
      // An empty answer is cached too, so a failing file spawns git once.
      final dates = _blame(filePath, text);
      _cache[filePath] = _FileDateCache(text.length, text.hashCode, dates);
      return dates;
    }
    // Best effort: any failure means "not old", never a crashed analysis.
    on Object catch (e, st) {
      developer.log(
        'baseline git blame failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return const {};
    }
  }

  /// File text, or null when it cannot be read.
  String? _readDisk(String filePath) {
    try {
      return File(filePath).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Blames [filePath]. When [text] differs from the disk copy (unsaved
  /// buffer), git annotates [text] through `--contents` instead, so edited
  /// lines come back uncommitted rather than inheriting the date of whatever
  /// line used to have that number.
  Map<int, DateTime> _blame(String filePath, String text) {
    if (text == _readDisk(filePath)) return _runBlame(filePath, null);
    final temp = Directory.systemTemp.createTempSync('saropa_blame_');
    try {
      final copy = File(p.join(temp.path, 'contents'))..writeAsStringSync(text);
      return _runBlame(filePath, copy.path);
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  /// Runs one whole-file blame; empty when git gives no answer.
  Map<int, DateTime> _runBlame(String filePath, String? contentsPath) {
    if (_unstartable.contains(_gitPath)) return const {};
    try {
      // No shell: a file name containing `&` or `%` must stay a file name.
      final result = Process.runSync(
        _gitPath,
        [
          // Neither a repository's fsmonitor hook nor a textconv driver may
          // run from inside the analysis server.
          '-c', 'core.fsmonitor=false',
          'blame', '--porcelain', '--no-textconv',
          if (contentsPath != null) ...['--contents', contentsPath],
          '--', p.basename(filePath),
        ],
        // The file's own folder, so git finds the repository that holds it.
        workingDirectory: p.dirname(filePath),
        environment: _gitEnvironment(),
        includeParentEnvironment: false,
        // Source lines in the output need not be valid UTF-8.
        stdoutEncoding: const Utf8Codec(allowMalformed: true),
        stderrEncoding: const Utf8Codec(allowMalformed: true),
      );
      if (result.exitCode != 0) return const {};
      return _parsePorcelain('${result.stdout}');
    } on ProcessException catch (e) {
      _unstartable.add(_gitPath);
      PluginLogger.warning(
        'git could not be started (${e.message}); '
        'baseline date: hides nothing.',
      );
      return const {};
    }
  }

  /// The process environment without the variables that pin git to one
  /// repository. Git hooks export them, and they would override the lookup
  /// from the file's folder.
  Map<String, String> _gitEnvironment() {
    const pinned = {
      'GIT_DIR',
      'GIT_WORK_TREE',
      'GIT_INDEX_FILE',
      'GIT_COMMON_DIR',
    };
    return Map.of(Platform.environment)
      ..removeWhere((key, _) => pinned.contains(key.toUpperCase()));
  }

  /// `<sha> <original-line> <final-line> [<count>]`, SHA-1 or SHA-256.
  static final RegExp _header = RegExp(r'^([0-9a-f]{40,64}) \d+ (\d+)');

  /// The all-zero sha git gives lines that are not committed.
  static final RegExp _uncommitted = RegExp(r'^0+$');

  /// Commit date per line from `--porcelain` output. Git prints a commit's
  /// metadata only the first time that commit appears, so dates are kept per
  /// sha; reading them per line dated only the first line of each commit.
  Map<int, DateTime> _parsePorcelain(String output) {
    final bySha = <String, DateTime>{};
    final byLine = <int, String>{};
    var sha = '';
    for (final line in output.split('\n')) {
      // Source lines are tab-prefixed and can never look like a header.
      if (line.startsWith('\t')) continue;
      final header = _header.firstMatch(line);
      if (header != null) {
        sha = header.group(1) ?? '';
        final number = int.tryParse(header.group(2) ?? '');
        // Uncommitted lines are left undated so they always report, even
        // when the cutoff is in the future.
        if (number != null && !_uncommitted.hasMatch(sha)) {
          byLine[number] = sha;
        }
      } else if (line.startsWith('committer-time ')) {
        final stamp = int.tryParse(
          line.afterIndex('committer-time '.length).trim(),
        );
        if (stamp != null) {
          bySha[sha] = DateTime.fromMillisecondsSinceEpoch(stamp * 1000);
        }
      }
    }
    final dates = <int, DateTime>{};
    byLine.forEach((number, commit) {
      final date = bySha[commit];
      if (date != null) dates[number] = date;
    });
    return dates;
  }

  @override
  String toString() => 'BaselineDate($baselineDate)';
}

/// Blame answers for one version of one file.
class _FileDateCache {
  _FileDateCache(this.length, this.hash, this.lineDates);

  /// Length and hash of the content that was blamed.
  final int length;
  final int hash;

  /// Commit date by 1-based line; uncommitted lines are absent.
  final Map<int, DateTime> lineDates;
}
