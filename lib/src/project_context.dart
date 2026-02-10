// ignore_for_file: always_specify_types

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

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
/// Example:
/// ```dart
/// // BAD - will fail on Windows:
/// _cache[filePath] = value;
///
/// // GOOD - works everywhere:
/// _cache[normalizePath(filePath)] = value;
/// ```
String normalizePath(String path) => path.replaceAll('\\', '/');

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
  BloomFilter([int bitSize = 8192]) : _bits = Uint8List((bitSize + 7) ~/ 8);

  final Uint8List _bits;
  int get _bitSize => _bits.length * 8;

  // Number of hash functions (k=3 is optimal for our use case)
  static const int _numHashes = 3;

  /// Add a string to the filter.
  void add(String value) {
    final hashes = _getHashes(value);
    for (final hash in hashes) {
      final index = hash % _bitSize;
      _bits[index ~/ 8] |= (1 << (index % 8));
    }
  }

  /// Add all space-separated tokens from content.
  ///
  /// Also adds common substrings (3-10 char prefixes) for partial matching.
  void addAllTokens(String content) {
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
  /// Returns true if definitely NOT in the set.
  /// Returns false if MAYBE in the set (could be false positive).
  bool mightContain(String value) {
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
    refresh();
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
      final result = await Process.run(
        'git',
        ['status', '--porcelain', '-z'],
        workingDirectory: root,
      );

      if (result.exitCode != 0) return;

      _modifiedFiles.clear();
      _stagedFiles.clear();

      final output = result.stdout as String;
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
    } catch (_) {
      // Git not available or other error - silently ignore
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
class ProjectContext {
  ProjectContext._();

  // =========================================================================
  // Project Type Cache
  // =========================================================================

  static final Map<String, _ProjectInfo> _projectCache = {};

  /// Get project info for the given file path.
  ///
  /// Finds the project root (directory containing pubspec.yaml) and caches
  /// the parsed project information for subsequent calls.
  static _ProjectInfo? getProjectInfo(String filePath) {
    final projectRoot = findProjectRoot(filePath);
    if (projectRoot == null) return null;

    return _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
  }

  /// Get the package name for the project at [projectRoot].
  ///
  /// Returns the `name:` field from `pubspec.yaml`, or an empty string
  /// if not found. Result is cached.
  static String getPackageName(String projectRoot) {
    final info = _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
    return info.packageName;
  }

  /// Find the project root directory (contains pubspec.yaml).
  ///
  /// Walks up the directory tree from [filePath] looking for pubspec.yaml.
  /// Returns `null` if no project root is found.
  static String? findProjectRoot(String filePath) {
    final normalized = normalizePath(filePath);
    var dir = Directory(normalized).parent;

    // Walk up the directory tree looking for pubspec.yaml
    while (dir.path.length > 1) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Clear the project cache (useful for testing).
  static void clearCache() {
    _projectCache.clear();
  }
}

/// Cached information about a project.
class _ProjectInfo {
  _ProjectInfo._({
    required this.isFlutterProject,
    required this.dependencies,
    required this.packageName,
  });

  factory _ProjectInfo._fromProjectRoot(String projectRoot) {
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
      );
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final isFlutter = content.contains('flutter:') ||
          content.contains('flutter_test:') ||
          content.contains('sdk: flutter');

      // Parse package name from top-level `name:` field (valid Dart pkg names)
      final nameMatch = RegExp(r'^name:\s+([a-z][a-z0-9_]*)', multiLine: true)
          .firstMatch(content);
      final packageName = nameMatch?.group(1) ?? '';

      // Parse dependencies (simple regex-based parsing)
      final deps = <String>{};
      final depMatches = RegExp(r'^\s+(\w+):').allMatches(content);
      for (final match in depMatches) {
        final dep = match.group(1);
        if (dep != null) deps.add(dep);
      }

      return _ProjectInfo._(
        isFlutterProject: isFlutter,
        dependencies: deps,
        packageName: packageName,
      );
    } catch (_) {
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
      );
    }
  }

  /// Whether this is a Flutter project (has flutter SDK dependency).
  final bool isFlutterProject;

  /// The package name from `pubspec.yaml` (`name:` field).
  final String packageName;

  /// Set of dependency names in the project.
  final Set<String> dependencies;

  /// Check if the project has a specific dependency.
  bool hasDependency(String name) => dependencies.contains(name);
}

// =============================================================================
// FILE CONTENT CACHE (Performance Optimization)
// =============================================================================
//
// Tracks file content hashes to detect unchanged files between analysis runs.
// When a file hasn't changed, we can skip re-running rules that already passed.
// =============================================================================

/// Caches file content hashes to detect unchanged files.
///
/// Usage:
/// ```dart
/// // Check if file changed since last analysis
/// if (!FileContentCache.hasChanged(path, content)) {
///   return; // Skip - file unchanged
/// }
/// ```
class FileContentCache {
  FileContentCache._();

  // Map of file path -> content hash
  static final Map<String, int> _contentHashes = {};

  // Map of file path -> set of rules that passed on this file
  static final Map<String, Set<String>> _passedRules = {};

  /// Check if file content has changed since last analysis.
  ///
  /// Returns `true` if the file is new or has changed.
  /// Returns `false` if the file content is identical to the cached version.
  static bool hasChanged(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    final newHash = content.hashCode;
    final oldHash = _contentHashes[normalizedPath];

    if (oldHash == null || oldHash != newHash) {
      // File is new or changed - update cache and clear passed rules
      _contentHashes[normalizedPath] = newHash;
      _passedRules.remove(normalizedPath);
      return true;
    }

    return false;
  }

  /// Record that a rule passed (no violations) on a file.
  ///
  /// Call this after a rule completes with no violations.
  static void recordRulePassed(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _passedRules.putIfAbsent(normalizedPath, () => {}).add(ruleName);
  }

  /// Check if a rule previously passed on an unchanged file.
  ///
  /// Returns `true` if the file is unchanged AND the rule passed before.
  static bool rulePreviouslyPassed(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _passedRules[normalizedPath]?.contains(ruleName) ?? false;
  }

  /// Clear cache for a specific file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _contentHashes.remove(normalizedPath);
    _passedRules.remove(normalizedPath);
  }

  /// Clear all cached data (useful for testing).
  static void clearCache() {
    _contentHashes.clear();
    _passedRules.clear();
  }
}

// =============================================================================
// FILE TYPE CLASSIFICATION (Performance Optimization)
// =============================================================================
//
// Classifies files by type to enable early rule skipping. Rules that only
// apply to specific file types can check this once instead of analyzing
// the entire file.
// =============================================================================

/// Classification of a Dart file for rule filtering.
enum FileType {
  /// A widget file (contains StatelessWidget, StatefulWidget, etc.)
  widget,

  /// A test file (*_test.dart, in test/ directory)
  test,

  /// A Bloc/Cubit file (contains Bloc, Cubit classes)
  bloc,

  /// A Provider/Riverpod file (contains providers)
  provider,

  /// A model/entity file (data classes, entities)
  model,

  /// A service/repository file
  service,

  /// Unknown or general Dart file
  general,
}

/// Fast file type detection based on file path and content.
class FileTypeDetector {
  FileTypeDetector._();

  static final Map<String, Set<FileType>> _cache = {};

  /// Detect file types for the given file.
  ///
  /// Returns a set of applicable file types (a file can be multiple types).
  /// Results are cached per file path.
  static Set<FileType> detect(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);

    // Check cache first
    if (_cache.containsKey(normalizedPath)) {
      return _cache[normalizedPath]!;
    }

    final types = <FileType>{};

    // Path-based detection (fast)
    if (isTestPath(normalizedPath)) {
      types.add(FileType.test);
    }

    // Content-based detection (only if needed)
    if (content.contains('extends StatelessWidget') ||
        content.contains('extends StatefulWidget') ||
        content.contains('extends State<')) {
      types.add(FileType.widget);
    }

    if (content.contains('extends Bloc<') ||
        content.contains('extends Cubit<')) {
      types.add(FileType.bloc);
    }

    // Provider/Riverpod detection - use specific patterns to avoid false positives
    if (content.contains('@riverpod') ||
        content.contains('ConsumerWidget') ||
        content.contains('ConsumerStatefulWidget') ||
        content.contains('ProviderScope') ||
        content.contains('ref.watch(') ||
        content.contains('ref.read(') ||
        content.contains('ChangeNotifierProvider') ||
        content.contains('StateNotifierProvider')) {
      types.add(FileType.provider);
    }

    if (types.isEmpty) {
      types.add(FileType.general);
    }

    _cache[normalizedPath] = types;
    return types;
  }

  /// Fast path-only check for test files.
  ///
  /// Expects a normalized path (forward slashes). Matches:
  /// - `*_test.dart` files
  /// - Files in `/test/`, `/test_driver/`, or `/integration_test/` directories
  static bool isTestPath(String normalizedPath) {
    return normalizedPath.endsWith('_test.dart') ||
        normalizedPath.contains('/test/') ||
        normalizedPath.contains('/test_driver/') ||
        normalizedPath.contains('/integration_test/');
  }

  /// Check if file is a specific type.
  static bool isType(String filePath, String content, FileType type) {
    return detect(filePath, content).contains(type);
  }

  /// Clear the cache (useful for testing).
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// RULE COST CLASSIFICATION (Performance Optimization)
// =============================================================================
//
// Each rule declares its own cost via the `cost` getter in SaropaLintRule.
// Fast rules run first, slow rules run last.
// =============================================================================

/// Estimated cost of running a rule.
///
/// Rules override the `cost` getter in SaropaLintRule to declare their cost.
/// The framework sorts rules by cost before execution.
enum RuleCost {
  /// Very fast rules (simple pattern matching)
  /// Examples: check for specific method name, check for parameter
  trivial,

  /// Fast rules (single AST node inspection)
  /// Examples: check constructor parameters, check method signature
  low,

  /// Medium cost rules (traverse part of AST) - DEFAULT
  /// Examples: check method body, check class members
  medium,

  /// High cost rules (traverse full AST or type resolution)
  /// Examples: check for circular dependencies, complex type analysis
  high,

  /// Very expensive rules (cross-file analysis simulation)
  /// Examples: check imports across project, dependency graph
  extreme,
}

// =============================================================================
// COMBINED PATTERN INDEX (Performance Optimization)
// =============================================================================
//
// Instead of each rule scanning for its patterns individually, we build a
// combined index once and scan the file content ONCE to determine which rules
// can skip. This reduces O(rules × patterns × content) to O(patterns × content).
//
// For 1400+ rules with an average of 2 patterns each, this is a 1400x speedup
// for the pattern-matching phase.
// =============================================================================

/// Builds and manages a combined pattern index for fast rule filtering.
///
/// Usage:
/// ```dart
/// // Build index from all enabled rules (once at startup)
/// PatternIndex.build(enabledRules);
///
/// // For each file, scan once to get matching rules
/// final matchingRules = PatternIndex.getMatchingRules(content);
///
/// // Only run rules that match
/// for (final rule in matchingRules) { ... }
/// ```
class PatternIndex {
  PatternIndex._();

  // Map of pattern -> set of rule names that require it
  static final Map<String, Set<String>> _patternToRules = {};

  // Set of rules with no patterns (always run)
  static final Set<String> _rulesWithNoPatterns = {};

  // Cached list of all patterns for fast iteration
  static List<String>? _allPatterns;

  // LRU cache of bloom filters for recently analyzed content
  static final LruCache<int, BloomFilter> _bloomCache = LruCache(maxSize: 200);

  /// Build the pattern index from enabled rules.
  ///
  /// Call this once when the plugin initializes with the filtered rule list.
  /// Rules that declare `requiredPatterns` will be indexed; rules without
  /// patterns are tracked separately and always run.
  static void build(Iterable<RulePatternInfo> rules) {
    _patternToRules.clear();
    _rulesWithNoPatterns.clear();
    _allPatterns = null;

    for (final rule in rules) {
      final patterns = rule.patterns;
      if (patterns == null || patterns.isEmpty) {
        _rulesWithNoPatterns.add(rule.name);
      } else {
        for (final pattern in patterns) {
          _patternToRules.putIfAbsent(pattern, () => {}).add(rule.name);
        }
      }
    }

    _allPatterns = _patternToRules.keys.toList();
  }

  /// Get the set of rule names that should run on this content.
  ///
  /// Uses a bloom filter for O(1) pre-screening of patterns, then
  /// confirms matches with actual string search. Returns rules that either:
  /// - Have no patterns (always run)
  /// - Have at least one matching pattern in the content
  static Set<String> getMatchingRules(String content) {
    final matching = <String>{..._rulesWithNoPatterns};

    final patterns = _allPatterns;
    if (patterns == null || patterns.isEmpty) {
      return matching;
    }

    // Get or create bloom filter for this content
    final contentHash = content.hashCode;
    var bloom = _bloomCache.get(contentHash);
    if (bloom == null) {
      bloom = BloomFilter();
      bloom.addAllTokens(content);
      _bloomCache.put(contentHash, bloom);
    }

    // Use bloom filter for fast pre-screening, then confirm with contains()
    for (final pattern in patterns) {
      // Bloom filter: O(1) check - if false, definitely not present
      if (!bloom.mightContain(pattern)) continue;

      // Bloom filter said "maybe" - confirm with actual search
      if (content.contains(pattern)) {
        final rules = _patternToRules[pattern];
        if (rules != null) {
          matching.addAll(rules);
        }
      }
    }

    return matching;
  }

