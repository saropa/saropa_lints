import 'dart:io';

import 'baseline_config.dart';
import 'baseline_date.dart';
import 'baseline_file.dart';
import 'baseline_paths.dart';

/// Central manager for baseline functionality.
///
/// Combines three baseline types - any match suppresses the violation:
///
/// 1. **File-based** (`baseline.file`): JSON file listing specific violations
/// 2. **Path-based** (`baseline.paths`): Glob patterns for directories/files
/// 3. **Date-based** (`baseline.date`): Git blame to ignore old code
///
/// ## Configuration Example
///
/// ```yaml
/// custom_lint:
///   saropa_lints:
///     baseline:
///       file: "saropa_baseline.json"    # Specific violations
///       date: "2025-01-15"              # Code unchanged since this date
///       paths:                           # Directories/patterns
///         - "lib/legacy/"
///         - "**/generated/"
///       only_impacts: [low, medium]     # Only baseline these severities
/// ```
///
/// ## Usage
///
/// ```dart
/// // Initialize once during plugin startup
/// BaselineManager.initialize(config);
///
/// // Check in reporter before emitting violation
/// if (BaselineManager.isBaselined(filePath, ruleName, line)) {
///   return; // Suppressed
/// }
/// ```
class BaselineManager {
  BaselineManager._();

  static BaselineConfig? _config;
  static BaselineFile? _baselineFile;
  static BaselinePaths? _baselinePaths;
  static BaselineDate? _baselineDate;
  static String? _projectRoot;

  // Cache for date-based baseline (file -> line -> isOld)
  static final Map<String, Map<int, bool>> _dateCache = {};

  /// Initialize the baseline manager with configuration.
  ///
  /// Should be called once during plugin initialization.
  /// [projectRoot] is optional - will auto-detect from pubspec.yaml if not provided.
  static void initialize(BaselineConfig config, {String? projectRoot}) {
    _config = config;
    _projectRoot = projectRoot ?? _findProjectRoot(Directory.current.path);

    // Initialize file-based baseline
    if (config.file != null) {
      final filePath = _resolveFilePath(config.file!);
      _baselineFile = BaselineFile.load(filePath);
    }

    // Initialize path-based baseline
    if (config.paths.isNotEmpty) {
      _baselinePaths = BaselinePaths(config.paths);
    }

    // Initialize date-based baseline
    if (config.date != null) {
      _baselineDate = BaselineDate(config.date!);
    }
  }

  /// Clear the baseline manager (for testing).
  static void reset() {
    _config = null;
    _baselineFile = null;
    _baselinePaths = null;
    _baselineDate = null;
    _projectRoot = null;
    _dateCache.clear();
    BaselineDate.clearCache();
  }

  /// Whether the baseline manager is initialized and has any baselines configured.
  static bool get isEnabled => _config?.isEnabled ?? false;

  /// Check if a violation should be suppressed by any baseline (synchronous).
  ///
  /// Returns true if the violation matches:
  /// - The baseline file (exact file:line:rule match)
  /// - A baselined path pattern
  /// - Code older than the baseline date (uses cached data)
  ///
  /// [filePath] is the full path to the file.
  /// [ruleName] is the lint rule name.
  /// [line] is the 1-based line number.
  /// [impact] is the rule's impact level (optional, for filtering).
  ///
  /// **Note**: Date-based baseline requires [preloadDateBaseline] to be called first.
  /// If not preloaded, date-based checks are skipped.
  static bool isBaselined(
    String filePath,
    String ruleName,
    int line, {
    String? impact,
  }) {
    final config = _config;
    if (config == null || !config.isEnabled) {
      return false;
    }

    // Check impact filter first (only_impacts configuration)
    if (impact != null && !config.shouldBaselineImpact(impact)) {
      return false;
    }

    // Check file-based baseline
    if (_checkFileBaseline(filePath, ruleName, line)) {
      return true;
    }

    // Check path-based baseline
    if (_checkPathBaseline(filePath)) {
      return true;
    }

    // Check date-based baseline (from cache)
    if (_checkDateBaselineSync(filePath, line)) {
      return true;
    }

    return false;
  }

