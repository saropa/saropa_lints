part of 'project_context.dart';

// =============================================================================
// PATH UTILITIES
// =============================================================================
//
// IMPORTANT: Always use [normalizePath] when using file paths as map keys!
// Windows provides paths with backslashes (d:\src\file.dart) but disk caches
// may store forward slashes (d:/src/file.dart). Without normalization, map
// lookups fail silently on Windows.
//
// See: SAROPA_LINTS_INVESTIGATION.md Issue 6
// =============================================================================

/// Normalizes a file path for use as a map key.
///
/// Converts backslashes to forward slashes for cross-platform consistency.
/// ALWAYS use this when storing or looking up file paths in maps/caches.
///
/// Returns empty string for null or empty input (defensive fallback).
///
/// Example:
/// ```dart
/// // BAD - will fail on Windows:
/// _cache[filePath] = value;
///
/// // GOOD - works everywhere:
/// _cache[normalizePath(filePath)] = value;
/// ```
String normalizePath(String? path) {
  if (path == null || path.isEmpty) return '';
  return path.replaceAll('\\', '/');
}

// =============================================================================
// PROJECT CONTEXT CACHE (Performance Optimization)
// =============================================================================
//
// Provides cached project-level information to avoid redundant file I/O and
// parsing across multiple rules. Each piece of information is computed once
// per project root and reused for all subsequent rule invocations.
//
// Cached data includes:
// 1. Project type detection (Flutter vs pure Dart)
// 2. Pubspec.yaml dependencies
// 3. File type classification
//
// Impact: Reduces redundant file operations across 1400+ rules.
// =============================================================================

// =============================================================================
// BLOOM FILTER (Performance Optimization)
// =============================================================================
//
// A space-efficient probabilistic data structure for O(1) membership testing.
// Used to quickly check if content might contain patterns without scanning.
// False positives possible (says "maybe" when actually "no"), but no false negatives.
//
// Impact: Reduces pattern matching from O(patterns × content) to O(patterns).
// =============================================================================

/// A simple bloom filter for fast string membership testing.
///
/// Use [addAllTokens] to populate with content tokens, then [mightContain]
/// to check if a pattern might be present in O(1) time.
class BloomFilter {
  /// Creates a bloom filter with the specified bit size.
  ///
  /// Larger sizes reduce false positive rate but use more memory.
  /// Default of 8192 bits (1KB) gives ~1% false positive rate for 500 patterns.
  /// If [bitSize] is <= 0, uses 8192 as fallback.
  BloomFilter([int bitSize = 8192])
    : _bits = Uint8List(((bitSize > 0 ? bitSize : 8192) + 7) ~/ 8);

  final Uint8List _bits;
  int get _bitSize => _bits.length * 8;

  // Number of hash functions (k=3 is optimal for our use case)
  static const int _numHashes = 3;

  /// Add a string to the filter.
  /// No-op if [value] is null or empty.
  void add(String? value) {
    if (value == null || value.isEmpty) return;
    final hashes = _getHashes(value);
    for (final hash in hashes) {
      final index = hash % _bitSize;
      _bits[index ~/ 8] |= (1 << (index % 8));
    }
  }

  /// Add all space-separated tokens from content.
  ///
  /// Also adds common substrings (3-10 char prefixes) for partial matching.
  /// No-op if [content] is null.
  void addAllTokens(String? content) {
    if (content == null) return;
    // Add word tokens
    final words = content.split(RegExp(r'[\s\.\(\)\{\}\[\];,<>]+'));
    for (final word in words) {
      if (word.length >= 3) {
        add(word);
        // Add prefixes for partial matching
        for (var len = 3; len <= word.length && len <= 10; len++) {
          add(word.substring(0, len));
        }
      }
    }
  }

  /// Check if the filter might contain a string.
  ///
  /// Returns false if [value] is null or empty (defensive: never "might contain").
  /// Otherwise: false = definitely not in set; true = might be in set (possible false positive).
  bool mightContain(String? value) {
    if (value == null || value.isEmpty) return false;
    final hashes = _getHashes(value);
    for (final hash in hashes) {
      final index = hash % _bitSize;
      if ((_bits[index ~/ 8] & (1 << (index % 8))) == 0) {
        return false;
      }
    }
    return true;
  }

  /// Get k hash values for a string using double hashing.
  List<int> _getHashes(String value) {
    // Use two base hashes and derive k hashes via double hashing
    final h1 = value.hashCode;
    final h2 = _fnv1a(value);

    return List.generate(_numHashes, (i) => (h1 + i * h2).abs());
  }