  /// Check if a specific rule should run based on pattern matching.
  ///
  /// Uses bloom filter for O(1) pre-screening when available.
  /// Returns true if the rule has no patterns OR has a matching pattern.
  static bool shouldRuleRun(String ruleName, String content) {
    if (_rulesWithNoPatterns.contains(ruleName)) return true;

    // Get or create bloom filter for this content
    final contentHash = content.hashCode;
    var bloom = _bloomCache.get(contentHash);
    if (bloom == null) {
      bloom = BloomFilter();
      bloom.addAllTokens(content);
      _bloomCache.put(contentHash, bloom);
    }

    // Find patterns for this rule, using bloom filter pre-screening
    for (final entry in _patternToRules.entries) {
      if (entry.value.contains(ruleName)) {
        // Bloom filter: O(1) check
        if (!bloom.mightContain(entry.key)) continue;
        // Confirm with actual search
        if (content.contains(entry.key)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if the index is built.
  static bool get isBuilt => _allPatterns != null;

  /// Clear the index (useful for testing).
  static void clear() {
    _patternToRules.clear();
    _rulesWithNoPatterns.clear();
    _allPatterns = null;
  }
}

/// Information about a rule's patterns for index building.
class RulePatternInfo {
  const RulePatternInfo({required this.name, required this.patterns});

  final String name;
  final Set<String>? patterns;
}

// =============================================================================
// FILE METRICS CACHE (Performance Optimization)
// =============================================================================
//
// Caches computed file metrics (line count, complexity indicators, etc.)
// to avoid re-computing them for each rule. Many rules check similar metrics.
// =============================================================================

/// Cached metrics about a file's content.
///
/// Computed once per file and reused across all rules.
class FileMetrics {
  const FileMetrics({
    required this.lineCount,
    required this.characterCount,
    required this.importCount,
    required this.classCount,
    required this.functionCount,
    required this.hasAsyncCode,
    required this.hasWidgets,
    required this.hasFlutterImport,
    required this.hasBlocImport,
    required this.hasProviderImport,
    required this.hasRiverpodImport,
  });

  final int lineCount;
  final int characterCount;
  final int importCount;
  final int classCount;
  final int functionCount;
  final bool hasAsyncCode;
  final bool hasWidgets;

  /// Whether file imports package:flutter/
  final bool hasFlutterImport;

  /// Whether file imports package:bloc/ or package:flutter_bloc/
  final bool hasBlocImport;

  /// Whether file imports package:provider/
  final bool hasProviderImport;

  /// Whether file imports package:riverpod/ or package:flutter_riverpod/
  final bool hasRiverpodImport;

  /// Fast complexity estimation without full AST parsing.
  bool get isLikelyComplex =>
      lineCount > 200 || classCount > 3 || functionCount > 10;

  /// Check if file is tiny (likely a model, enum, or simple utility).
  bool get isTiny => lineCount < 20 && classCount <= 1;
}

/// Computes and caches file metrics for fast access.
class FileMetricsCache {
  FileMetricsCache._();

  static final Map<String, FileMetrics> _cache = {};

  /// Get metrics for a file, computing if not cached.
  static FileMetrics get(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    return _cache.putIfAbsent(normalizedPath, () => _compute(content));
  }

  /// Compute metrics from content (fast regex-based, not AST).
  static FileMetrics _compute(String content) {
    // Line count: count newlines
    var lineCount = 1;
    var importCount = 0;
    var classCount = 0;
    var functionCount = 0;

    final lines = content.split('\n');
    lineCount = lines.length;

    // Simple pattern matching for quick estimates
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ')) importCount++;
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ')) {
        classCount++;
      }
      if (trimmed.contains(' Function') ||
          RegExp(r'^\s*\w+\s+\w+\s*\(').hasMatch(line)) {
        functionCount++;
      }
    }

    // Package import detection (single pass through content)
    final hasFlutterImport = content.contains('package:flutter/');
    final hasBlocImport = content.contains('package:bloc/') ||
        content.contains('package:flutter_bloc/');
    final hasProviderImport = content.contains('package:provider/');
    final hasRiverpodImport = content.contains('package:riverpod/') ||
        content.contains('package:flutter_riverpod/') ||
        content.contains('package:hooks_riverpod/');

    return FileMetrics(
      lineCount: lineCount,
      characterCount: content.length,
      importCount: importCount,
      classCount: classCount,
      functionCount: functionCount,
      hasAsyncCode: content.contains('async') || content.contains('Future'),
      hasWidgets: content.contains('Widget') || content.contains('State<'),
      hasFlutterImport: hasFlutterImport,
      hasBlocImport: hasBlocImport,
      hasProviderImport: hasProviderImport,
      hasRiverpodImport: hasRiverpodImport,
    );
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _cache.remove(normalizedPath);
  }

  /// Clear all cached metrics.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// SMART CONTENT FILTER (Performance Optimization)
// =============================================================================
//
// Uses multiple quick heuristics to skip rules that definitely won't apply.
// This is faster than AST parsing and catches obvious mismatches.
// =============================================================================

/// Quick content-based filtering to skip rules early.
///
/// Combines multiple heuristics for maximum filtering before AST parsing:
/// - Required patterns (string contains)
/// - Minimum/maximum line counts
/// - Required keywords (class, async, etc.)
/// - File type indicators
class SmartContentFilter {
  SmartContentFilter._();

  /// Check if a rule should potentially run based on content heuristics.
  ///
  /// Returns `false` if the rule definitely won't find anything.
  /// Returns `true` if the rule might find violations (needs AST check).
  ///
  /// **WARNING**: [maximumLines] skips analysis on large files. Only use
  /// for rules with O(n²) complexity. Large files often need linting most!
  static bool mightApply({
    required String content,
    required String filePath,
    Set<String>? requiredPatterns,
    int minimumLines = 0,
    int maximumLines = 0,
    Set<String>? requiredKeywords,
    bool requiresAsync = false,
    bool requiresWidgets = false,
  }) {
    final metrics = FileMetricsCache.get(filePath, content);

    // Check minimum line count (skip tiny files for complex rules)
    if (minimumLines > 0 && metrics.lineCount < minimumLines) return false;

    // Check maximum line count (DANGEROUS - skips analysis!)
    if (maximumLines > 0 && metrics.lineCount > maximumLines) return false;

    // Check async requirement
    if (requiresAsync && !metrics.hasAsyncCode) return false;

    // Check widget requirement
    if (requiresWidgets && !metrics.hasWidgets) return false;

    // Check required patterns (any must match)
    if (requiredPatterns != null && requiredPatterns.isNotEmpty) {
      if (!requiredPatterns.any((p) => content.contains(p))) return false;
    }

    // Check required keywords (all must match)
    if (requiredKeywords != null && requiredKeywords.isNotEmpty) {
      if (!requiredKeywords.every((k) => content.contains(k))) return false;
    }

    return true;
  }
}

// =============================================================================
// INCREMENTAL ANALYSIS TRACKER (Performance Optimization)
// =============================================================================
//
// Tracks which files have been fully analyzed with no violations, allowing
// us to skip re-analysis until the file changes. This is especially valuable
// for large projects where most files pass all rules.
//
// **DISK PERSISTENCE**: Cache survives IDE restarts by saving to
// `.dart_tool/saropa_lints_cache.json`. This prevents re-analyzing the entire
// project on every IDE restart.
// =============================================================================

/// Tracks clean files for incremental analysis optimization.
///
/// A "clean" file is one that passed all enabled rules with no violations.
/// Clean files can be skipped entirely on subsequent analysis runs until
/// either the file changes or the rule set changes.
///
/// **Persistence**: Call [loadFromDisk] at startup and [saveToDisk] periodically
/// to survive IDE restarts. Cache is stored in `.dart_tool/saropa_lints_cache.json`.
class IncrementalAnalysisTracker {
  IncrementalAnalysisTracker._();

  // Map of file path -> (content hash, set of passed rule names)
  static final Map<String, _FileAnalysisState> _state = {};

  // Hash of the current rule configuration (tier + enabled rules)
  static int? _ruleConfigHash;

  // Project root for disk cache location
  static String? _projectRoot;

  // Track if cache is dirty (needs saving)
  static bool _isDirty = false;

  // Counter for auto-save throttling
  static int _changesSinceLastSave = 0;
  static const int _autoSaveThreshold = 50; // Save after 50 changes

  /// Cache file name (stored in .dart_tool/)
  static const String _cacheFileName = 'saropa_lints_cache.json';

  /// Set the project root for disk cache location.
  ///
  /// Call this once when initializing the linter.
  static void setProjectRoot(String projectRoot) {
    if (_projectRoot != projectRoot) {
      _projectRoot = projectRoot;
      // Try to load existing cache
      loadFromDisk();
    }
  }

  /// Set the current rule configuration hash.
  ///
  /// Call this when rules are loaded. If the hash changes, all cached
  /// analysis results are invalidated.
  static void setRuleConfig(int configHash) {
    if (_ruleConfigHash != configHash) {
      _state.clear();
      _ruleConfigHash = configHash;
      _isDirty = true;
      // Don't auto-save here - config change might be temporary
    }
  }

  /// Disable incremental caching entirely.
  ///
  /// Cache is DISABLED BY DEFAULT due to bugs causing stale "passed" entries.
  /// Set SAROPA_LINTS_ENABLE_CACHE=true to re-enable (not recommended).
  static final bool _cacheDisabled =
      !(const bool.fromEnvironment('SAROPA_LINTS_ENABLE_CACHE') ||
          const String.fromEnvironment('SAROPA_LINTS_ENABLE_CACHE') == 'true');

  /// Check if a rule can be skipped for this file.
  ///
  /// Returns `true` if:
  /// - The file's content hash matches the cached hash
  /// - The rule previously passed on this file
  static bool canSkipRule(String filePath, String content, String ruleName) {
    // Allow complete cache bypass for debugging
    if (_cacheDisabled) return false;

    // Normalize path separators for cross-platform consistency
    final normalizedPath = normalizePath(filePath);
    final state = _state[normalizedPath];
    if (state == null) return false;

    // Check if file changed
    final currentHash = content.hashCode;
    if (state.contentHash != currentHash) {
      // File changed - invalidate
      _state.remove(normalizedPath);
      _isDirty = true;
      return false;
    }

    return state.passedRules.contains(ruleName);
  }

  /// Record that a rule passed on a file.
  static void recordRulePassed(
    String filePath,
    String content,
    String ruleName,
  ) {
    // Skip recording if cache is disabled
    if (_cacheDisabled) return;

    // Normalize path separators for cross-platform consistency
    final normalizedPath = normalizePath(filePath);
    final hash = content.hashCode;
    final state = _state.putIfAbsent(
      normalizedPath,
      () => _FileAnalysisState(contentHash: hash),
    );

    // Update hash if changed
    if (state.contentHash != hash) {
      state.contentHash = hash;
      state.passedRules.clear();
    }

    final wasAdded = state.passedRules.add(ruleName);
    if (wasAdded) {
      _isDirty = true;
      _changesSinceLastSave++;

      // Auto-save periodically to avoid losing too much work
      if (_changesSinceLastSave >= _autoSaveThreshold) {
        saveToDisk();
      }
    }
  }

  /// Check if a file is completely clean (all rules passed).
  static bool isFileClean(String filePath, int totalRuleCount) {
    final normalizedPath = normalizePath(filePath);
    final state = _state[normalizedPath];
    return state != null && state.passedRules.length >= totalRuleCount;
  }

  /// Clear all tracking data.
  static void clearCache() {
    _state.clear();
    _ruleConfigHash = null;
    _isDirty = true;
    saveToDisk(); // Persist the clear
  }

  // ===========================================================================
  // DISK PERSISTENCE
  // ===========================================================================

  /// Get the cache file path.
  static String? get _cacheFilePath {
    if (_projectRoot == null) return null;
    return '$_projectRoot/.dart_tool/$_cacheFileName';
  }

  /// Load cache from disk.
  ///
  /// Call this once at startup. Silently fails if no cache exists.
  static void loadFromDisk() {
    // Skip loading if cache is disabled
    if (_cacheDisabled) return;

    final path = _cacheFilePath;
    if (path == null) return;

    try {
      final file = File(path);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final json = _parseJson(content);
      if (json == null) return;

      // Check version compatibility
      final version = json['version'] as int?;
      if (version != 1) {
        // Incompatible version - discard
        file.deleteSync();
        return;
      }

      // Check config hash - if different, cache is invalid
      final savedConfigHash = json['configHash'] as int?;
      if (savedConfigHash != null && _ruleConfigHash != null) {
        if (savedConfigHash != _ruleConfigHash) {
          // Config changed - discard cache
          return;
        }
      }

      // Load file states
      final files = json['files'] as Map<String, dynamic>?;
      if (files == null) return;

      _state.clear();
      for (final entry in files.entries) {
        final fileData = entry.value as Map<String, dynamic>?;
        if (fileData == null) continue;

        final contentHash = fileData['hash'] as int?;
        final rules = fileData['rules'] as List<dynamic>?;

        if (contentHash != null && rules != null) {
          _state[entry.key] = _FileAnalysisState(contentHash: contentHash)
            ..passedRules.addAll(rules.cast<String>());
        }
      }

      _isDirty = false;
      _changesSinceLastSave = 0;
    } catch (_) {
      // Silently ignore load errors - cache is optional
    }
  }

  /// Save cache to disk.
  ///
  /// Call this periodically or when analysis completes.
  static void saveToDisk() {
    // Skip saving if cache is disabled
    if (_cacheDisabled) return;
    if (!_isDirty) return;

    final path = _cacheFilePath;
    if (path == null) return;

    try {
      final json = <String, dynamic>{
        'version': 1,
        'configHash': _ruleConfigHash,
        'savedAt': DateTime.now().toIso8601String(),
        'files': <String, dynamic>{
          for (final entry in _state.entries)
            entry.key: <String, dynamic>{
              'hash': entry.value.contentHash,
              'rules': entry.value.passedRules.toList(),
            },
        },
      };

      // Ensure .dart_tool directory exists
      final dartToolDir = Directory('$_projectRoot/.dart_tool');
      if (!dartToolDir.existsSync()) {
        dartToolDir.createSync(recursive: true);
      }

      // Write atomically (write to temp, then rename)
      final tempPath = '$path.tmp';
      final tempFile = File(tempPath);
      tempFile.writeAsStringSync(_toJson(json));
      tempFile.renameSync(path);

      _isDirty = false;
      _changesSinceLastSave = 0;
    } catch (_) {
      // Silently ignore save errors - cache is optional
    }
  }

  /// Parse JSON safely.
  static Map<String, dynamic>? _parseJson(String content) {
    try {
      // Simple JSON parsing without importing dart:convert in header
      // Uses a minimal approach for the cache format
      final trimmed = content.trim();
      if (!trimmed.startsWith('{')) return null;

      // For simplicity, we'll use a basic approach
      // In production, you'd want proper JSON parsing
      return _simpleJsonParse(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// Simple JSON parser for cache format.
  static Map<String, dynamic>? _simpleJsonParse(String json) {
    // This is a simplified parser for our specific cache format
    // For robustness, consider using dart:convert
    try {
      // Remove outer braces and parse key-value pairs
      // This is intentionally simple - real impl would use dart:convert
      final result = <String, dynamic>{};

      // Match "key": value patterns
      final versionMatch = RegExp(r'"version":\s*(\d+)').firstMatch(json);
      if (versionMatch != null) {
        result['version'] = int.parse(versionMatch.group(1)!);
      }

      final configHashMatch =
          RegExp(r'"configHash":\s*(-?\d+)').firstMatch(json);
      if (configHashMatch != null) {
        result['configHash'] = int.parse(configHashMatch.group(1)!);
      }

      // Parse files section - this is complex, so we'll use a regex approach
      final filesMatch =
          RegExp(r'"files":\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}').firstMatch(json);
      if (filesMatch != null) {
        final filesContent = filesMatch.group(1)!;
        final files = <String, dynamic>{};

        // Match each file entry: "path": {"hash": N, "rules": [...]}
        final filePattern = RegExp(
          r'"([^"]+)":\s*\{\s*"hash":\s*(-?\d+),\s*"rules":\s*\[([^\]]*)\]\s*\}',
        );

        for (final match in filePattern.allMatches(filesContent)) {
          final path = match.group(1)!;
          final hash = int.parse(match.group(2)!);
          final rulesStr = match.group(3)!;

          // Parse rules array
          final rules = <String>[];
          final rulePattern = RegExp(r'"([^"]+)"');
          for (final ruleMatch in rulePattern.allMatches(rulesStr)) {
            rules.add(ruleMatch.group(1)!);
          }

          files[path] = <String, dynamic>{
            'hash': hash,
            'rules': rules,
          };
        }

        result['files'] = files;
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Convert to JSON string.
  static String _toJson(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    _writeJson(buffer, data, 0);
    return buffer.toString();
  }

  static void _writeJson(StringBuffer buffer, dynamic value, int indent) {
    final spaces = '  ' * indent;
    final nextSpaces = '  ' * (indent + 1);

    if (value == null) {
      buffer.write('null');
    } else if (value is bool) {
      buffer.write(value.toString());
    } else if (value is num) {
      buffer.write(value.toString());
    } else if (value is String) {
      // Escape special characters
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      buffer.write('"$escaped"');
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.write('[]');
      } else {
        buffer.writeln('[');
        for (var i = 0; i < value.length; i++) {
          buffer.write(nextSpaces);
          _writeJson(buffer, value[i], indent + 1);
          if (i < value.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$spaces]');
      }
    } else if (value is Map) {
      if (value.isEmpty) {
        buffer.write('{}');
      } else {
        buffer.writeln('{');
        final entries = value.entries.toList();
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          buffer.write('$nextSpaces"${entry.key}": ');
          _writeJson(buffer, entry.value, indent + 1);
          if (i < entries.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$spaces}');
      }
    }
  }

  /// Get statistics about the cache.
  static Map<String, dynamic> getStats() {
    var totalRules = 0;
    for (final state in _state.values) {
      totalRules += state.passedRules.length;
    }

    return {
      'files': _state.length,
      'totalPassedRules': totalRules,
      'isDirty': _isDirty,
      'changesSinceLastSave': _changesSinceLastSave,
      'hasProjectRoot': _projectRoot != null,
    };
  }
}

class _FileAnalysisState {
  _FileAnalysisState({required this.contentHash});

  int contentHash;
  final Set<String> passedRules = {};
}

// =============================================================================
// RULE PRIORITY QUEUE (Performance Optimization)
// =============================================================================
//
// Sorts rules by cost so cheaper rules run first. This enables "fail fast"
// behavior - if a cheap rule finds violations, we can skip expensive rules
// in certain scenarios. Even without skipping, running cheap rules first
// provides faster initial feedback to developers.
// =============================================================================

/// Manages rule execution order for optimal performance.
///
/// Principles:
/// 1. Cheap rules first - provides faster initial feedback
/// 2. Fail-fast grouping - group related rules so failures skip related checks
/// 3. Content-aware ordering - reorder based on what patterns matched
class RulePriorityQueue {
  RulePriorityQueue._();

  static final Map<String, int> _rulePriority = {};

  /// Build priority index from rules.
  ///
  /// Priority is based on:
  /// 1. RuleCost (trivial=0, low=100, medium=200, high=300, extreme=400)
  /// 2. Pattern specificity (more patterns = lower priority)
  /// 3. Historical performance (TODO: track actual execution times)
  static void build(Iterable<RulePriorityInfo> rules) {
    _rulePriority.clear();

    for (final rule in rules) {
      final basePriority = _costToPriority(rule.cost);
      final patternAdjustment = (rule.patternCount) * 5;

      _rulePriority[rule.name] = basePriority + patternAdjustment;
    }
  }

  static int _costToPriority(RuleCost cost) {
    return switch (cost) {
      RuleCost.trivial => 0,
      RuleCost.low => 100,
      RuleCost.medium => 200,
      RuleCost.high => 300,
      RuleCost.extreme => 400,
    };
  }

  /// Sort rules by priority (lowest priority number runs first).
  static List<T> sortByPriority<T>(
    List<T> rules,
    String Function(T) getName,
  ) {
    return [...rules]..sort((a, b) {
        final pa = _rulePriority[getName(a)] ?? 200;
        final pb = _rulePriority[getName(b)] ?? 200;
        return pa.compareTo(pb);
      });
  }

  /// Get priority for a rule (lower = runs first).
  static int getPriority(String ruleName) {
    return _rulePriority[ruleName] ?? 200;
  }

  /// Clear the priority index.
  static void clear() {
    _rulePriority.clear();
  }
}

/// Information for building rule priority.
class RulePriorityInfo {
  const RulePriorityInfo({
    required this.name,
    required this.cost,
    required this.patternCount,
  });

  final String name;
  final RuleCost cost;
  final int patternCount;
}

// =============================================================================
// CONTENT REGION INDEX (Performance Optimization)
// =============================================================================
//
// Indexes content into regions (imports, class declarations, function bodies)
// so rules can scan only relevant portions. A rule checking imports doesn't
// need to scan function bodies, and vice versa.
// =============================================================================

/// Pre-indexed content regions for targeted scanning.
class ContentRegions {
  const ContentRegions({
    required this.importRegion,
    required this.classDeclarations,
    required this.topLevelCode,
    required this.hasMain,
  });

  /// Lines containing import/export statements.
  final String importRegion;

  /// Class declaration headers (just the "class X extends Y" parts).
  final List<String> classDeclarations;

  /// Top-level code outside of classes.
  final String topLevelCode;

  /// Whether file has a main() function.
  final bool hasMain;
}

/// Indexes file content into regions for targeted rule scanning.
class ContentRegionIndex {
  ContentRegionIndex._();

  static final Map<String, ContentRegions> _cache = {};

  /// Get indexed regions for a file.
  static ContentRegions get(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    return _cache.putIfAbsent(normalizedPath, () => _index(content));
  }

  static ContentRegions _index(String content) {
    final lines = content.split('\n');
    final importLines = <String>[];
    final classDeclarations = <String>[];
    final topLevelLines = <String>[];

    var hasMain = false;
    var inClassBody = false;
    var braceDepth = 0;

    for (final line in lines) {
      final trimmed = line.trimLeft();

      // Track import region
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
        importLines.add(line);
        continue;
      }

      // Track main function
      if (trimmed.contains('void main(') || trimmed.contains('main()')) {
        hasMain = true;
      }

      // Track class declarations
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ') ||
          trimmed.startsWith('mixin ') ||
          trimmed.startsWith('extension ')) {
        classDeclarations.add(trimmed.split('{').first.trim());
        inClassBody = true;
        braceDepth = 1;
        continue;
      }

      // Track brace depth for class body detection
      if (inClassBody) {
        braceDepth += '{'.allMatches(line).length;
        braceDepth -= '}'.allMatches(line).length;
        if (braceDepth <= 0) {
          inClassBody = false;
        }
      } else {
        topLevelLines.add(line);
      }
    }

    return ContentRegions(
      importRegion: importLines.join('\n'),
      classDeclarations: classDeclarations,
      topLevelCode: topLevelLines.join('\n'),
      hasMain: hasMain,
    );
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
  }

  /// Clear all cached regions.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// AST NODE TYPE REGISTRY (Performance Optimization)
// =============================================================================
//
// Groups rules by which AST node types they visit. Instead of each rule
// registering its own visitor callbacks, we batch all rules that care about
// the same node type and invoke them together. This reduces the overhead of
// AST traversal significantly.
// =============================================================================

/// Types of AST nodes that rules commonly care about.
enum AstNodeCategory {
  /// Import/export declarations
  imports,

  /// Class declarations (class, mixin, extension)
  classDecl,

  /// Method/function declarations
  functions,

  /// Variable/field declarations
  variables,

  /// Constructor declarations
  constructors,

  /// Method invocations (calls)
  invocations,

  /// Literal expressions (strings, numbers, lists, maps)
  literals,

  /// Control flow (if, for, while, switch)
  controlFlow,

  /// Try/catch/finally blocks
  errorHandling,

  /// Async-related (async, await, Future)
  asyncCode,

  /// Annotations/metadata
  annotations,

  /// Full compilation unit (whole file)
  compilationUnit,
}

/// Tracks which rules care about which AST node types.
///
/// This allows the framework to batch rule invocations by node type,
/// reducing AST traversal overhead.
class AstNodeTypeRegistry {
  AstNodeTypeRegistry._();

  static final Map<AstNodeCategory, Set<String>> _categoryToRules = {};
  static final Map<String, Set<AstNodeCategory>> _ruleToCategories = {};

  /// Register which categories a rule cares about.
  static void register(String ruleName, Set<AstNodeCategory> categories) {
    _ruleToCategories[ruleName] = categories;

    for (final category in categories) {
      _categoryToRules.putIfAbsent(category, () => {}).add(ruleName);
    }
  }

  /// Get all rules that care about a specific node category.
  static Set<String> getRulesForCategory(AstNodeCategory category) {
    return _categoryToRules[category] ?? {};
  }

  /// Get all categories a rule cares about.
  static Set<AstNodeCategory> getCategoriesForRule(String ruleName) {
    return _ruleToCategories[ruleName] ?? {};
  }

  /// Check if a rule cares about a specific category.
  static bool ruleCaresAbout(String ruleName, AstNodeCategory category) {
    return _ruleToCategories[ruleName]?.contains(category) ?? false;
  }

  /// Check if ANY enabled rule cares about a category.
  ///
  /// If no rules care about a category, we can skip that part of AST traversal.
  static bool anyCareAbout(AstNodeCategory category) {
    final rules = _categoryToRules[category];
    return rules != null && rules.isNotEmpty;
  }

  /// Clear all registrations.
  static void clear() {
    _categoryToRules.clear();
    _ruleToCategories.clear();
  }
}

// =============================================================================
// VIOLATION BATCH REPORTER (Performance Optimization)
// =============================================================================
//
// Batches violation reports to reduce I/O overhead. Instead of reporting
// each violation immediately, we collect them and flush in batches.
// =============================================================================

/// Batches violations for more efficient reporting.
class ViolationBatch {
  ViolationBatch._();

  static final List<_BatchedViolation> _pending = [];
  static const int _batchSize = 50;

  /// Queue a violation for batched reporting.
  static void add({
    required String filePath,
    required String ruleName,
    required int offset,
    required int length,
    required String message,
    required String? correction,
  }) {
    _pending.add(_BatchedViolation(
      filePath: filePath,
      ruleName: ruleName,
      offset: offset,
      length: length,
      message: message,
      correction: correction,
    ));

    // Auto-flush when batch is full
    if (_pending.length >= _batchSize) {
      flush();
    }
  }

  /// Flush all pending violations.
  ///
  /// Call this at the end of each file analysis or when switching files.
  static List<_BatchedViolation> flush() {
    if (_pending.isEmpty) return [];

    final batch = List<_BatchedViolation>.from(_pending);
    _pending.clear();
    return batch;
  }

  /// Get count of pending violations.
  static int get pendingCount => _pending.length;

  /// Clear all pending without reporting.
  static void clear() {
    _pending.clear();
  }
}

class _BatchedViolation {
  const _BatchedViolation({
    required this.filePath,
    required this.ruleName,
    required this.offset,
    required this.length,
    required this.message,
    required this.correction,
  });

  final String filePath;
  final String ruleName;
  final int offset;
  final int length;
  final String message;
  final String? correction;
}

// =============================================================================
// CONTENT FINGERPRINT (Performance Optimization)
// =============================================================================
//
// Creates a quick "fingerprint" of file content for fast similarity detection.
// Files with identical fingerprints are very likely to have the same violations.
// This enables caching analysis results across similar files.
// =============================================================================

/// Fast content fingerprint for quick similarity detection.
///
/// Two files with the same fingerprint are likely to have similar structure,
/// even if their content differs in details. This enables:
/// - Caching analysis results across similar files
/// - Quick "skip if similar file was clean" optimization
class ContentFingerprint {
  ContentFingerprint._();

  static final Map<String, int> _cache = {};

  /// Compute fingerprint for content.
  ///
  /// The fingerprint captures structural characteristics:
  /// - Import count
  /// - Class count
  /// - Whether it has async code
  /// - Whether it has widgets
  /// - Approximate size bucket
  static int compute(String filePath, String content) {
    return _cache.putIfAbsent(filePath, () => _computeFingerprint(content));
  }

  static int _computeFingerprint(String content) {
    final lines = content.split('\n');
    final lineCount = lines.length;

    // Count structural elements
    var importCount = 0;
    var classCount = 0;
    var hasAsync = false;
    var hasWidget = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ')) importCount++;
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ')) {
        classCount++;
      }
      if (!hasAsync && (line.contains('async') || line.contains('Future'))) {
        hasAsync = true;
      }
      if (!hasWidget && (line.contains('Widget') || line.contains('State<'))) {
        hasWidget = true;
      }
    }

    // Create fingerprint from characteristics
    // Size bucket: 0=tiny(<50), 1=small(<200), 2=medium(<500), 3=large(<1000), 4=huge
    final sizeBucket = lineCount < 50
        ? 0
        : lineCount < 200
            ? 1
            : lineCount < 500
                ? 2
                : lineCount < 1000
                    ? 3
                    : 4;

    return Object.hash(
      importCount.clamp(0, 20), // Cap at 20 imports
      classCount.clamp(0, 10), // Cap at 10 classes
      hasAsync,
      hasWidget,
      sizeBucket,
    );
  }

  /// Check if two files have the same fingerprint.
  static bool areSimilar(
    String path1,
    String content1,
    String path2,
    String content2,
  ) {
    return compute(path1, content1) == compute(path2, content2);
  }

  /// Invalidate cached fingerprint.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
  }

  /// Clear all cached fingerprints.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// RULE DEPENDENCY GRAPH (Performance Optimization)
// =============================================================================
//
// Tracks dependencies between rules. If rule A depends on rule B, and B finds
// violations, we might want to skip A (since the code needs fixing anyway).
// This enables "fail fast" optimization chains.
// =============================================================================

/// Tracks rule dependencies for fail-fast optimization.
///
/// Some rules are naturally dependent:
/// - If `avoid_mutable_global_variables` fires, skip `prefer_const` checks
/// - If `missing_dispose` fires, skip `dispose_order` checks
///
/// This allows skipping downstream rules when upstream rules find issues.
class RuleDependencyGraph {
  RuleDependencyGraph._();

  // Map of rule -> rules that depend on it
  static final Map<String, Set<String>> _dependents = {};

  // Map of rule -> rules it depends on
  static final Map<String, Set<String>> _dependencies = {};

  /// Declare that [dependent] depends on [prerequisite].
  ///
  /// If [prerequisite] finds violations, [dependent] can be skipped.
  static void addDependency(String dependent, String prerequisite) {
    _dependencies.putIfAbsent(dependent, () => {}).add(prerequisite);
    _dependents.putIfAbsent(prerequisite, () => {}).add(dependent);
  }

  /// Get rules that should be skipped if [rule] found violations.
  static Set<String> getDependents(String rule) {
    return _dependents[rule] ?? {};
  }

  /// Get prerequisites for a rule.
  static Set<String> getPrerequisites(String rule) {
    return _dependencies[rule] ?? {};
  }

  /// Check if [rule] should be skipped based on prerequisite violations.
  static bool shouldSkip(String rule, Set<String> rulesWithViolations) {
    final prereqs = _dependencies[rule];
    if (prereqs == null || prereqs.isEmpty) return false;

    // Skip if ANY prerequisite has violations
    return prereqs.any((p) => rulesWithViolations.contains(p));
  }

  /// Clear all dependencies.
  static void clear() {
    _dependents.clear();
    _dependencies.clear();
  }
}

// =============================================================================
// RULE EXECUTION STATS (Performance Optimization)
// =============================================================================
//
// Tracks historical execution statistics for rules. This data enables:
// - Dynamic priority adjustment (slow rules get deprioritized)
// - Skip analysis of rules that rarely find anything
// - Identify rules that need optimization
// =============================================================================

/// Tracks rule execution statistics over time.
///
/// Used for dynamic optimization decisions based on actual performance data.
class RuleExecutionStats {
  RuleExecutionStats._();

  static final Map<String, _RuleStats> _stats = {};

  /// Record a rule execution.
  static void record({
    required String ruleName,
    required Duration elapsed,
    required bool foundViolations,
  }) {
    final stats = _stats.putIfAbsent(ruleName, () => _RuleStats());
    stats.executionCount++;
    stats.totalTime += elapsed;
    if (foundViolations) stats.violationCount++;
  }

  /// Get average execution time for a rule.
  static Duration getAverageTime(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount == 0) {
      return Duration.zero;
    }
    return stats.totalTime ~/ stats.executionCount;
  }

  /// Get violation rate for a rule (0.0 to 1.0).
  static double getViolationRate(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount == 0) return 0.0;
    return stats.violationCount / stats.executionCount;
  }

  /// Check if a rule rarely finds violations (candidate for lazy execution).
  ///
  /// A rule with <5% hit rate over 100+ executions is rarely useful.
  static bool rarelyFindsViolations(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount < 100) return false;
    return getViolationRate(ruleName) < 0.05;
  }

  /// Check if a rule is slow (>50ms average).
  static bool isSlow(String ruleName) {
    return getAverageTime(ruleName).inMilliseconds > 50;
  }

  /// Get all slow rules for optimization review.
  static List<String> getSlowRules() {
    return _stats.entries
        .where((e) => e.value.executionCount > 10)
        .where((e) =>
            (e.value.totalTime ~/ e.value.executionCount).inMilliseconds > 50)
        .map((e) => e.key)
        .toList();
  }

  /// Clear all stats.
  static void clearStats() {
    _stats.clear();
  }
}

class _RuleStats {
  int executionCount = 0;
  int violationCount = 0;
  Duration totalTime = Duration.zero;
}

// =============================================================================
// LAZY PATTERN COMPILER (Performance Optimization)
// =============================================================================
//
// Compiles regex patterns lazily on first use. Many rules have patterns that
// are never actually needed (if early filtering skips the rule). This avoids
// paying the regex compilation cost upfront.
// =============================================================================

/// Lazily compiled regex patterns.
///
/// Regex compilation is expensive. This class defers compilation until
/// the pattern is actually used, avoiding unnecessary work for rules
/// that get skipped by early filtering.
class LazyPattern {
  LazyPattern(this._pattern);

  final String _pattern;
  RegExp? _compiled;

  /// Get the compiled regex (compiles on first access).
  RegExp get regex => _compiled ??= RegExp(_pattern);

  /// Check if pattern matches (compiles lazily).
  bool hasMatch(String input) => regex.hasMatch(input);

  /// Find all matches (compiles lazily).
  Iterable<RegExpMatch> allMatches(String input) => regex.allMatches(input);

  /// Check if already compiled.
  bool get isCompiled => _compiled != null;
}

/// Cache of lazily compiled patterns.
class LazyPatternCache {
  LazyPatternCache._();

  static final Map<String, LazyPattern> _cache = {};

  /// Get a lazily compiled pattern.
  static LazyPattern get(String pattern) {
    return _cache.putIfAbsent(pattern, () => LazyPattern(pattern));
  }

  /// Pre-compile patterns that are known to be frequently used.
  static void precompile(Iterable<String> patterns) {
    for (final pattern in patterns) {
      get(pattern).regex; // Force compilation
    }
  }

  /// Get count of compiled patterns.
  static int get compiledCount =>
      _cache.values.where((p) => p.isCompiled).length;

  /// Clear the cache.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// PARALLEL ANALYSIS (Performance Optimization)
// =============================================================================
//
// Provides parallel pre-analysis capabilities using Dart isolates. Since the
// custom_lint framework controls rule execution order, we can't parallelize
// rule execution directly. Instead, we parallelize:
//
// 1. **File scanning**: Pre-scan files in parallel to populate caches
// 2. **Pattern matching**: Check required patterns across files in parallel
// 3. **Metrics computation**: Compute file metrics in parallel
// 4. **Content fingerprinting**: Generate fingerprints in parallel
//
// This warms the caches BEFORE rules execute, so when the framework calls
// each rule, the expensive work is already done.
// =============================================================================

/// Result of analyzing a file in parallel.
class ParallelAnalysisResult {
  const ParallelAnalysisResult({
    required this.filePath,
    required this.contentHash,
    required this.metrics,
    required this.fingerprint,
    required this.fileTypes,
    required this.matchingPatterns,
  });

  final String filePath;
  final int contentHash;
  final FileMetrics metrics;
  final int fingerprint;
  final Set<FileType> fileTypes;
  final Set<String> matchingPatterns;

  /// Create from a map (for isolate communication).
  factory ParallelAnalysisResult.fromMap(Map<String, dynamic> map) {
    return ParallelAnalysisResult(
      filePath: map['filePath'] as String,
      contentHash: map['contentHash'] as int,
      metrics: FileMetrics(
        lineCount: map['lineCount'] as int,
        characterCount: map['characterCount'] as int,
        importCount: map['importCount'] as int,
        classCount: map['classCount'] as int,
        functionCount: map['functionCount'] as int,
        hasAsyncCode: map['hasAsyncCode'] as bool,
        hasWidgets: map['hasWidgets'] as bool,
        hasFlutterImport: map['hasFlutterImport'] as bool? ?? false,
        hasBlocImport: map['hasBlocImport'] as bool? ?? false,
        hasProviderImport: map['hasProviderImport'] as bool? ?? false,
        hasRiverpodImport: map['hasRiverpodImport'] as bool? ?? false,
      ),
      fingerprint: map['fingerprint'] as int,
      fileTypes: (map['fileTypes'] as List<dynamic>)
          .map((e) => FileType.values[e as int])
          .toSet(),
      matchingPatterns:
          (map['matchingPatterns'] as List<dynamic>).cast<String>().toSet(),
    );
  }

  /// Convert to map for isolate communication.
  Map<String, dynamic> toMap() {
    return {
      'filePath': filePath,
      'contentHash': contentHash,
      'lineCount': metrics.lineCount,
      'characterCount': metrics.characterCount,
      'importCount': metrics.importCount,
      'classCount': metrics.classCount,
      'functionCount': metrics.functionCount,
      'hasAsyncCode': metrics.hasAsyncCode,
      'hasWidgets': metrics.hasWidgets,
      'hasFlutterImport': metrics.hasFlutterImport,
      'hasBlocImport': metrics.hasBlocImport,
      'hasProviderImport': metrics.hasProviderImport,
      'hasRiverpodImport': metrics.hasRiverpodImport,
      'fingerprint': fingerprint,
      'fileTypes': fileTypes.map((t) => t.index).toList(),
      'matchingPatterns': matchingPatterns.toList(),
    };
  }
}

/// Manages parallel pre-analysis of files using isolates.
///
/// Usage:
/// ```dart
/// // Initialize the pool (once at startup)
/// await ParallelAnalyzer.initialize();
///
/// // Pre-analyze files in parallel
/// final results = await ParallelAnalyzer.analyzeFiles(
///   files: filePaths,
///   patterns: allRequiredPatterns,
/// );
///
/// // Results are automatically cached for rule execution
/// ```
class ParallelAnalyzer {
  ParallelAnalyzer._();

  // Number of worker isolates (based on CPU cores)
  static int _workerCount = 0;
  static bool _initialized = false;
  static bool _useIsolates = true;

  // Cache of pre-computed results (shared across isolates via main isolate)
  static final Map<String, ParallelAnalysisResult> _resultCache = {};

  // Statistics
  static int _isolateTasksRun = 0;
  static int _syncTasksRun = 0;

  /// Initialize the parallel analyzer.
  ///
  /// Call this once at startup. Creates worker isolates based on CPU cores.
  /// If isolates aren't available (e.g., web), falls back to sync processing.
  static Future<void> initialize({
    int? workerCount,
    bool useIsolates = true,
  }) async {
    if (_initialized) return;

    // Determine worker count (default: CPU cores - 1, min 1, max 8)
    _workerCount = workerCount ?? _getDefaultWorkerCount();
    _useIsolates = useIsolates;
    _initialized = true;
  }

  static int _getDefaultWorkerCount() {
    // Platform.numberOfProcessors isn't available in all environments
    // Use a conservative default of 4 workers
    return 4;
  }

  /// Pre-analyze files in parallel using real isolates.
  ///
  /// Returns analysis results for each file. Results are cached automatically.
  /// Uses Isolate.run() for true parallel execution when available.
  static Future<List<ParallelAnalysisResult>> analyzeFiles({
    required List<String> filePaths,
    required Set<String> patterns,
  }) async {
    if (!_initialized || _workerCount <= 1) {
      // Fallback to synchronous processing
      return _analyzeFilesSync(filePaths, patterns);
    }

    // Check cache first
    final uncached = <String>[];
    final results = <ParallelAnalysisResult>[];

    for (final path in filePaths) {
      final cached = _resultCache[path];
      if (cached != null) {
        results.add(cached);
      } else {
        uncached.add(path);
      }
    }

    if (uncached.isEmpty) return results;

    // Process uncached files in parallel batches
    final batchSize = (uncached.length / _workerCount).ceil().clamp(1, 50);
    final batches = <List<String>>[];

    for (var i = 0; i < uncached.length; i += batchSize) {
      batches.add(uncached.sublist(
        i,
        (i + batchSize).clamp(0, uncached.length),
      ));
    }

    if (_useIsolates && batches.length > 1) {
      // Process batches in parallel using isolates
      final futures = batches.map((batch) => _processBatchInIsolate(
            batch,
            patterns.toList(),
          ));
      final batchResults = await Future.wait(futures);
      for (final batchResult in batchResults) {
        results.addAll(batchResult);
      }
    } else {
      // Sequential processing with async gaps
      for (final batch in batches) {
        final batchResults = await _processBatch(batch, patterns);
        results.addAll(batchResults);
      }
    }

    return results;
  }

  /// Process a batch of files in an isolate for true parallelism.
  static Future<List<ParallelAnalysisResult>> _processBatchInIsolate(
    List<String> filePaths,
    List<String> patterns,
  ) async {
    try {
      _isolateTasksRun++;

      // Use Isolate.run for true parallel execution
      // The computation runs in a separate isolate and returns when complete
      final results = await Isolate.run(() {
        return _analyzeFilesInIsolate(filePaths, patterns.toSet());
      });

      // Cache results and apply to main caches
      for (final result in results) {
        _resultCache[result.filePath] = result;
        _applyCacheResult(result);
      }

      return results;
    } catch (e) {
      // Isolate failed - fall back to sync processing
      _syncTasksRun++;
      return _processBatch(filePaths, patterns.toSet());
    }
  }

  /// Analyze files within an isolate (no shared state access).
  ///
  /// This function runs in a separate isolate, so it cannot access
  /// any static state from the main isolate. All data must be passed in.
  static List<ParallelAnalysisResult> _analyzeFilesInIsolate(
    List<String> filePaths,
    Set<String> patterns,
  ) {
    final results = <ParallelAnalysisResult>[];

    for (final path in filePaths) {
      try {
        final file = File(path);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();
        final result = analyzeFileContent(path, content, patterns);
        results.add(result);
      } catch (_) {
        // Skip files that can't be read
      }
    }

    return results;
  }

  /// Process a batch of files (async to allow other work to proceed).
  static Future<List<ParallelAnalysisResult>> _processBatch(
    List<String> filePaths,
    Set<String> patterns,
  ) async {
    _syncTasksRun++;
    final results = <ParallelAnalysisResult>[];

    for (final path in filePaths) {
      // Allow other async work between files
      await Future<void>.delayed(Duration.zero);

      try {
        final file = File(path);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();
        final result = analyzeFileContent(path, content, patterns);

        _resultCache[path] = result;
        _applyCacheResult(result);

        results.add(result);
      } catch (_) {
        // Skip files that can't be read
      }
    }

    return results;
  }

  /// Synchronous fallback for environments without isolate support.
  static List<ParallelAnalysisResult> _analyzeFilesSync(
    List<String> filePaths,
    Set<String> patterns,
  ) {
    final results = <ParallelAnalysisResult>[];

    for (final path in filePaths) {
      final cached = _resultCache[path];
      if (cached != null) {
        results.add(cached);
        continue;
      }

      try {
        final file = File(path);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();
        final result = analyzeFileContent(path, content, patterns);

        _resultCache[path] = result;
        _applyCacheResult(result);

        results.add(result);
      } catch (_) {
        // Skip files that can't be read
      }
    }

    return results;
  }

  /// Analyze a single file's content.
  ///
  /// This is the core analysis function that can run in any isolate.
  static ParallelAnalysisResult analyzeFileContent(
    String filePath,
    String content,
    Set<String> patterns,
  ) {
    // Compute content hash
    final contentHash = content.hashCode;

    // Compute metrics
    final metrics = _computeMetrics(content);

    // Compute fingerprint
    final fingerprint = _computeFingerprint(content, metrics);

    // Detect file types
    final fileTypes = _detectFileTypes(filePath, content);

    // Find matching patterns
    final matchingPatterns = <String>{};
    for (final pattern in patterns) {
      if (content.contains(pattern)) {
        matchingPatterns.add(pattern);
      }
    }

    return ParallelAnalysisResult(
      filePath: filePath,
      contentHash: contentHash,
      metrics: metrics,
      fingerprint: fingerprint,
      fileTypes: fileTypes,
      matchingPatterns: matchingPatterns,
    );
  }

  /// Compute file metrics (same logic as FileMetricsCache).
  static FileMetrics _computeMetrics(String content) {
    var lineCount = 1;
    var importCount = 0;
    var classCount = 0;
    var functionCount = 0;

    final lines = content.split('\n');
    lineCount = lines.length;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ')) importCount++;
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ')) {
        classCount++;
      }
      if (trimmed.contains(' Function') ||
          RegExp(r'^\s*\w+\s+\w+\s*\(').hasMatch(line)) {
        functionCount++;
      }
    }

    // Package import detection
    final hasFlutterImport = content.contains('package:flutter/');
    final hasBlocImport = content.contains('package:bloc/') ||
        content.contains('package:flutter_bloc/');
    final hasProviderImport = content.contains('package:provider/');
    final hasRiverpodImport = content.contains('package:riverpod/') ||
        content.contains('package:flutter_riverpod/') ||
        content.contains('package:hooks_riverpod/');

    return FileMetrics(
      lineCount: lineCount,
      characterCount: content.length,
      importCount: importCount,
      classCount: classCount,
      functionCount: functionCount,
      hasAsyncCode: content.contains('async') || content.contains('Future'),
      hasWidgets: content.contains('Widget') || content.contains('State<'),
      hasFlutterImport: hasFlutterImport,
      hasBlocImport: hasBlocImport,
      hasProviderImport: hasProviderImport,
      hasRiverpodImport: hasRiverpodImport,
    );
  }

  /// Compute content fingerprint.
  static int _computeFingerprint(String content, FileMetrics metrics) {
    final sizeBucket = metrics.lineCount < 50
        ? 0
        : metrics.lineCount < 200
            ? 1
            : metrics.lineCount < 500
                ? 2
                : metrics.lineCount < 1000
                    ? 3
                    : 4;

    return Object.hash(
      metrics.importCount.clamp(0, 20),
      metrics.classCount.clamp(0, 10),
      metrics.hasAsyncCode,
      metrics.hasWidgets,
      sizeBucket,
    );
  }

  /// Detect file types.
  static Set<FileType> _detectFileTypes(String filePath, String content) {
    final types = <FileType>{};
    final normalizedPath = normalizePath(filePath);

    // Path-based detection
    if (normalizedPath.endsWith('_test.dart') ||
        normalizedPath.contains('/test/') ||
        normalizedPath.contains('/integration_test/')) {
      types.add(FileType.test);
    }

    // Content-based detection
    if (content.contains('extends StatelessWidget') ||
        content.contains('extends StatefulWidget') ||
        content.contains('extends State<')) {
      types.add(FileType.widget);
    }

    if (content.contains('extends Bloc<') ||
        content.contains('extends Cubit<')) {
      types.add(FileType.bloc);
    }

    if (content.contains('@riverpod') ||
        content.contains('ConsumerWidget') ||
        content.contains('ConsumerStatefulWidget') ||
        content.contains('ProviderScope') ||
        content.contains('ref.watch(') ||
        content.contains('ref.read(') ||
        content.contains('ChangeNotifierProvider') ||
        content.contains('StateNotifierProvider')) {
      types.add(FileType.provider);
    }

    if (types.isEmpty) {
      types.add(FileType.general);
    }

    return types;
  }

  /// Apply a pre-computed result to the main caches.
  ///
  /// This populates FileMetricsCache, FileTypeDetector, etc. so rules
  /// can use the pre-computed values without re-analyzing.
  static void _applyCacheResult(ParallelAnalysisResult result) {
    // These calls will use putIfAbsent, so they won't overwrite
    // if somehow the cache was already populated
    FileMetricsCache._cache.putIfAbsent(result.filePath, () => result.metrics);
    FileTypeDetector._cache
        .putIfAbsent(result.filePath, () => result.fileTypes);
    ContentFingerprint._cache
        .putIfAbsent(result.filePath, () => result.fingerprint);
  }

  /// Get cached result for a file (if available).
  static ParallelAnalysisResult? getCachedResult(String filePath) {
    return _resultCache[filePath];
  }

  /// Check if a file has been pre-analyzed.
  static bool hasPreAnalyzed(String filePath) {
    return _resultCache.containsKey(filePath);
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _resultCache.remove(filePath);
  }

  /// Clear all cached results.
  static void clearCache() {
    _resultCache.clear();
  }

  /// Get statistics about parallel analysis.
  static Map<String, dynamic> getStats() {
    return {
      'initialized': _initialized,
      'workerCount': _workerCount,
      'useIsolates': _useIsolates,
      'cachedFiles': _resultCache.length,
      'isolateTasksRun': _isolateTasksRun,
      'syncTasksRun': _syncTasksRun,
    };
  }
}

// =============================================================================
// RULE BATCH EXECUTOR (Performance Optimization)
// =============================================================================
//
// Provides a framework for batch-executing independent rules in parallel.
// While the custom_lint framework controls actual rule invocation, this
// allows pre-computation and result caching for rules that can be batched.
// =============================================================================

/// Information about a rule for batch execution planning.
class BatchableRuleInfo {
  const BatchableRuleInfo({
    required this.name,
    required this.cost,
    required this.requiredPatterns,
    required this.applicableFileTypes,
    required this.requiresAsync,
    required this.requiresWidgets,
    this.dependencies = const {},
  });

  final String name;
  final RuleCost cost;
  final Set<String>? requiredPatterns;
  final Set<FileType>? applicableFileTypes;
  final bool requiresAsync;
  final bool requiresWidgets;
  final Set<String> dependencies;

  /// Check if this rule should run on a file based on pre-analysis.
  bool shouldRunOn(ParallelAnalysisResult analysis) {
    // Check file type filter
    if (applicableFileTypes != null && applicableFileTypes!.isNotEmpty) {
      if (!applicableFileTypes!.any((t) => analysis.fileTypes.contains(t))) {
        return false;
      }
    }

    // Check async requirement
    if (requiresAsync && !analysis.metrics.hasAsyncCode) {
      return false;
    }

    // Check widget requirement
    if (requiresWidgets && !analysis.metrics.hasWidgets) {
      return false;
    }

    // Check required patterns
    if (requiredPatterns != null && requiredPatterns!.isNotEmpty) {
      if (!requiredPatterns!
          .any((p) => analysis.matchingPatterns.contains(p))) {
        return false;
      }
    }

    return true;
  }
}

/// Plans and tracks batch rule execution.
class RuleBatchExecutor {
  RuleBatchExecutor._();

  // Track which rules should run on which files
  static final Map<String, Set<String>> _fileToApplicableRules = {};

  /// Plan rule execution for analyzed files.
  ///
  /// Returns a map of file path -> set of rule names that should run.
  /// Rules that definitely won't find anything are excluded.
  static Map<String, Set<String>> planExecution({
    required List<ParallelAnalysisResult> analyses,
    required List<BatchableRuleInfo> rules,
  }) {
    _fileToApplicableRules.clear();

    for (final analysis in analyses) {
      final applicableRules = <String>{};

      for (final rule in rules) {
        if (rule.shouldRunOn(analysis)) {
          applicableRules.add(rule.name);
        }
      }

      // Normalize path separators for cross-platform consistency
      final normalizedPath = normalizePath(analysis.filePath);
      _fileToApplicableRules[normalizedPath] = applicableRules;
    }

    return Map.unmodifiable(_fileToApplicableRules);
  }

  /// Check if a rule should run on a specific file.
  ///
  /// Uses pre-computed plan from [planExecution].
  static bool shouldRuleRunOnFile(String ruleName, String filePath) {
    final normalizedPath = normalizePath(filePath);
    final rules = _fileToApplicableRules[normalizedPath];
    if (rules == null) return true; // No plan = run all rules
    return rules.contains(ruleName);
  }

  /// Get rules that should run on a file.
  static Set<String> getApplicableRules(String filePath) {
    final normalizedPath = normalizePath(filePath);
    return _fileToApplicableRules[normalizedPath] ?? {};
  }

  /// Get files that a rule should run on.
  static List<String> getApplicableFiles(String ruleName) {
    return _fileToApplicableRules.entries
        .where((e) => e.value.contains(ruleName))
        .map((e) => e.key)
        .toList();
  }

  /// Get statistics about the execution plan.
  static Map<String, dynamic> getStats() {
    var totalPairs = 0;
    for (final rules in _fileToApplicableRules.values) {
      totalPairs += rules.length;
    }

    return {
      'files': _fileToApplicableRules.length,
      'totalRuleFilePairs': totalPairs,
      'avgRulesPerFile': _fileToApplicableRules.isEmpty
          ? 0
          : totalPairs / _fileToApplicableRules.length,
    };
  }

  /// Clear execution plan.
  static void clear() {
    _fileToApplicableRules.clear();
  }
}

// =============================================================================
// CONSOLIDATED VISITOR DISPATCH (Performance Optimization #3)
// =============================================================================
//
// Instead of each rule registering its own visitor callbacks (causing multiple
// AST traversals), we create a dispatch system where:
// 1. Rules register which AST node types they care about
// 2. A single traversal visits each node once
// 3. The dispatcher invokes all interested rules for each node
//
// This reduces O(rules × nodes) to O(nodes) for traversal overhead.
// =============================================================================

/// Callback type for consolidated node visitors.
typedef NodeVisitCallback = void Function(dynamic node, String filePath);

/// Manages consolidated AST visitor dispatch.
///
/// Usage:
/// ```dart
/// // Register rules at startup
/// ConsolidatedVisitorDispatch.register(
///   ruleName: 'avoid_print',
///   nodeTypes: {AstNodeCategory.invocations},
///   callback: (node, path) => checkPrint(node),
/// );
///
/// // During analysis, dispatch to all rules
/// ConsolidatedVisitorDispatch.dispatch(
///   category: AstNodeCategory.invocations,
///   node: methodInvocation,
///   filePath: currentFile,
/// );
/// ```
class ConsolidatedVisitorDispatch {
  ConsolidatedVisitorDispatch._();

  // Map of node category -> list of (ruleName, callback)
  static final Map<AstNodeCategory, List<_RegisteredCallback>> _callbacks = {};

  // Track which rules are registered
  static final Set<String> _registeredRules = {};

  /// Register a rule's callback for specific node types.
  static void register({
    required String ruleName,
    required Set<AstNodeCategory> nodeTypes,
    required NodeVisitCallback callback,
  }) {
    if (_registeredRules.contains(ruleName)) return; // Already registered
    _registeredRules.add(ruleName);

    for (final category in nodeTypes) {
      _callbacks.putIfAbsent(category, () => []).add(
            _RegisteredCallback(ruleName: ruleName, callback: callback),
          );
    }
  }

  /// Dispatch a node to all interested rules.
  ///
  /// Returns the number of callbacks invoked.
  static int dispatch({
    required AstNodeCategory category,
    required dynamic node,
    required String filePath,
  }) {
    final callbacks = _callbacks[category];
    if (callbacks == null || callbacks.isEmpty) return 0;

    var count = 0;
    for (final cb in callbacks) {
      // Check if rule should run on this file (via batch executor)
      if (RuleBatchExecutor.shouldRuleRunOnFile(cb.ruleName, filePath)) {
        cb.callback(node, filePath);
        count++;
      }
    }
    return count;
  }

  /// Check if any rules are registered for a category.
  static bool hasCallbacksFor(AstNodeCategory category) {
    final callbacks = _callbacks[category];
    return callbacks != null && callbacks.isNotEmpty;
  }

  /// Get count of registered rules.
  static int get registeredRuleCount => _registeredRules.length;

  /// Get count of callbacks per category.
  static Map<AstNodeCategory, int> get callbackCounts {
    return {
      for (final entry in _callbacks.entries) entry.key: entry.value.length,
    };
  }

  /// Clear all registrations.
  static void clear() {
    _callbacks.clear();
    _registeredRules.clear();
  }
}

class _RegisteredCallback {
  const _RegisteredCallback({
    required this.ruleName,
    required this.callback,
  });

  final String ruleName;
  final NodeVisitCallback callback;
}

// =============================================================================
// BASELINE-AWARE EARLY EXIT (Performance Optimization #4)
// =============================================================================
//
// If ALL potential violations in a file are already baselined (suppressed),
// we can skip running the rule entirely. This requires:
// 1. Pre-computing which rules have baselined violations per file
// 2. Checking if a rule's violations would all be suppressed
// =============================================================================

/// Tracks baselined violations for early exit optimization.
///
/// If all of a rule's potential violations in a file are baselined,
/// we can skip running the rule entirely.
class BaselineAwareEarlyExit {
  BaselineAwareEarlyExit._();

  // Map of file path -> set of rules with ALL violations baselined
  static final Map<String, Set<String>> _fullyBaselinedRules = {};

  // Map of file path -> map of rule name -> count of baselined violations
  static final Map<String, Map<String, int>> _baselinedViolationCounts = {};

  /// Record that a violation is baselined.
  static void recordBaselinedViolation(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _baselinedViolationCounts
        .putIfAbsent(normalizedPath, () => {})
        .update(ruleName, (c) => c + 1, ifAbsent: () => 1);
  }

  /// Mark a rule as fully baselined for a file.
  ///
  /// Call this when you determine that ALL violations of a rule in a file
  /// are covered by baseline (e.g., path-based baseline covers entire file).
  static void markFullyBaselined(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _fullyBaselinedRules.putIfAbsent(normalizedPath, () => {}).add(ruleName);
  }

  /// Check if a rule can be skipped for a file due to baseline.
  ///
  /// Returns true if the rule is fully baselined for this file.
  static bool canSkipRule(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _fullyBaselinedRules[normalizedPath]?.contains(ruleName) ?? false;
  }

  /// Get count of baselined violations for a rule in a file.
  static int getBaselinedCount(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _baselinedViolationCounts[normalizedPath]?[ruleName] ?? 0;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _fullyBaselinedRules.remove(normalizedPath);
    _baselinedViolationCounts.remove(normalizedPath);
  }

  /// Clear all cached data.
  static void clearCache() {
    _fullyBaselinedRules.clear();
    _baselinedViolationCounts.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalBaselined = 0;
    for (final counts in _baselinedViolationCounts.values) {
      for (final count in counts.values) {
        totalBaselined += count;
      }
    }

    return {
      'filesWithBaselinedRules': _fullyBaselinedRules.length,
      'totalBaselinedViolations': totalBaselined,
    };
  }
}

// =============================================================================
// DIFF-BASED ANALYSIS (Performance Optimization #5)
// =============================================================================
//
// Only re-analyze changed regions of a file. If only lines 50-60 changed,
// rules that don't touch those lines can be skipped. This requires:
// 1. Tracking which lines changed between analysis runs
// 2. Mapping AST nodes to line ranges
// 3. Skipping rules whose scope doesn't overlap with changes
// =============================================================================

/// Represents a range of lines in a file.
class LineRange {
  const LineRange(this.start, this.end);

  final int start;
  final int end;

  /// Check if this range overlaps with another.
  bool overlaps(LineRange other) {
    return start <= other.end && end >= other.start;
  }

  /// Check if this range contains a specific line.
  bool containsLine(int line) {
    return line >= start && line <= end;
  }

  /// Merge with another range (returns union).
  LineRange merge(LineRange other) {
    return LineRange(
      start < other.start ? start : other.start,
      end > other.end ? end : other.end,
    );
  }

  @override
  String toString() => '$start-$end';
}

/// Tracks changed regions for diff-based analysis.
///
/// Usage:
/// ```dart
/// // Record changes when file is modified
/// DiffBasedAnalysis.recordChanges(filePath, [LineRange(50, 60)]);
///
/// // Check if a rule needs to run based on its scope
/// if (!DiffBasedAnalysis.needsAnalysis(filePath, ruleScope)) {
///   return; // Skip - changes don't affect this rule's scope
/// }
/// ```
class DiffBasedAnalysis {
  DiffBasedAnalysis._();

  // Map of file path -> list of changed line ranges
  static final Map<String, List<LineRange>> _changedRegions = {};

  // Map of file path -> previous content (for diff computation)
  static final Map<String, String> _previousContent = {};

  /// Record changed regions in a file.
  static void recordChanges(String filePath, List<LineRange> changes) {
    if (changes.isEmpty) {
      _changedRegions.remove(filePath);
    } else {
      _changedRegions[filePath] = _mergeOverlapping(changes);
    }
  }

  /// Compute changes between previous and current content.
  ///
  /// Returns list of changed line ranges. Updates internal cache.
  static List<LineRange> computeChanges(
      String filePath, String currentContent) {
    final previous = _previousContent[filePath];
    _previousContent[filePath] = currentContent;

    if (previous == null) {
      // First time seeing this file - consider all lines changed
      final lineCount = '\n'.allMatches(currentContent).length + 1;
      final changes = [LineRange(1, lineCount)];
      _changedRegions[filePath] = changes;
      return changes;
    }

    if (previous == currentContent) {
      // No changes
      _changedRegions.remove(filePath);
      return [];
    }

    // Compute diff (simple line-by-line comparison)
    final changes = _computeLineDiff(previous, currentContent);
    if (changes.isNotEmpty) {
      _changedRegions[filePath] = changes;
    } else {
      _changedRegions.remove(filePath);
    }
    return changes;
  }

  /// Check if a rule needs to run based on its scope.
  ///
  /// [ruleScope] is the line range that the rule checks.
  /// Returns true if the rule's scope overlaps with any changed region.
  static bool needsAnalysis(String filePath, LineRange ruleScope) {
    final changes = _changedRegions[filePath];
    if (changes == null || changes.isEmpty) {
      return false; // No changes recorded
    }

    return changes.any((change) => change.overlaps(ruleScope));
  }

  /// Check if any part of the file changed.
  static bool hasChanges(String filePath) {
    final changes = _changedRegions[filePath];
    return changes != null && changes.isNotEmpty;
  }

  /// Get changed regions for a file.
  static List<LineRange> getChangedRegions(String filePath) {
    return _changedRegions[filePath] ?? [];
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _changedRegions.remove(filePath);
    _previousContent.remove(filePath);
  }

  /// Clear all cached data.
  static void clearCache() {
    _changedRegions.clear();
    _previousContent.clear();
  }

  /// Merge overlapping ranges into consolidated ranges.
  static List<LineRange> _mergeOverlapping(List<LineRange> ranges) {
    if (ranges.isEmpty) return [];
    if (ranges.length == 1) return ranges;

    // Sort by start line
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));

    final merged = <LineRange>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.last;

      if (current.start <= last.end + 1) {
        // Overlapping or adjacent - merge
        merged[merged.length - 1] = last.merge(current);
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  /// Simple line-by-line diff computation.
  static List<LineRange> _computeLineDiff(String previous, String current) {
    final prevLines = previous.split('\n');
    final currLines = current.split('\n');
    final changes = <LineRange>[];

    var changeStart = -1;
    final maxLines = prevLines.length > currLines.length
        ? prevLines.length
        : currLines.length;

    for (var i = 0; i < maxLines; i++) {
      final prevLine = i < prevLines.length ? prevLines[i] : null;
      final currLine = i < currLines.length ? currLines[i] : null;

      final isDifferent = prevLine != currLine;

      if (isDifferent && changeStart < 0) {
        changeStart = i + 1; // Lines are 1-indexed
      } else if (!isDifferent && changeStart >= 0) {
        changes.add(LineRange(changeStart, i)); // End at previous line
        changeStart = -1;
      }
    }

    // Handle trailing change
    if (changeStart >= 0) {
      changes.add(LineRange(changeStart, maxLines));
    }

    return _mergeOverlapping(changes);
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalChangedLines = 0;
    for (final ranges in _changedRegions.values) {
      for (final range in ranges) {
        totalChangedLines += range.end - range.start + 1;
      }
    }

    return {
      'filesWithChanges': _changedRegions.length,
      'totalChangedLines': totalChangedLines,
      'cachedFiles': _previousContent.length,
    };
  }
}

// =============================================================================
// IMPORT GRAPH CACHE (Performance Optimization #9)
// =============================================================================
//
// Caches the import graph for a project to avoid re-parsing imports for each
// file. This is especially valuable for rules that need to check transitive
// dependencies or detect circular imports.
// =============================================================================

/// Represents import relationships in a project.
class ImportNode {
  ImportNode(this.filePath);

  final String filePath;
  final Set<String> imports = {};
  final Set<String> exports = {};
  final Set<String> importedBy = {}; // Reverse graph

  /// Check if this file transitively imports another.
  bool transitivelyImports(String target) {
    final visited = <String>{};
    return _transitivelyImportsHelper(target, visited);
  }

  bool _transitivelyImportsHelper(
    String target,
    Set<String> visited,
  ) {
    if (visited.contains(filePath)) return false;
    visited.add(filePath);

    if (imports.contains(target)) return true;

    for (final imp in imports) {
      final node = ImportGraphCache.getNode(imp);
      if (node != null && node._transitivelyImportsHelper(target, visited)) {
        return true;
      }
    }
    return false;
  }
}

/// Caches import graph for efficient dependency queries.
///
/// Usage:
/// ```dart
/// // Build graph from project files
/// ImportGraphCache.buildFromDirectory(projectRoot);
///
/// // Query dependencies
/// final node = ImportGraphCache.getNode(filePath);
/// if (node?.imports.contains('package:flutter/material.dart')) {
///   // File imports Flutter
/// }
///
/// // Check transitive dependencies
/// if (ImportGraphCache.hasTransitiveImport(fileA, fileB)) {
///   // fileA transitively imports fileB
/// }
/// ```
class ImportGraphCache {
  ImportGraphCache._();

  // Map of file path -> import node
  static final Map<String, ImportNode> _graph = {};

  // Track if graph is built
  static bool _isBuilt = false;
  static String? _projectRoot;

  /// Build import graph from a project directory.
  static Future<void> buildFromDirectory(String projectRoot) async {
    if (_isBuilt && _projectRoot == projectRoot) return;

    _graph.clear();
    _projectRoot = projectRoot;

    // Find all Dart files
    final libDir = Directory('$projectRoot/lib');
    if (!libDir.existsSync()) {
      _isBuilt = true;
      return;
    }

    await _scanDirectory(libDir);
    _buildReverseGraph();
    _isBuilt = true;
  }

  /// Scan a directory for Dart files and parse their imports.
  static Future<void> _scanDirectory(Directory dir) async {
    try {
      final entities = dir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          await _parseImports(entity.path);
        }
      }
    } catch (_) {
      // Ignore errors during scanning
    }
  }