  /// Check if a violation should be suppressed (async version with full date support).
  ///
  /// This version runs git blame if needed. Use for CLI tools or when
  /// async operations are acceptable.
  static Future<bool> isBaselinedAsync(
    String filePath,
    String ruleName,
    int line, {
    String? impact,
  }) async {
    final config = _config;
    if (config == null || !config.isEnabled) {
      return false;
    }

    // Check impact filter first
    if (impact != null && !config.shouldBaselineImpact(impact)) {
      return false;
    }

    // Check file-based baseline
    if (_checkFileBaseline(filePath, ruleName, line)) {
      return true;
    }

    // Check path-based baseline
    if (_checkPathBaseline(filePath)) {
      return true;
    }

    // Check date-based baseline (with git blame)
    if (await _checkDateBaselineAsync(filePath, line)) {
      return true;
    }

    return false;
  }

  /// Preload date-based baseline data for a file.
  ///
  /// Call this before analyzing a file to enable date-based baseline checks.
  /// This runs `git blame` once for the file and caches all line dates.
  static Future<void> preloadDateBaseline(String filePath) async {
    final baselineDate = _baselineDate;
    if (baselineDate == null) return;

    await baselineDate.preloadFile(filePath, projectRoot: _projectRoot);

    // Also populate our sync cache
    final fileCache = _dateCache.putIfAbsent(filePath, () => {});
    final file = File(filePath);
    if (!file.existsSync()) return;

    final lines = file.readAsLinesSync();
    for (var i = 1; i <= lines.length; i++) {
      final isOld =
          await baselineDate.isOlderThanBaseline(filePath, i, projectRoot: _projectRoot);
      fileCache[i] = isOld;
    }
  }

  // =========================================================================
  // Private: File-based baseline
  // =========================================================================

  /// Check if violation is in the baseline file.
  static bool _checkFileBaseline(String filePath, String ruleName, int line) {
    final baselineFile = _baselineFile;
    if (baselineFile == null) return false;

    return baselineFile.isBaselined(filePath, ruleName, line);
  }

  // =========================================================================
  // Private: Path-based baseline
  // =========================================================================

  /// Check if file path matches any baselined path patterns.
  static bool _checkPathBaseline(String filePath) {
    final baselinePaths = _baselinePaths;
    if (baselinePaths == null || !baselinePaths.hasPatterns) return false;

    final normalizedPath = _normalizePath(filePath);
    return baselinePaths.matches(normalizedPath);
  }

  // =========================================================================
  // Private: Date-based baseline
  // =========================================================================

  /// Check date-based baseline synchronously (from cache).
  static bool _checkDateBaselineSync(String filePath, int line) {
    if (_baselineDate == null) return false;

    final fileCache = _dateCache[filePath];
    if (fileCache == null) return false;

    return fileCache[line] ?? false;
  }

  /// Check date-based baseline asynchronously (runs git blame).
  static Future<bool> _checkDateBaselineAsync(String filePath, int line) async {
    final baselineDate = _baselineDate;
    if (baselineDate == null) return false;

    return baselineDate.isOlderThanBaseline(
      filePath,
      line,
      projectRoot: _projectRoot,
    );
  }

  // =========================================================================
  // Private: Utilities
  // =========================================================================

  /// Resolve a baseline file path relative to project root.
  static String _resolveFilePath(String path) {
    if (_projectRoot != null) {
      final resolved = '$_projectRoot/$path'.replaceAll('\\', '/');
      if (File(resolved).existsSync()) {
        return resolved;
      }
    }
    return path;
  }

  /// Normalize a file path for pattern matching.
  static String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');

    // Remove project root prefix if present
    if (_projectRoot != null) {
      final rootNorm = _projectRoot!.replaceAll('\\', '/');
      if (normalized.startsWith(rootNorm)) {
        normalized = normalized.substring(rootNorm.length);
        if (normalized.startsWith('/')) {
          normalized = normalized.substring(1);
        }
      }
    }

    // Remove leading ./ if present
    if (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }

    return normalized;
  }

  /// Find the project root by looking for pubspec.yaml.
  static String? _findProjectRoot(String startPath) {
    var dir = Directory(startPath);
    while (dir.path != dir.parent.path) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return null;
  }

  // =========================================================================
  // Public: Accessors
  // =========================================================================

  /// Get the current baseline configuration.
  static BaselineConfig? get config => _config;

  /// Get the loaded baseline file.
  static BaselineFile? get baselineFile => _baselineFile;

  /// Get the compiled path patterns.
  static BaselinePaths? get baselinePaths => _baselinePaths;

  /// Get the date-based baseline handler.
  static BaselineDate? get baselineDate => _baselineDate;

  /// Get the project root path.
  static String? get projectRoot => _projectRoot;

  /// Find the project root (public accessor).
  static String? findProjectRoot(String startPath) => _findProjectRoot(startPath);
}
