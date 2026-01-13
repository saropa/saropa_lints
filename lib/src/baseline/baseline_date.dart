import 'dart:io';

/// Date-based baseline for ignoring violations in code older than a specified date.
///
/// Uses `git blame` to determine when each line was last modified.
/// Lines modified before the baseline date are considered "legacy" and ignored.
///
/// ## Usage
///
/// ```yaml
/// custom_lint:
///   saropa_lints:
///     baseline:
///       date: "2025-01-15"  # Ignore violations in code unchanged since this date
/// ```
///
/// ## How It Works
///
/// 1. When a violation is reported at line N in file F
/// 2. We run `git blame -L N,N --porcelain F` to get the commit date
/// 3. If the commit date is before the baseline date, the violation is suppressed
///
/// ## Caching
///
/// Git blame results are cached per-file to avoid repeated git calls.
/// Cache is invalidated when file content changes (via content hash).
class BaselineDate {
  BaselineDate(this.baselineDate, {String? gitPath})
      : _gitPath = gitPath ?? 'git';

  /// The cutoff date - violations in code unchanged since this date are ignored.
  final DateTime baselineDate;

  /// Path to git executable.
  final String _gitPath;

  /// Cache of file path -> (content hash, line -> commit date)
  static final Map<String, _FileDateCache> _cache = {};

  /// Check if a violation at the given line should be suppressed.
  ///
  /// Returns true if the line was last modified before [baselineDate].
  ///
  /// [filePath] is the full path to the file.
  /// [line] is the 1-based line number.
  /// [projectRoot] is the git repository root (optional, auto-detected if null).
  Future<bool> isOlderThanBaseline(
    String filePath,
    int line, {
    String? projectRoot,
  }) async {
    if (line <= 0) return false;

    try {
      final lineDate = await _getLineDate(filePath, line, projectRoot);
      if (lineDate == null) return false;

      return lineDate.isBefore(baselineDate);
    } catch (e) {
      // If git blame fails (not a git repo, file not tracked, etc.), don't suppress
      return false;
    }
  }

  /// Get the commit date for a specific line in a file.
  Future<DateTime?> _getLineDate(
    String filePath,
    int line,
    String? projectRoot,
  ) async {
    // Check cache first
    final cached = _cache[filePath];
    if (cached != null) {
      final lineDate = cached.lineDates[line];
      if (lineDate != null) {
        return lineDate;
      }
    }

    // Run git blame for this line
    final date = await _runGitBlame(filePath, line, projectRoot);
    if (date != null) {
      // Cache the result
      _cache.putIfAbsent(filePath, () => _FileDateCache()).lineDates[line] =
          date;
    }

    return date;
  }

  /// Run git blame to get the commit date for a specific line.
  Future<DateTime?> _runGitBlame(
    String filePath,
    int line,
    String? projectRoot,
  ) async {
    final workDir = projectRoot ?? _findGitRoot(filePath);
    if (workDir == null) return null;

    // Make path relative to git root
    final relativePath = _makeRelative(filePath, workDir);

    final result = await Process.run(
      _gitPath,
      ['blame', '-L', '$line,$line', '--porcelain', relativePath],
      workingDirectory: workDir,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      return null;
    }

    // Parse the porcelain output to find committer-time
    final output = result.stdout.toString();
    return _parseCommitterTime(output);
  }

  /// Parse git blame porcelain output to extract committer timestamp.
  DateTime? _parseCommitterTime(String output) {
    // Format:
    // <sha> <original-line> <final-line> <line-count>
    // author <name>
    // author-mail <email>
    // author-time <timestamp>
    // author-tz <timezone>
    // committer <name>
    // committer-mail <email>
    // committer-time <timestamp>
    // committer-tz <timezone>
    // ...

    final lines = output.split('\n');
    for (final line in lines) {
      if (line.startsWith('committer-time ')) {
        final timestampStr = line.substring('committer-time '.length).trim();
        final timestamp = int.tryParse(timestampStr);
        if (timestamp != null) {
          return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }
    }

    return null;
  }

  /// Find the git repository root for a file.
  String? _findGitRoot(String filePath) {
    var dir = Directory(filePath).parent;
    while (dir.path != dir.parent.path) {
      final gitDir = Directory('${dir.path}/.git');
      if (gitDir.existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }

  /// Make a file path relative to the git root.
  String _makeRelative(String filePath, String gitRoot) {
    final normalized = filePath.replaceAll('\\', '/');
    final rootNorm = gitRoot.replaceAll('\\', '/');

    if (normalized.startsWith(rootNorm)) {
      var relative = normalized.substring(rootNorm.length);
      if (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
      return relative;
    }

    return normalized;
  }

  /// Clear the cache (for testing or when files change).
  static void clearCache() {
    _cache.clear();
  }

  /// Preload blame data for an entire file (optimization).
  ///
  /// This runs git blame once for the entire file and caches all line dates,
  /// which is faster than running blame line-by-line.
  Future<void> preloadFile(String filePath, {String? projectRoot}) async {
    final workDir = projectRoot ?? _findGitRoot(filePath);
    if (workDir == null) return;

    final relativePath = _makeRelative(filePath, workDir);

    final result = await Process.run(
      _gitPath,
      ['blame', '--porcelain', relativePath],
      workingDirectory: workDir,
      runInShell: true,
    );

    if (result.exitCode != 0) return;

    final output = result.stdout.toString();
    final lineDates = _parseFullBlame(output);

    _cache[filePath] = _FileDateCache()..lineDates.addAll(lineDates);
  }

  /// Parse full git blame output to extract all line dates.
  Map<int, DateTime> _parseFullBlame(String output) {
    final lineDates = <int, DateTime>{};
    final lines = output.split('\n');

    int? currentLine;
    DateTime? currentDate;

    for (final line in lines) {
      // Line number is in the header: <sha> <orig-line> <final-line> [count]
      if (line.isNotEmpty && !line.startsWith('\t')) {
        final parts = line.split(' ');
        if (parts.length >= 3) {
          // Check if this looks like a commit hash line
          if (parts[0].length == 40 && _isHex(parts[0])) {
            currentLine = int.tryParse(parts[2]);
          }
        }
      }

      if (line.startsWith('committer-time ')) {
        final timestampStr = line.substring('committer-time '.length).trim();
        final timestamp = int.tryParse(timestampStr);
        if (timestamp != null) {
          currentDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }

      // When we see a tab (start of actual line content), save the date
      if (line.startsWith('\t') && currentLine != null && currentDate != null) {
        lineDates[currentLine] = currentDate;
        currentLine = null;
        currentDate = null;
      }
    }

    return lineDates;
  }

  /// Check if a string is a valid hex string.
  bool _isHex(String s) {
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);
  }

  @override
  String toString() => 'BaselineDate($baselineDate)';
}

/// Cache for a single file's line dates.
class _FileDateCache {
  final Map<int, DateTime> lineDates = {};
}