  /// Parse imports from a single file.
  static Future<void> _parseImports(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final node = ImportNode(filePath);

      // Parse imports and exports with simple regex
      final importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');
      final exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');

      for (final match in importPattern.allMatches(content)) {
        final import = match.group(1);
        if (import != null) {
          node.imports.add(_resolveImport(import, filePath));
        }
      }

      for (final match in exportPattern.allMatches(content)) {
        final export = match.group(1);
        if (export != null) {
          node.exports.add(_resolveImport(export, filePath));
        }
      }

      _graph[filePath] = node;
    } catch (_) {
      // Ignore parse errors
    }
  }

  /// Resolve a relative import to absolute path.
  static String _resolveImport(String import, String fromFile) {
    // Package imports stay as-is
    if (import.startsWith('package:') || import.startsWith('dart:')) {
      return import;
    }

    // Resolve relative imports
    final fromDir = File(fromFile).parent.path;
    final resolved = '$fromDir/$import'.replaceAll('\\', '/');

    // Normalize path (remove . and ..)
    final parts = resolved.split('/');
    final normalized = <String>[];
    for (final part in parts) {
      if (part == '..') {
        if (normalized.isNotEmpty) normalized.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        normalized.add(part);
      }
    }
    return normalized.join('/');
  }

  /// Build reverse graph (importedBy relationships).
  static void _buildReverseGraph() {
    for (final node in _graph.values) {
      for (final imp in node.imports) {
        final target = _graph[imp];
        if (target != null) {
          target.importedBy.add(node.filePath);
        }
      }
    }
  }

  /// Get import node for a file.
  static ImportNode? getNode(String filePath) {
    return _graph[filePath];
  }

  /// Check if fileA transitively imports fileB.
  static bool hasTransitiveImport(String fileA, String fileB) {
    final node = _graph[fileA];
    if (node == null) return false;
    return node.transitivelyImports(fileB);
  }

  /// Get all files that import a specific file.
  static Set<String> getImporters(String filePath) {
    return _graph[filePath]?.importedBy ?? {};
  }

  /// Get all files that a specific file imports.
  static Set<String> getImports(String filePath) {
    return _graph[filePath]?.imports ?? {};
  }

  /// Check if the graph contains a specific file.
  static bool hasFile(String filePath) {
    return _graph.containsKey(filePath);
  }

  /// Detect circular imports involving a file.
  static List<List<String>> detectCircularImports(String filePath) {
    final cycles = <List<String>>[];
    final node = _graph[filePath];
    if (node == null) return cycles;

    final path = <String>[filePath];
    final visited = <String>{filePath};

    _detectCycles(node, path, visited, cycles);
    return cycles;
  }

  static void _detectCycles(
    ImportNode node,
    List<String> path,
    Set<String> visited,
    List<List<String>> cycles,
  ) {
    for (final imp in node.imports) {
      if (imp == path.first) {
        // Found a cycle back to start
        cycles.add([...path, imp]);
        continue;
      }

      if (visited.contains(imp)) continue;

      final nextNode = _graph[imp];
      if (nextNode != null) {
        visited.add(imp);
        path.add(imp);
        _detectCycles(nextNode, path, visited, cycles);
        path.removeLast();
      }
    }
  }

  /// Invalidate cache for a file (e.g., when file changes).
  static void invalidate(String filePath) {
    final node = _graph.remove(filePath);
    if (node != null) {
      // Remove from reverse graph
      for (final imp in node.imports) {
        _graph[imp]?.importedBy.remove(filePath);
      }
    }
  }

  /// Clear entire cache.
  static void clearCache() {
    _graph.clear();
    _isBuilt = false;
    _projectRoot = null;
  }

  /// Get statistics about the import graph.
  static Map<String, dynamic> getStats() {
    var totalImports = 0;
    var maxImports = 0;
    String? fileWithMostImports;

    for (final entry in _graph.entries) {
      final count = entry.value.imports.length;
      totalImports += count;
      if (count > maxImports) {
        maxImports = count;
        fileWithMostImports = entry.key;
      }
    }

    return {
      'isBuilt': _isBuilt,
      'projectRoot': _projectRoot,
      'fileCount': _graph.length,
      'totalImports': totalImports,
      'avgImportsPerFile': _graph.isEmpty ? 0 : totalImports / _graph.length,
      'maxImports': maxImports,
      'fileWithMostImports': fileWithMostImports,
    };
  }
}

