part of 'project_context.dart';

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
  /// Returns null if [filePath] is null/empty or no project root is found.
  static _ProjectInfo? getProjectInfo(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final projectRoot = findProjectRoot(filePath);
    if (projectRoot == null || projectRoot.isEmpty) return null;

    return _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
  }

  /// Get the package name for the project at [projectRoot].
  ///
  /// Returns the `name:` field from `pubspec.yaml`, or an empty string
  /// if not found. Result is cached.
  /// Returns empty string if [projectRoot] is null or empty.
  static String getPackageName(String? projectRoot) {
    if (projectRoot == null || projectRoot.isEmpty) return '';
    final info = _projectCache.putIfAbsent(projectRoot, () {
      return _ProjectInfo._fromProjectRoot(projectRoot);
    });
    return info.packageName;
  }

  /// Find the project root directory (contains pubspec.yaml).
  ///
  /// Walks up the directory tree from [filePath] looking for pubspec.yaml.
  /// Returns `null` if no project root is found or [filePath] is null/empty.
  static String? findProjectRoot(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final normalized = normalizePath(filePath);
    if (normalized.isEmpty) return null;
    try {
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
    } on OSError {
      return null;
    }
  }

  /// Check if the project containing [filePath] has a specific dependency.
  /// Returns false if [filePath] or [packageName] is null/empty.
  static bool hasDependency(String? filePath, String? packageName) {
    if (filePath == null || filePath.isEmpty) return false;
    if (packageName == null || packageName.isEmpty) return false;
    return getProjectInfo(filePath)?.hasDependency(packageName) ?? false;
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
      final isFlutter =
          content.contains('flutter:') ||
          content.contains('flutter_test:') ||
          content.contains('sdk: flutter');

      // Parse package name from top-level `name:` field (valid Dart pkg names)
      final nameMatch = RegExp(
        r'^name:\s+([a-z][a-z0-9_]*)',
        multiLine: true,
      ).firstMatch(content);
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
    } on FormatException {
      return _ProjectInfo._(
        isFlutterProject: false,
        dependencies: {},
        packageName: '',
      );
    } on IOException {
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
    final cached = _cache[normalizedPath];
    if (cached != null) return cached;

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