  /// FNV-1a hash for second hash function.
  static int _fnv1a(String s) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      hash ^= s.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Clear the filter.
  void clear() {
    for (var i = 0; i < _bits.length; i++) {
      _bits[i] = 0;
    }
  }
}

// =============================================================================
// GIT-AWARE PRIORITY (Performance Optimization)
// =============================================================================
//
// Prioritizes analysis of files that git shows as modified. These are the files
// the developer is actively working on and cares about most. Pre-warming caches
// for these files provides faster feedback on the code being edited.
//
// Impact: Faster perceived performance by prioritizing relevant files.
// =============================================================================

/// Tracks git-modified files for analysis prioritization.
///
/// Files that git shows as modified/staged/untracked are likely what the
/// developer cares about. Prioritizing these files provides faster feedback.
class GitAwarePriority {
  GitAwarePriority._();

  // Set of modified file paths (absolute)
  static final Set<String> _modifiedFiles = {};

  // Set of staged file paths (absolute)
  static final Set<String> _stagedFiles = {};

  // Last refresh timestamp
  static DateTime? _lastRefresh;

  // Refresh interval (don't hit git too often)
  static const Duration _refreshInterval = Duration(seconds: 30);

  // Project root for git operations
  static String? _projectRoot;

  /// Initialize with project root.
  static void initialize(String projectRoot) {
    _projectRoot = projectRoot;
    unawaited(refresh());
  }

  /// Refresh the list of modified files from git.
  ///
  /// Automatically throttled to avoid excessive git calls.
  static Future<void> refresh() async {
    final root = _projectRoot;
    if (root == null) return;

    final now = DateTime.now();
    final last = _lastRefresh;
    if (last != null && now.difference(last) < _refreshInterval) {
      return; // Too soon, skip refresh
    }

    try {
      // Get modified and staged files
      final result = await Process.run('git', [
        'status',
        '--porcelain',
        '-z',
      ], workingDirectory: root);

      if (result.exitCode != 0) return;

      _modifiedFiles.clear();
      _stagedFiles.clear();

      final stdoutRaw = result.stdout;
      if (stdoutRaw is! String) return;
      final output = stdoutRaw;
      // Porcelain format with -z: XY<space>path<null>
      final entries = output.split('\x00');
      for (final entry in entries) {
        if (entry.length < 4) continue;

        final status = entry.substring(0, 2);
        final path = entry.substring(3);
        final absolutePath = '$root/$path';

        // Index status (staged)
        if (status[0] != ' ' && status[0] != '?') {
          _stagedFiles.add(absolutePath);
        }

        // Work tree status (modified)
        if (status[1] != ' ') {
          _modifiedFiles.add(absolutePath);
        }

        // Untracked files
        if (status == '??') {
          _modifiedFiles.add(absolutePath);
        }
      }

      _lastRefresh = now;
    } on ProcessException catch (e, st) {
      developer.log(
        'git status refresh failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Git not available or other error - ignore
    } on IOException catch (e, st) {
      developer.log(
        'git status refresh failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Git not available or other error - ignore
    }
  }

  /// Check if a file is modified in the work tree.
  static bool isModified(String filePath) {
    return _modifiedFiles.contains(filePath);
  }

  /// Check if a file is staged for commit.
  static bool isStaged(String filePath) {
    return _stagedFiles.contains(filePath);
  }

  /// Check if a file is either modified or staged.
  static bool isRelevant(String filePath) {
    return _modifiedFiles.contains(filePath) || _stagedFiles.contains(filePath);
  }

  /// Get all modified files.
  static Set<String> get modifiedFiles => Set.unmodifiable(_modifiedFiles);

  /// Get all staged files.
  static Set<String> get stagedFiles => Set.unmodifiable(_stagedFiles);

  /// Get all relevant files (modified + staged).
  static Set<String> get relevantFiles => {..._modifiedFiles, ..._stagedFiles};

  /// Get priority score for a file.
  ///
  /// Returns:
  /// - 0: Not in git status (lowest priority)
  /// - 1: Modified in work tree
  /// - 2: Staged for commit (highest priority)
  static int getPriority(String filePath) {
    if (_stagedFiles.contains(filePath)) return 2;
    if (_modifiedFiles.contains(filePath)) return 1;
    return 0;
  }

  /// Clear cached data.
  static void clear() {
    _modifiedFiles.clear();
    _stagedFiles.clear();
    _lastRefresh = null;
  }
}

/// Cached project context information.
///
/// Provides fast access to project-level data that would otherwise require
/// expensive file I/O operations for each rule.