// =============================================================================
// SOURCE LOCATION CACHE (Performance Optimization)
// =============================================================================
//
// Caches offset-to-line/column calculations to avoid repeated computation.
// Computing line numbers from offsets requires scanning the content, which
// is O(n) per lookup. Caching makes subsequent lookups O(1).
// =============================================================================

/// Cached source location (line and column).
class SourceLocation {
  const SourceLocation(this.line, this.column);

  final int line;
  final int column;

  @override
  String toString() => '$line:$column';
}

/// Caches line/column lookups for file offsets.
///
/// Usage:
/// ```dart
/// // Get location from offset
/// final loc = SourceLocationCache.getLocation(filePath, content, offset);
/// print('Line ${loc.line}, column ${loc.column}');
///
/// // Or compute line starts once, then lookup many offsets
/// SourceLocationCache.computeLineStarts(filePath, content);
/// final loc1 = SourceLocationCache.getLocation(filePath, content, offset1);
/// final loc2 = SourceLocationCache.getLocation(filePath, content, offset2);
/// ```
class SourceLocationCache {
  SourceLocationCache._();

  // Map of file path -> list of line start offsets
  static final Map<String, List<int>> _lineStarts = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Compute and cache line starts for a file.
  static void computeLineStarts(String filePath, String content) {
    final hash = content.hashCode;
    if (_contentHashes[filePath] == hash && _lineStarts.containsKey(filePath)) {
      return; // Already computed for this content
    }

    final starts = <int>[0]; // Line 1 starts at offset 0
    for (var i = 0; i < content.length; i++) {
      if (content[i] == '\n') {
        starts.add(i + 1); // Next line starts after newline
      }
    }

    _lineStarts[filePath] = starts;
    _contentHashes[filePath] = hash;
  }

