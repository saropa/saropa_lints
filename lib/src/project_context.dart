// ignore_for_file: always_specify_types

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

import 'dart:io';

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
    final projectRoot = _findProjectRoot(filePath);
    if (projectRoot == null) return null;

    return _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
  }

  /// Find the project root directory (contains pubspec.yaml).
  static String? _findProjectRoot(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
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
  });

  factory _ProjectInfo._fromProjectRoot(String projectRoot) {
    final pubspecFile = File('$projectRoot/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      return _ProjectInfo._(isFlutterProject: false, dependencies: {});
    }

    try {
      final content = pubspecFile.readAsStringSync();
      final isFlutter = content.contains('flutter:') ||
          content.contains('flutter_test:') ||
          content.contains('sdk: flutter');

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
      );
    } catch (_) {
      return _ProjectInfo._(isFlutterProject: false, dependencies: {});
    }
  }

  /// Whether this is a Flutter project (has flutter SDK dependency).
  final bool isFlutterProject;

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
    final newHash = content.hashCode;
    final oldHash = _contentHashes[filePath];

    if (oldHash == null || oldHash != newHash) {
      // File is new or changed - update cache and clear passed rules
      _contentHashes[filePath] = newHash;
      _passedRules.remove(filePath);
      return true;
    }

    return false;
  }

  /// Record that a rule passed (no violations) on a file.
  ///
  /// Call this after a rule completes with no violations.
  static void recordRulePassed(String filePath, String ruleName) {
    _passedRules.putIfAbsent(filePath, () => {}).add(ruleName);
  }

  /// Check if a rule previously passed on an unchanged file.
  ///
  /// Returns `true` if the file is unchanged AND the rule passed before.
  static bool rulePreviouslyPassed(String filePath, String ruleName) {
    return _passedRules[filePath]?.contains(ruleName) ?? false;
  }

  /// Clear cache for a specific file.
  static void invalidate(String filePath) {
    _contentHashes.remove(filePath);
    _passedRules.remove(filePath);
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
    // Check cache first
    if (_cache.containsKey(filePath)) {
      return _cache[filePath]!;
    }

    final types = <FileType>{};
    final normalizedPath = filePath.replaceAll('\\', '/');

    // Path-based detection (fast)
    if (normalizedPath.endsWith('_test.dart') ||
        normalizedPath.contains('/test/') ||
        normalizedPath.contains('/integration_test/')) {
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

    _cache[filePath] = types;
    return types;
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