  /// Get source location for an offset.
  static SourceLocation getLocation(
      String filePath, String content, int offset) {
    // Ensure line starts are computed
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath]!;

    // Binary search for the line containing this offset
    var low = 0;
    var high = starts.length - 1;

    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (starts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    final line = low + 1; // Lines are 1-indexed
    final column = offset - starts[low] + 1; // Columns are 1-indexed

    return SourceLocation(line, column);
  }

  /// Get line number for an offset (1-indexed).
  static int getLine(String filePath, String content, int offset) {
    return getLocation(filePath, content, offset).line;
  }

  /// Get column number for an offset (1-indexed).
  static int getColumn(String filePath, String content, int offset) {
    return getLocation(filePath, content, offset).column;
  }

  /// Get offset for a line/column pair.
  static int? getOffset(String filePath, String content, int line, int column) {
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath]!;
    if (line < 1 || line > starts.length) return null;

    final lineStart = starts[line - 1];
    return lineStart + column - 1;
  }

  /// Get the line content for a specific line number.
  static String? getLineContent(String filePath, String content, int line) {
    if (!_lineStarts.containsKey(filePath) ||
        _contentHashes[filePath] != content.hashCode) {
      computeLineStarts(filePath, content);
    }

    final starts = _lineStarts[filePath]!;
    if (line < 1 || line > starts.length) return null;

    final start = starts[line - 1];
    final end = line < starts.length ? starts[line] - 1 : content.length;

    return content.substring(start, end);
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _lineStarts.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _lineStarts.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'cachedFiles': _lineStarts.length,
      'totalLines': _lineStarts.values.fold<int>(0, (sum, l) => sum + l.length),
    };
  }
}

// =============================================================================
// SEMANTIC TOKEN CACHE (Performance Optimization)
// =============================================================================
//
// Caches resolved type information and symbol metadata across rules.
// Type resolution is expensive; caching it allows multiple rules
// to share the same resolved information.
// =============================================================================

/// Cached information about a symbol (class, method, variable, etc.).
class CachedSymbolInfo {
  const CachedSymbolInfo({
    required this.name,
    required this.kind,
    this.typeName,
    this.isStatic = false,
    this.isPrivate = false,
    this.isAsync = false,
    this.returnType,
    this.parameterCount,
    this.declaringClass,
  });

  final String name;
  final SymbolKind kind;
  final String? typeName;
  final bool isStatic;
  final bool isPrivate;
  final bool isAsync;
  final String? returnType;
  final int? parameterCount;
  final String? declaringClass;
}

/// Kind of symbol.
enum SymbolKind {
  classDecl,
  methodDecl,
  functionDecl,
  variableDecl,
  fieldDecl,
  parameterDecl,
  enumDecl,
  mixinDecl,
  extensionDecl,
  typedefDecl,
  constructorDecl,
}

/// Caches semantic information about symbols in files.
///
/// Usage:
/// ```dart
/// // Cache a symbol
/// SemanticTokenCache.cacheSymbol(
///   filePath,
///   offset,
///   CachedSymbolInfo(name: 'myMethod', kind: SymbolKind.methodDecl, ...),
/// );
///
/// // Look up a symbol
/// final info = SemanticTokenCache.getSymbol(filePath, offset);
/// if (info?.kind == SymbolKind.methodDecl && info.isAsync) {
///   // Handle async method
/// }
/// ```
class SemanticTokenCache {
  SemanticTokenCache._();

  // Map of file path -> map of offset -> symbol info
  static final Map<String, Map<int, CachedSymbolInfo>> _symbols = {};

  // Map of file path -> map of name -> list of offsets (for name lookups)
  static final Map<String, Map<String, List<int>>> _nameIndex = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Cache a symbol at a specific offset.
  static void cacheSymbol(String filePath, int offset, CachedSymbolInfo info) {
    _symbols.putIfAbsent(filePath, () => {})[offset] = info;

    // Also index by name for fast lookups
    _nameIndex
        .putIfAbsent(filePath, () => {})
        .putIfAbsent(info.name, () => [])
        .add(offset);
  }

  /// Get symbol info at a specific offset.
  static CachedSymbolInfo? getSymbol(String filePath, int offset) {
    return _symbols[filePath]?[offset];
  }

  /// Get all symbols with a specific name in a file.
  static List<CachedSymbolInfo> getSymbolsByName(String filePath, String name) {
    final offsets = _nameIndex[filePath]?[name];
    if (offsets == null) return [];

    final fileSymbols = _symbols[filePath];
    if (fileSymbols == null) return [];

    return offsets
        .map((o) => fileSymbols[o])
        .whereType<CachedSymbolInfo>()
        .toList();
  }

  /// Get all symbols of a specific kind in a file.
  static List<CachedSymbolInfo> getSymbolsByKind(
      String filePath, SymbolKind kind) {
    final fileSymbols = _symbols[filePath];
    if (fileSymbols == null) return [];

    return fileSymbols.values.where((s) => s.kind == kind).toList();
  }

  /// Check if we have cached symbols for a file with matching content.
  static bool hasCachedSymbols(String filePath, String content) {
    return _contentHashes[filePath] == content.hashCode &&
        _symbols.containsKey(filePath);
  }

  /// Mark that symbols have been cached for a specific content version.
  static void markCached(String filePath, String content) {
    _contentHashes[filePath] = content.hashCode;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _symbols.remove(filePath);
    _nameIndex.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _symbols.clear();
    _nameIndex.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalSymbols = 0;
    for (final symbols in _symbols.values) {
      totalSymbols += symbols.length;
    }

    return {
      'cachedFiles': _symbols.length,
      'totalSymbols': totalSymbols,
    };
  }
}

// =============================================================================
// COMPILATION UNIT DERIVED DATA CACHE (Performance Optimization)
// =============================================================================
//
// Caches expensive AST traversal results that multiple rules query.
// Instead of each rule traversing the AST to find "all method names" or
// "all class hierarchies", we compute once and cache.
// =============================================================================

/// Cached derived data from a compilation unit.
class CompilationUnitDerivedData {
  CompilationUnitDerivedData();

  /// All class names declared in the file.
  final Set<String> classNames = {};

  /// All method names declared in the file.
  final Set<String> methodNames = {};

  /// All function names declared in the file.
  final Set<String> functionNames = {};

  /// All variable names declared in the file.
  final Set<String> variableNames = {};

  /// All field names declared in the file.
  final Set<String> fieldNames = {};

  /// All import URIs in the file.
  final Set<String> importUris = {};

  /// All export URIs in the file.
  final Set<String> exportUris = {};

  /// Whether file has main() function.
  bool hasMainFunction = false;

  /// Whether file has Flutter widgets.
  bool hasWidgets = false;

  /// Whether file has async code.
  bool hasAsyncCode = false;

  /// Whether file has tests.
  bool hasTests = false;

  /// Class inheritance map (class name -> superclass name).
  final Map<String, String?> classInheritance = {};

  /// Class mixins map (class name -> list of mixin names).
  final Map<String, List<String>> classMixins = {};

  /// Class interfaces map (class name -> list of interface names).
  final Map<String, List<String>> classInterfaces = {};
}

/// Caches derived data from compilation units.
///
/// Usage:
/// ```dart
/// // Get or create derived data for a file
/// final data = CompilationUnitCache.getOrCreate(filePath, content);
///
/// // Check if file declares a specific class
/// if (data.classNames.contains('MyWidget')) {
///   // Handle
/// }
///
/// // Check class inheritance
/// if (data.classInheritance['MyWidget'] == 'StatelessWidget') {
///   // It's a stateless widget
/// }
/// ```
class CompilationUnitCache {
  CompilationUnitCache._();

  // Map of file path -> derived data
  static final Map<String, CompilationUnitDerivedData> _cache = {};

  // Map of file path -> content hash (for invalidation)
  static final Map<String, int> _contentHashes = {};

  /// Get cached data for a file, or create empty data if not cached.
  static CompilationUnitDerivedData getOrCreate(
      String filePath, String content) {
    final hash = content.hashCode;
    if (_contentHashes[filePath] == hash && _cache.containsKey(filePath)) {
      return _cache[filePath]!;
    }

    // Create new data
    final data = CompilationUnitDerivedData();
    _cache[filePath] = data;
    _contentHashes[filePath] = hash;

    // Pre-populate with basic content analysis
    _analyzeContent(content, data);

    return data;
  }

  /// Quick content analysis to populate basic data.
  static void _analyzeContent(String content, CompilationUnitDerivedData data) {
    // Check for widgets
    data.hasWidgets = content.contains('extends StatelessWidget') ||
        content.contains('extends StatefulWidget') ||
        content.contains('extends State<');

    // Check for async
    data.hasAsyncCode =
        content.contains('async') || content.contains('Future<');

    // Check for tests
    data.hasTests = content.contains('@Test') ||
        content.contains('void main()') && content.contains('test(');

    // Check for main function
    data.hasMainFunction = RegExp(r'void\s+main\s*\(').hasMatch(content);

    // Extract imports
    final importPattern = RegExp(r'''import\s+['"]([^'"]+)['"]''');
    for (final match in importPattern.allMatches(content)) {
      final uri = match.group(1);
      if (uri != null) data.importUris.add(uri);
    }

    // Extract exports
    final exportPattern = RegExp(r'''export\s+['"]([^'"]+)['"]''');
    for (final match in exportPattern.allMatches(content)) {
      final uri = match.group(1);
      if (uri != null) data.exportUris.add(uri);
    }

    // Extract class names (simple pattern)
    final classPattern = RegExp(r'class\s+(\w+)');
    for (final match in classPattern.allMatches(content)) {
      final name = match.group(1);
      if (name != null) data.classNames.add(name);
    }

    // Extract function names (simple pattern)
    final funcPattern = RegExp(r'^\s*\w+\s+(\w+)\s*\(', multiLine: true);
    for (final match in funcPattern.allMatches(content)) {
      final name = match.group(1);
      if (name != null && name != 'if' && name != 'for' && name != 'while') {
        data.functionNames.add(name);
      }
    }
  }

  /// Get cached data for a file (returns null if not cached).
  static CompilationUnitDerivedData? get(String filePath) {
    return _cache[filePath];
  }

  /// Check if data is cached and current for a file.
  static bool isCached(String filePath, String content) {
    return _contentHashes[filePath] == content.hashCode &&
        _cache.containsKey(filePath);
  }

  /// Update derived data after AST analysis.
  static void update(String filePath, CompilationUnitDerivedData data) {
    _cache[filePath] = data;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
    _contentHashes.remove(filePath);
  }

  /// Clear all caches.
  static void clearCache() {
    _cache.clear();
    _contentHashes.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalClasses = 0;
    var totalMethods = 0;
    for (final data in _cache.values) {
      totalClasses += data.classNames.length;
      totalMethods += data.methodNames.length;
    }

    return {
      'cachedFiles': _cache.length,
      'totalClasses': totalClasses,
      'totalMethods': totalMethods,
    };
  }
}

// =============================================================================
// THROTTLED ANALYSIS FOR IDE (Performance Optimization)
// =============================================================================
//
// Throttles analysis requests during rapid typing to reduce CPU usage.
// When a user is actively typing, we delay analysis until they pause.
// This prevents the analyzer from running on every keystroke.
// =============================================================================

/// Throttles analysis during rapid editing.
///
/// Usage:
/// ```dart
/// // Before starting analysis
/// if (!ThrottledAnalysis.shouldAnalyze(filePath)) {
///   return; // Skip - user is still typing
/// }
///
/// // Record that file was modified
/// ThrottledAnalysis.recordEdit(filePath);
/// ```
class ThrottledAnalysis {
  ThrottledAnalysis._();

  // Map of file path -> last edit timestamp
  static final Map<String, DateTime> _lastEdit = {};

  // Map of file path -> last analysis timestamp
  static final Map<String, DateTime> _lastAnalysis = {};

  // Debounce duration (wait this long after last edit before analyzing)
  static Duration _debounceDelay = const Duration(milliseconds: 300);

  // Minimum interval between analyses for the same file
  static Duration _minAnalysisInterval = const Duration(milliseconds: 500);

  // Files currently being analyzed
  static final Set<String> _analyzing = {};

  /// Configure throttling parameters.
  static void configure({
    Duration? debounceDelay,
    Duration? minAnalysisInterval,
  }) {
    if (debounceDelay != null) _debounceDelay = debounceDelay;
    if (minAnalysisInterval != null) _minAnalysisInterval = minAnalysisInterval;
  }

  /// Record that a file was edited.
  static void recordEdit(String filePath) {
    _lastEdit[filePath] = DateTime.now();
  }

  /// Check if we should analyze a file now.
  ///
  /// Returns false if:
  /// - User edited recently (still typing)
  /// - Analysis ran recently (throttled)
  /// - Analysis is currently running
  static bool shouldAnalyze(String filePath) {
    final now = DateTime.now();

    // Check if currently analyzing
    if (_analyzing.contains(filePath)) {
      return false;
    }

    // Check debounce (wait for user to stop typing)
    final lastEdit = _lastEdit[filePath];
    if (lastEdit != null) {
      final elapsed = now.difference(lastEdit);
      if (elapsed < _debounceDelay) {
        return false;
      }
    }

    // Check minimum analysis interval
    final lastAnalysis = _lastAnalysis[filePath];
    if (lastAnalysis != null) {
      final elapsed = now.difference(lastAnalysis);
      if (elapsed < _minAnalysisInterval) {
        return false;
      }
    }

    return true;
  }

  /// Mark that analysis is starting.
  static void startAnalysis(String filePath) {
    _analyzing.add(filePath);
    _lastAnalysis[filePath] = DateTime.now();
  }

  /// Mark that analysis is complete.
  static void endAnalysis(String filePath) {
    _analyzing.remove(filePath);
  }

  /// Get time until next analysis is allowed.
  static Duration getTimeUntilAnalysis(String filePath) {
    final now = DateTime.now();
    var waitTime = Duration.zero;

    // Check debounce
    final lastEdit = _lastEdit[filePath];
    if (lastEdit != null) {
      final debounceEnd = lastEdit.add(_debounceDelay);
      if (debounceEnd.isAfter(now)) {
        waitTime = debounceEnd.difference(now);
      }
    }

    // Check throttle
    final lastAnalysis = _lastAnalysis[filePath];
    if (lastAnalysis != null) {
      final throttleEnd = lastAnalysis.add(_minAnalysisInterval);
      if (throttleEnd.isAfter(now)) {
        final throttleWait = throttleEnd.difference(now);
        if (throttleWait > waitTime) {
          waitTime = throttleWait;
        }
      }
    }

    return waitTime;
  }

  /// Clear throttle state for a file.
  static void clear(String filePath) {
    _lastEdit.remove(filePath);
    _lastAnalysis.remove(filePath);
    _analyzing.remove(filePath);
  }

  /// Clear all throttle state.
  static void clearAll() {
    _lastEdit.clear();
    _lastAnalysis.clear();
    _analyzing.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'trackedFiles': _lastEdit.length,
      'analyzingFiles': _analyzing.length,
      'debounceDelayMs': _debounceDelay.inMilliseconds,
      'minIntervalMs': _minAnalysisInterval.inMilliseconds,
    };
  }
}

// =============================================================================
// BACKGROUND SPECULATIVE ANALYSIS (Performance Optimization)
// =============================================================================
//
// Speculatively pre-analyzes files likely to be opened next.
// When a user opens file A, we can predict they might open file B
// (e.g., test file for implementation, or files in same directory).
// =============================================================================

/// Speculatively pre-analyzes likely-to-be-opened files.
///
/// Usage:
/// ```dart
/// // When user opens a file
/// final predictions = SpeculativeAnalysis.predictNextFiles(filePath);
/// for (final predicted in predictions) {
///   SpeculativeAnalysis.schedulePreAnalysis(predicted);
/// }
///
/// // Check if a file was pre-analyzed
/// if (SpeculativeAnalysis.isPreAnalyzed(filePath)) {
///   // Use cached results
/// }
/// ```
class SpeculativeAnalysis {
  SpeculativeAnalysis._();

  // Files that have been pre-analyzed
  static final Set<String> _preAnalyzed = {};

  // Queue of files to pre-analyze
  static final List<String> _queue = [];

  // Map of file -> associated files (for predictions)
  static final Map<String, Set<String>> _associations = {};

  // History of recently opened files
  static final List<String> _openHistory = [];
  static const int _maxHistory = 20;

  // Maximum files to pre-analyze in background
  static const int _maxPreAnalyze = 5;

  /// Predict which files might be opened next.
  ///
  /// Predictions based on:
  /// - Test file for implementation (or vice versa)
  /// - Files in same directory
  /// - Files imported by current file
  /// - Historical patterns
  static List<String> predictNextFiles(String currentFile) {
    final predictions = <String>{};
    final normalizedPath = currentFile.replaceAll('\\', '/');

    // Predict test file
    if (!normalizedPath.contains('_test.dart')) {
      final testPath = normalizedPath.replaceFirst('.dart', '_test.dart');
      if (testPath != normalizedPath) predictions.add(testPath);
    } else {
      // Predict implementation file
      final implPath = normalizedPath.replaceFirst('_test.dart', '.dart');
      if (implPath != normalizedPath) predictions.add(implPath);
    }

    // Add associated files
    final associated = _associations[currentFile];
    if (associated != null) {
      predictions.addAll(associated.take(3));
    }

    // Add imports (from ImportGraphCache if available)
    final imports = ImportGraphCache.getImports(currentFile);
    for (final imp in imports.take(2)) {
      if (!imp.startsWith('dart:') && !imp.startsWith('package:')) {
        predictions.add(imp);
      }
    }

    return predictions.take(_maxPreAnalyze).toList();
  }

  /// Record that a file was opened (for learning associations).
  static void recordFileOpened(String filePath) {
    // Update history
    _openHistory.remove(filePath);
    _openHistory.insert(0, filePath);
    if (_openHistory.length > _maxHistory) {
      _openHistory.removeLast();
    }

    // Learn associations (files opened in sequence)
    if (_openHistory.length >= 2) {
      final previous = _openHistory[1];
      _associations.putIfAbsent(previous, () => {}).add(filePath);
      _associations.putIfAbsent(filePath, () => {}).add(previous);
    }
  }

  /// Schedule a file for background pre-analysis.
  static void schedulePreAnalysis(String filePath) {
    if (_preAnalyzed.contains(filePath)) return;
    if (_queue.contains(filePath)) return;

    _queue.add(filePath);

    // Trim queue if too long
    while (_queue.length > _maxPreAnalyze * 2) {
      _queue.removeAt(0);
    }
  }

  /// Get next file to pre-analyze (if any).
  static String? getNextToAnalyze() {
    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      if (!_preAnalyzed.contains(next)) {
        return next;
      }
    }
    return null;
  }

  /// Mark a file as pre-analyzed.
  static void markPreAnalyzed(String filePath) {
    _preAnalyzed.add(filePath);
  }

  /// Check if a file was pre-analyzed.
  static bool isPreAnalyzed(String filePath) {
    return _preAnalyzed.contains(filePath);
  }

  /// Invalidate pre-analysis (e.g., when file changes).
  static void invalidate(String filePath) {
    _preAnalyzed.remove(filePath);
  }

  /// Clear all state.
  static void clearAll() {
    _preAnalyzed.clear();
    _queue.clear();
    _associations.clear();
    _openHistory.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'preAnalyzedFiles': _preAnalyzed.length,
      'queuedFiles': _queue.length,
      'associations': _associations.length,
      'historySize': _openHistory.length,
    };
  }
}

// =============================================================================
// RULE GROUP EXECUTION (Performance Optimization)
// =============================================================================
//
// Groups related rules for batch execution. Rules in the same group share
// setup/teardown costs and can share intermediate results.
// =============================================================================

/// Defines a group of related rules that can share execution context.
class RuleGroup {
  const RuleGroup({
    required this.name,
    required this.rules,
    this.sharedPatterns = const {},
    this.sharedCategories = const {},
    this.priority = 100,
  });

  /// Group name (e.g., 'flutter_widgets', 'async_rules').
  final String name;

  /// Rule names in this group.
  final Set<String> rules;

  /// Patterns that all rules in this group might need.
  final Set<String> sharedPatterns;

  /// AST node categories that rules in this group visit.
  final Set<AstNodeCategory> sharedCategories;

  /// Priority for group execution order (lower = runs first).
  final int priority;
}

/// Manages rule group execution for optimal performance.
///
/// Usage:
/// ```dart
/// // Register groups at startup
/// RuleGroupExecutor.registerGroup(RuleGroup(
///   name: 'async_rules',
///   rules: {'avoid_slow_async_io', 'unawaited_futures', ...},
///   sharedPatterns: {'async', 'await', 'Future'},
/// ));
///
/// // Get groups applicable to a file
/// final groups = RuleGroupExecutor.getApplicableGroups(filePath, content);
///
/// // Execute groups in order
/// for (final group in groups) {
///   RuleGroupExecutor.startGroup(group.name, filePath);
///   // Execute rules in group...
///   RuleGroupExecutor.endGroup(group.name, filePath);
/// }
/// ```
class RuleGroupExecutor {
  RuleGroupExecutor._();

  // Registered groups
  static final Map<String, RuleGroup> _groups = {};

  // Map of rule name -> group name
  static final Map<String, String> _ruleToGroup = {};

  // Shared context per group execution
  static final Map<String, Map<String, dynamic>> _groupContext = {};

  // Track active group executions
  static final Map<String, DateTime> _activeGroups = {};

  /// Register a rule group.
  static void registerGroup(RuleGroup group) {
    _groups[group.name] = group;
    for (final rule in group.rules) {
      _ruleToGroup[rule] = group.name;
    }
  }

  /// Get the group a rule belongs to (if any).
  static String? getGroupForRule(String ruleName) {
    return _ruleToGroup[ruleName];
  }

  /// Get all groups applicable to a file.
  ///
  /// A group is applicable if any of its shared patterns match the content.
  static List<RuleGroup> getApplicableGroups(String filePath, String content) {
    final applicable = <RuleGroup>[];

    for (final group in _groups.values) {
      // Check if any shared patterns match
      if (group.sharedPatterns.isEmpty ||
          group.sharedPatterns.any((p) => content.contains(p))) {
        applicable.add(group);
      }
    }

    // Sort by priority
    applicable.sort((a, b) => a.priority.compareTo(b.priority));
    return applicable;
  }

  /// Start executing a group on a file.
  ///
  /// Sets up shared context for rules in the group.
  static void startGroup(String groupName, String filePath) {
    final key = '$groupName:$filePath';
    _activeGroups[key] = DateTime.now();
    _groupContext[key] = {};
  }

  /// End group execution.
  static void endGroup(String groupName, String filePath) {
    final key = '$groupName:$filePath';
    _activeGroups.remove(key);
    _groupContext.remove(key);
  }

  /// Store shared data in group context.
  static void setGroupData(
    String groupName,
    String filePath,
    String key,
    dynamic value,
  ) {
    final contextKey = '$groupName:$filePath';
    _groupContext[contextKey]?[key] = value;
  }

  /// Get shared data from group context.
  static T? getGroupData<T>(String groupName, String filePath, String key) {
    final contextKey = '$groupName:$filePath';
    return _groupContext[contextKey]?[key] as T?;
  }

  /// Check if a group is currently active for a file.
  static bool isGroupActive(String groupName, String filePath) {
    return _activeGroups.containsKey('$groupName:$filePath');
  }

  /// Get all registered groups.
  static List<RuleGroup> get allGroups => _groups.values.toList();

  /// Clear all registrations.
  static void clear() {
    _groups.clear();
    _ruleToGroup.clear();
    _groupContext.clear();
    _activeGroups.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'registeredGroups': _groups.length,
      'totalRulesInGroups': _ruleToGroup.length,
      'activeGroupExecutions': _activeGroups.length,
    };
  }
}

// =============================================================================
// STRING INTERNING POOL (Performance Optimization)
// =============================================================================
//
// Interns frequently used strings to reduce memory allocation.
// Many rules use the same strings repeatedly (e.g., 'StatelessWidget',
// 'BuildContext'). Interning ensures only one copy exists in memory.
// =============================================================================

/// Interns strings for memory efficiency.
///
/// Usage:
/// ```dart
/// // Intern a string
/// final className = StringInterner.intern('StatelessWidget');
///
/// // Later comparisons use == instead of string comparison
/// if (identical(otherClassName, StringInterner.intern('StatelessWidget'))) {
///   // Same string instance
/// }
///
/// // Pre-intern known common strings at startup
/// StringInterner.preIntern(['StatelessWidget', 'StatefulWidget', ...]);
/// ```
class StringInterner {
  StringInterner._();

  // The intern pool
  static final Map<String, String> _pool = {};

  // Common Dart/Flutter strings to pre-intern
  static const List<String> _commonStrings = [
    // Flutter widgets
    'StatelessWidget',
    'StatefulWidget',
    'State',
    'BuildContext',
    'Widget',
    'Key',
    // Common types
    'String',
    'int',
    'double',
    'bool',
    'List',
    'Map',
    'Set',
    'Future',
    'Stream',
    'void',
    'dynamic',
    'Object',
    'Null',
    // Common modifiers
    'async',
    'await',
    'const',
    'final',
    'static',
    'late',
    'required',
    'override',
    // Common patterns
    'dispose',
    'initState',
    'build',
    'setState',
    'mounted',
  ];

  /// Intern a string, returning the canonical instance.
  static String intern(String s) {
    return _pool.putIfAbsent(s, () => s);
  }

  /// Pre-intern a list of strings.
  static void preIntern(Iterable<String> strings) {
    for (final s in strings) {
      _pool.putIfAbsent(s, () => s);
    }
  }

  /// Pre-intern common Dart/Flutter strings.
  static void preInternCommon() {
    preIntern(_commonStrings);
  }

  /// Check if a string is already interned.
  static bool isInterned(String s) {
    return _pool.containsKey(s);
  }

  /// Get the interned version if it exists, otherwise null.
  static String? getInterned(String s) {
    return _pool[s];
  }

  /// Compare two strings using interned equality.
  ///
  /// Returns true if both strings intern to the same instance.
  static bool equals(String a, String b) {
    return identical(intern(a), intern(b));
  }

  /// Clear the intern pool.
  ///
  /// Call this to free memory, but be careful as existing
  /// references to interned strings will still work.
  static void clear() {
    _pool.clear();
  }

  /// Get pool size.
  static int get poolSize => _pool.length;

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalChars = 0;
    for (final s in _pool.keys) {
      totalChars += s.length;
    }

    return {
      'poolSize': _pool.length,
      'totalCharacters': totalChars,
      'estimatedMemorySaved': totalChars * 2, // Approximate bytes saved
    };
  }
}

// =============================================================================
// HOT PATH PROFILING (Performance Optimization)
// =============================================================================
//
// Instruments hot paths for performance profiling. Helps identify
// which rules and operations take the most time.
// =============================================================================

/// Records a profiling measurement.
class ProfilingEntry {
  const ProfilingEntry({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.metadata,
  });

  final String name;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}

/// Profiles hot paths for performance analysis.
///
/// Usage:
/// ```dart
/// // Profile a rule execution
/// final stopwatch = HotPathProfiler.startProfile('avoid_print');
/// // ... execute rule ...
/// HotPathProfiler.endProfile('avoid_print', stopwatch);
///
/// // Get profiling report
/// final report = HotPathProfiler.getReport();
/// for (final entry in report.slowest) {
///   print('${entry.name}: ${entry.averageDuration}ms');
/// }
/// ```
class HotPathProfiler {
  HotPathProfiler._();

  // Whether profiling is enabled
  static bool _enabled = false;

  // Map of name -> list of durations
  static final Map<String, List<Duration>> _measurements = {};

  // Recent profiling entries (for detailed analysis)
  static final List<ProfilingEntry> _recentEntries = [];
  static const int _maxRecentEntries = 1000;

  // Threshold for "slow" operations
  static Duration _slowThreshold = const Duration(milliseconds: 50);

  /// Enable profiling.
  static void enable() {
    _enabled = true;
  }

  /// Disable profiling.
  static void disable() {
    _enabled = false;
  }

  /// Check if profiling is enabled.
  static bool get isEnabled => _enabled;

  /// Configure slow threshold.
  static void setSlowThreshold(Duration threshold) {
    _slowThreshold = threshold;
  }

  /// Start profiling an operation.
  ///
  /// Returns a Stopwatch that should be passed to [endProfile].
  static Stopwatch startProfile(String name) {
    final stopwatch = Stopwatch();
    if (_enabled) {
      stopwatch.start();
    }
    return stopwatch;
  }

  /// End profiling and record the measurement.
  static void endProfile(
    String name,
    Stopwatch stopwatch, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_enabled) return;

    stopwatch.stop();
    final duration = stopwatch.elapsed;

    // Record measurement
    _measurements.putIfAbsent(name, () => []).add(duration);

    // Record entry
    final entry = ProfilingEntry(
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    _recentEntries.add(entry);

    // Trim old entries
    while (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeAt(0);
    }
  }

  /// Record a measurement directly (for cases where stopwatch isn't used).
  static void recordMeasurement(
    String name,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_enabled) return;

    _measurements.putIfAbsent(name, () => []).add(duration);

    _recentEntries.add(ProfilingEntry(
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));

    while (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeAt(0);
    }
  }

  /// Get average duration for an operation.
  static Duration getAverageDuration(String name) {
    final measurements = _measurements[name];
    if (measurements == null || measurements.isEmpty) {
      return Duration.zero;
    }

    var total = Duration.zero;
    for (final m in measurements) {
      total += m;
    }
    return total ~/ measurements.length;
  }

  /// Get all slow operations (above threshold).
  static List<String> getSlowOperations() {
    final slow = <String>[];
    for (final entry in _measurements.entries) {
      final avg = getAverageDuration(entry.key);
      if (avg >= _slowThreshold) {
        slow.add(entry.key);
      }
    }
    return slow;
  }

  /// Get slowest N operations.
  static List<MapEntry<String, Duration>> getSlowest(int n) {
    final averages = <MapEntry<String, Duration>>[];
    for (final name in _measurements.keys) {
      averages.add(MapEntry(name, getAverageDuration(name)));
    }
    averages.sort((a, b) => b.value.compareTo(a.value));
    return averages.take(n).toList();
  }

  /// Get recent entries for detailed analysis.
  static List<ProfilingEntry> getRecentEntries({
    String? filterName,
    Duration? minDuration,
  }) {
    var entries = _recentEntries.toList();

    if (filterName != null) {
      entries = entries.where((e) => e.name == filterName).toList();
    }

    if (minDuration != null) {
      entries = entries.where((e) => e.duration >= minDuration).toList();
    }

    return entries;
  }

  /// Clear all measurements.
  static void clear() {
    _measurements.clear();
    _recentEntries.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalMeasurements = 0;
    for (final m in _measurements.values) {
      totalMeasurements += m.length;
    }

    final slowOperations = getSlowOperations();
    final slowest = getSlowest(5);

    return {
      'enabled': _enabled,
      'operationsTracked': _measurements.length,
      'totalMeasurements': totalMeasurements,
      'recentEntries': _recentEntries.length,
      'slowOperationCount': slowOperations.length,
      'slowestOperations':
          slowest.map((e) => '${e.key}: ${e.value.inMilliseconds}ms').toList(),
    };
  }
}

// =============================================================================
// LRU CACHE WITH SIZE LIMITS (Performance Optimization)
// =============================================================================
//
// Generic LRU (Least Recently Used) cache with configurable size limits.
// When the cache exceeds its maximum size, the least recently accessed
// entries are evicted. This prevents unbounded memory growth.
// =============================================================================

/// A node in the LRU doubly-linked list.
class _LruNode<K, V> {
  _LruNode(this.key, this.value);

  final K key;
  V value;
  _LruNode<K, V>? prev;
  _LruNode<K, V>? next;
}

/// Generic LRU cache with size limits.
///
/// Usage:
/// ```dart
/// final cache = LruCache<String, FileMetrics>(maxSize: 1000);
/// cache.put('file.dart', metrics);
/// final metrics = cache.get('file.dart'); // Moves to front
/// ```
class LruCache<K, V> {
  LruCache({required this.maxSize}) : assert(maxSize > 0);

  final int maxSize;
  final Map<K, _LruNode<K, V>> _map = {};
  _LruNode<K, V>? _head;
  _LruNode<K, V>? _tail;

  /// Get a value, moving it to the front (most recently used).
  V? get(K key) {
    final node = _map[key];
    if (node == null) return null;

    _moveToFront(node);
    return node.value;
  }

  /// Check if key exists without affecting LRU order.
  bool containsKey(K key) => _map.containsKey(key);

  /// Put a value, evicting old entries if needed.
  void put(K key, V value) {
    final existing = _map[key];
    if (existing != null) {
      existing.value = value;
      _moveToFront(existing);
      return;
    }

    // Create new node
    final node = _LruNode(key, value);
    _map[key] = node;
    _addToFront(node);

    // Evict if over capacity
    while (_map.length > maxSize) {
      _evictLru();
    }
  }

  /// Get or create a value using the factory.
  V putIfAbsent(K key, V Function() factory) {
    final existing = get(key);
    if (existing != null) return existing;

    final value = factory();
    put(key, value);
    return value;
  }

  /// Remove a specific key.
  V? remove(K key) {
    final node = _map.remove(key);
    if (node == null) return null;

    _removeNode(node);
    return node.value;
  }

  /// Clear all entries.
  void clear() {
    _map.clear();
    _head = null;
    _tail = null;
  }

  /// Current size.
  int get length => _map.length;

  /// All keys (most recent first).
  Iterable<K> get keys sync* {
    var node = _head;
    while (node != null) {
      yield node.key;
      node = node.next;
    }
  }

  /// All values (most recent first).
  Iterable<V> get values sync* {
    var node = _head;
    while (node != null) {
      yield node.value;
      node = node.next;
    }
  }

  void _moveToFront(_LruNode<K, V> node) {
    if (node == _head) return;

    _removeNode(node);
    _addToFront(node);
  }

  void _addToFront(_LruNode<K, V> node) {
    node.prev = null;
    node.next = _head;

    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;

    if (_tail == null) {
      _tail = node;
    }
  }

  void _removeNode(_LruNode<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }

    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }
  }

  void _evictLru() {
    if (_tail == null) return;

    _map.remove(_tail!.key);
    _removeNode(_tail!);
  }
}

// =============================================================================
// MEMORY PRESSURE HANDLING (Performance Optimization)
// =============================================================================
//
// Monitors memory usage and clears caches when under pressure.
// This prevents the analysis process from running out of memory
// on large projects with many files.
// =============================================================================

/// Handles memory pressure by clearing caches.
///
/// Usage:
/// ```dart
/// // Register caches to be cleared under pressure
/// MemoryPressureHandler.registerCache('fileMetrics', FileMetricsCache.clearCache);
///
/// // Check periodically (e.g., every 100 files)
/// MemoryPressureHandler.checkAndRelieve();
///
/// // Or set up automatic threshold-based clearing
/// MemoryPressureHandler.enableAutoRelief(thresholdMb: 500);
/// ```
class MemoryPressureHandler {
  MemoryPressureHandler._();

  // Registered cache clear functions with priority (lower = clear first)
  static final Map<String, _CacheRegistration> _caches = {};

  // Configuration
  static int _thresholdMb = 512; // Default 512MB threshold
  static bool _autoReliefEnabled = false;
  static int _checkIntervalFiles = 50; // Check every N files
  static int _filesProcessed = 0;

  // Statistics
  static int _relieveCount = 0;
  static DateTime? _lastRelieve;

  /// Register a cache to be cleared under memory pressure.
  ///
  /// [priority] - Lower values are cleared first (0-100).
  /// Use low priority for expensive-to-rebuild caches.
  static void registerCache(
    String name,
    void Function() clearFunction, {
    int priority = 50,
  }) {
    _caches[name] = _CacheRegistration(
      name: name,
      clear: clearFunction,
      priority: priority,
    );
  }

  /// Unregister a cache.
  static void unregisterCache(String name) {
    _caches.remove(name);
  }

  /// Enable automatic memory relief.
  static void enableAutoRelief({
    int thresholdMb = 512,
    int checkIntervalFiles = 50,
  }) {
    _autoReliefEnabled = true;
    _thresholdMb = thresholdMb;
    _checkIntervalFiles = checkIntervalFiles;
  }

  /// Disable automatic memory relief.
  static void disableAutoRelief() {
    _autoReliefEnabled = false;
  }

  /// Record that a file was processed (for auto-relief timing).
  static void recordFileProcessed() {
    _filesProcessed++;

    if (_autoReliefEnabled && _filesProcessed >= _checkIntervalFiles) {
      _filesProcessed = 0;
      checkAndRelieve();
    }
  }

  /// Check memory pressure and relieve if needed.
  ///
  /// Returns true if caches were cleared.
  static bool checkAndRelieve() {
    // Note: Dart doesn't provide direct memory usage APIs in all environments.
    // We use a heuristic based on cache sizes instead.
    final estimatedUsageMb = _estimateMemoryUsageMb();

    if (estimatedUsageMb > _thresholdMb) {
      relieve(clearAll: false);
      return true;
    }
    return false;
  }

  /// Clear caches to relieve memory pressure.
  ///
  /// If [clearAll] is false, only clears low-priority caches.
  /// If [clearAll] is true, clears everything.
  static void relieve({bool clearAll = false}) {
    _relieveCount++;
    _lastRelieve = DateTime.now();

    // Sort by priority (low priority = clear first)
    final sorted = _caches.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Clear caches by priority
    for (final cache in sorted) {
      if (clearAll || cache.priority >= 50) {
        cache.clear();
      }
    }
  }

  /// Force clear all registered caches.
  static void clearAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
  }

  /// Estimate current memory usage from known cache sizes.
  static int _estimateMemoryUsageMb() {
    // Rough estimation based on typical cache entry sizes
    var estimatedBytes = 0;

    // File content cache: ~1KB per file (hash + rules set)
    estimatedBytes += FileContentCache._contentHashes.length * 1024;

    // Metrics cache: ~200 bytes per entry
    estimatedBytes += FileMetricsCache._cache.length * 200;

    // Source location cache: ~1KB per file (line starts array)
    estimatedBytes += SourceLocationCache._lineStarts.length * 1024;

    // Semantic token cache: ~500 bytes per symbol
    for (final symbols in SemanticTokenCache._symbols.values) {
      estimatedBytes += symbols.length * 500;
    }

    // Compilation unit cache: ~2KB per file
    estimatedBytes += CompilationUnitCache._cache.length * 2048;

    // Import graph: ~500 bytes per node
    estimatedBytes += ImportGraphCache._graph.length * 500;

    // String intern pool: actual string sizes
    for (final s in StringInterner._pool.keys) {
      estimatedBytes += s.length * 2; // UTF-16
    }

    return estimatedBytes ~/ (1024 * 1024);
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'registeredCaches': _caches.length,
      'autoReliefEnabled': _autoReliefEnabled,
      'thresholdMb': _thresholdMb,
      'estimatedUsageMb': _estimateMemoryUsageMb(),
      'relieveCount': _relieveCount,
      'lastRelieve': _lastRelieve?.toIso8601String(),
    };
  }
}

class _CacheRegistration {
  const _CacheRegistration({
    required this.name,
    required this.clear,
    required this.priority,
  });

  final String name;
  final void Function() clear;
  final int priority;
}

/// Initialize all caches with memory pressure handling.
///
/// Call this once at startup to register all caches.
void initializeCacheManagement({
  int maxFileContentCache = 500,
  int maxMetricsCache = 2000,
  int maxLocationCache = 2000,
  int maxSymbolCache = 1000,
  int maxCompilationUnitCache = 1000,
  int memoryThresholdMb = 512,
}) {
  // Register caches with priorities (lower = clear first when under pressure)
  // Content caches are expensive to rebuild, so clear last
  MemoryPressureHandler.registerCache(
    'stringInterner',
    StringInterner.clear,
    priority: 10, // Clear first - easy to rebuild
  );
  MemoryPressureHandler.registerCache(
    'contentFingerprint',
    ContentFingerprint.clearCache,
    priority: 20,
  );
  MemoryPressureHandler.registerCache(
    'lazyPatterns',
    LazyPatternCache.clearCache,
    priority: 25,
  );
  MemoryPressureHandler.registerCache(
    'contentRegions',
    ContentRegionIndex.clearCache,
    priority: 30,
  );
  MemoryPressureHandler.registerCache(
    'sourceLocation',
    SourceLocationCache.clearCache,
    priority: 40,
  );
  MemoryPressureHandler.registerCache(
    'semanticTokens',
    SemanticTokenCache.clearCache,
    priority: 50,
  );
  MemoryPressureHandler.registerCache(
    'compilationUnit',
    CompilationUnitCache.clearCache,
    priority: 60,
  );
  MemoryPressureHandler.registerCache(
    'fileMetrics',
    FileMetricsCache.clearCache,
    priority: 70,
  );
  MemoryPressureHandler.registerCache(
    'importGraph',
    ImportGraphCache.clearCache,
    priority: 80, // Expensive to rebuild
  );
  MemoryPressureHandler.registerCache(
    'fileContent',
    FileContentCache.clearCache,
    priority: 90, // Very expensive - clear last
  );

  // Enable automatic relief
  MemoryPressureHandler.enableAutoRelief(
    thresholdMb: memoryThresholdMb,
    checkIntervalFiles: 50,
  );
}
