import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import '../native/plugin_logger.dart';
import '../project_context.dart' show ProjectContext;

import 'baseline_config.dart';
import 'baseline_date.dart';
import 'baseline_file.dart';
import 'baseline_paths.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Returns the baseline configuration of the project at [projectRoot], or
/// null when that project configures none.
typedef BaselineConfigReader = BaselineConfig? Function(String projectRoot);

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
/// Top-level key in `analysis_options_custom.yaml` at the project root (the
/// only place the config loader reads it; see `baseline_activation.dart`):
///
/// ```yaml
/// baseline:
///   file: "saropa_baseline.json"    # Specific violations
///   date: "2025-01-15"              # Code unchanged since this date
///   paths:                          # Directories/patterns
///     - "lib/legacy/"
///     - "**/generated/"
///   only_impacts: [info, warning]   # Only baseline these severities
/// ```
///
/// Trailing comments and inline `[a, b]` lists, as above, are handled by
/// `baseline_section_parser.dart`.
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

  /// State set by [initialize]: one project, used by CLIs and tests.
  static _BaselineState? _single;

  /// Reader set by [enablePerRoot]; non-null switches lookups to per-project.
  static BaselineConfigReader? _reader;

  /// Per-project states loaded so far; a null value records "no baseline".
  static final Map<String, _BaselineState?> _byRoot = {};

  /// Preloaded date answers (cutoff + file -> line -> isOld).
  ///
  /// Held here, not on a project state, so a config reload cannot discard
  /// them: states are rebuilt from disk, blame answers stay valid. The
  /// cutoff is part of the key, so an edited `date:` never reads old answers.
  static final Map<(DateTime, String), Map<int, bool>> _dateCache = {};

  /// Initialize the baseline manager with configuration.
  ///
  /// Should be called once during plugin initialization.
  /// [projectRoot] is optional - will auto-detect from pubspec.yaml if not provided.
  static void initialize(BaselineConfig config, {String? projectRoot}) {
    _single = _BaselineState(
      config,
      projectRoot ?? _findProjectRoot(Directory.current.path),
    );
  }

  /// Makes every lookup use the analyzed file's own project baseline.
  ///
  /// Why: one analysis server hosts several project roots, but configuration
  /// is loaded once, so a single global baseline applied the first (or last)
  /// loaded project's `paths:` and JSON entries to every other project. A
  /// `lib/a.dart` entry could then hide a finding in an unrelated package.
  static void enablePerRoot(BaselineConfigReader reader) {
    _reader = reader;
    _byRoot.clear();
  }

  /// Clear the baseline manager, configuration and caches (tests).
  static void reset() {
    resetConfig();
    _dateCache.clear();
    BaselineDate.clearCache();
  }

  /// Forget the configuration before a reload, keeping git blame answers.
  ///
  /// The plugin reloads lazily once the real project root is known. Using
  /// [reset] there threw away blame data already preloaded, and the sync
  /// date check then silently stopped matching.
  static void resetConfig() {
    _single = null;
    _reader = null;
    _byRoot.clear();
  }

  /// Whether any baseline can apply. In per-project mode this is true even
  /// before a project is loaded, since only the lookup knows the project.
  static bool get isEnabled =>
      _reader != null || (_single?.config.isEnabled ?? false);

  /// The state that governs [filePath]. In per-project mode this is the
  /// nearest enclosing package that configures a baseline, so a nested
  /// package without one (`example/`) keeps inheriting its parent's, while
  /// a sibling project never sees it.
  static _BaselineState? _stateFor(String filePath) {
    final reader = _reader;
    if (reader == null) return _single;
    var root = ProjectContext.findProjectRoot(filePath);
    while (root != null) {
      final current = root;
      final state = _byRoot.putIfAbsent(current, () {
        final config = reader(current);
        return config == null ? null : _BaselineState(config, current);
      });
      if (state != null) return state;
      // The lookup starts at its argument's parent, so this climbs one level.
      root = ProjectContext.findProjectRoot(current);
    }
    return null;
  }

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
  /// Returns false if [filePath], [ruleName] are null/empty or [line] < 1.
  static bool isBaselined(
    String? filePath,
    String? ruleName,
    int line, {
    String? impact,
  }) {
    if (filePath == null || filePath.isEmpty) return false;
    if (ruleName == null || ruleName.isEmpty) return false;
    if (line < 1) return false;

    final state = _stateFor(filePath);
    if (state == null || !state.config.isEnabled) {
      return false;
    }
    final config = state.config;

    // Check impact filter first (only_impacts configuration)
    if (impact != null && !config.shouldBaselineImpact(impact)) {
      return false;
    }

    // Check file-based baseline
    if (state.matchesFile(filePath, ruleName, line)) {
      return true;
    }

    // Check path-based baseline
    if (state.matchesPath(filePath)) {
      return true;
    }

    // Check date-based baseline (from cache)
    if (state.isOldCached(filePath, line)) {
      return true;
    }

    return false;
  }

  /// Check if a violation should be suppressed (async version with full date support).
  ///
  /// This version runs git blame if needed. Use for CLI tools or when
  /// async operations are acceptable.
  /// Returns false if [filePath], [ruleName] are null/empty or [line] < 1.
  static Future<bool> isBaselinedAsync(
    String? filePath,
    String? ruleName,
    int line, {
    String? impact,
  }) async {
    if (filePath == null || filePath.isEmpty) return false;
    if (ruleName == null || ruleName.isEmpty) return false;
    if (line < 1) return false;

    final state = _stateFor(filePath);
    if (state == null || !state.config.isEnabled) {
      return false;
    }
    final config = state.config;

    // Check impact filter first
    if (impact != null && !config.shouldBaselineImpact(impact)) {
      return false;
    }

    // Check file-based baseline
    if (state.matchesFile(filePath, ruleName, line)) {
      return true;
    }

    // Check path-based baseline
    if (state.matchesPath(filePath)) {
      return true;
    }

    // Check date-based baseline (with git blame)
    if (await state.isOld(filePath, line)) {
      return true;
    }

    return false;
  }

  /// Preload date-based baseline data for a file.
  ///
  /// Call this before analyzing a file to enable date-based baseline checks.
  /// This runs `git blame` once for the file and caches all line dates.
  /// No-op if [filePath] is null or empty.
  static Future<void> preloadDateBaseline(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return;

    final state = _stateFor(filePath);
    final baselineDate = state?.date;
    if (state == null || baselineDate == null) return;

    try {
      await baselineDate.preloadFile(filePath, projectRoot: state.root);
      // Catch Object explicitly: bare `catch` swallows OutOfMemoryError /
      // StackOverflowError silently. Object is intentional here — this is a
      // best-effort preload and ANY failure should fall back to "no date
      // baseline for this file" rather than tear down the analyzer plugin.
    } on Object catch (e, st) {
      developer.log(
        'baseline preloadFile failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return;
    }

    // Also populate our sync cache
    final fileCache = _dateCache.putIfAbsent((
      baselineDate.baselineDate,
      filePath,
    ), () => {});
    try {
      // Async I/O here: this method is already async and runs from the
      // analyzer plugin's per-file preload. Sync I/O (existsSync /
      // readAsLinesSync) would block the analysis isolate and trip
      // avoid_blocking_main_thread on Flutter consumers of the plugin.
      final file = File(filePath);
      if (!await file.exists()) return;

      final lines = await file.readAsLines();
      for (var i = 1; i <= lines.length; i++) {
        final isOld = await baselineDate.isOlderThanBaseline(
          filePath,
          i,
          projectRoot: state.root,
        );
        fileCache[i] = isOld;
      }
      // See preloadFile catch above for why this is `on Object` and not bare.
    } on Object catch (e, st) {
      developer.log(
        'baseline date cache read failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // File read or blame failed; sync cache stays empty
    }
  }

  /// Which settings of [filePath]'s baseline match that file, using the same
  /// matchers as [isBaselined]. Null when no baseline governs the file.
  ///
  /// Findings are not needed: path patterns, JSON entries and line ages are
  /// properties of the file, so this answers without running analysis.
  static Future<BaselineExplanation?> explain(String filePath) async {
    final state = _stateFor(filePath);
    if (state == null || !state.config.isEnabled) return null;
    final relative = state._normalizePath(filePath);
    return BaselineExplanation(
      config: state.config,
      root: state.root,
      relativePath: relative,
      matchedPatterns: [
        for (final pattern in state.config.paths)
          if (BaselinePaths([pattern]).matches(relative)) pattern,
      ],
      fileLoaded: state.file != null,
      fileEntries: state.file?.entriesFor(filePath) ?? const {},
      oldLines: await state.date?.oldLines(filePath, projectRoot: state.root),
    );
  }

  // =========================================================================
  // Private: Utilities
  // =========================================================================

  /// Find the project root by looking for pubspec.yaml.
  static String? _findProjectRoot(String? startPath) {
    if (startPath == null || startPath.isEmpty) return null;
    try {
      var dir = Directory(startPath);
      while (dir.path != dir.parent.path) {
        // FileSystemEntity.isFileSync instead of File.existsSync: same
        // reasoning as _resolveFilePath — sync init contract requires
        // sync I/O here, and isFileSync sidesteps avoid_blocking_main_thread
        // while being semantically tighter (pubspec.yaml must be a file,
        // not a directory).
        final pubspecPath = '${dir.path}/pubspec.yaml';
        if (FileSystemEntity.isFileSync(pubspecPath)) {
          return dir.path;
        }
        dir = dir.parent;
      }
      // `on Object` over bare catch: never let directory walk failures
      // (permissions, broken symlinks) crash the plugin — we just return
      // null and the caller falls back to Directory.current.
    } on Object catch (e, st) {
      developer.log(
        '_findProjectRoot failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  // =========================================================================
  // Public: Accessors
  // =========================================================================

  // The accessors below describe the [initialize]d project only; they serve
  // the violation export, the config loader and tests.

  /// Get the current baseline configuration.
  static BaselineConfig? get config => _single?.config;

  /// Get the loaded baseline file.
  static BaselineFile? get baselineFile => _single?.file;

  /// Get the compiled path patterns.
  static BaselinePaths? get baselinePaths => _single?.paths;

  /// Get the date-based baseline handler.
  static BaselineDate? get baselineDate => _single?.date;

  /// Get the project root path.
  static String? get projectRoot => _single?.root;

  /// Find the project root (public accessor).
  static String? findProjectRoot(String? startPath) =>
      _findProjectRoot(startPath);
}

/// What [BaselineManager.explain] found for one file.
class BaselineExplanation {
  const BaselineExplanation({
    required this.config,
    required this.root,
    required this.relativePath,
    required this.matchedPatterns,
    required this.fileLoaded,
    required this.fileEntries,
    required this.oldLines,
  });

  /// The governing project's baseline configuration.
  final BaselineConfig config;

  /// Root of the governing project.
  final String? root;

  /// The file as path patterns see it.
  final String relativePath;

  /// `paths:` entries that match the file.
  final List<String> matchedPatterns;

  /// Whether the configured baseline JSON was read.
  final bool fileLoaded;

  /// Baseline JSON entries for the file: rule -> lines.
  final Map<String, List<int>> fileEntries;

  /// Lines older than `date:`; null when `date:` is unset or git blame
  /// gave no answer.
  final List<int>? oldLines;
}

/// One project's loaded baseline: its configuration, JSON entries, path
/// patterns and date cache, all resolved against [root].
class _BaselineState {
  _BaselineState(this.config, this.root)
    : paths = config.paths.isEmpty ? null : BaselinePaths(config.paths),
      date = config.date == null ? null : BaselineDate(config.date!) {
    final name = config.file;
    if (name == null) return;
    file = BaselineFile.load(_resolveFilePath(name));
    // A configured file that did not load looks exactly like "baseline
    // active, nothing matched", so say so in the plugin log.
    if (file == null) {
      PluginLogger.warning(
        'Baseline file "$name" not found or unreadable under '
        '${root ?? Directory.current.path}; no file-based baseline applied.',
      );
    }
  }

  final BaselineConfig config;
  final String? root;
  final BaselinePaths? paths;
  final BaselineDate? date;
  BaselineFile? file;

  /// Whether the violation is listed in the baseline JSON.
  bool matchesFile(String filePath, String ruleName, int line) =>
      file?.isBaselined(filePath, ruleName, line) ?? false;

  /// Whether [filePath] matches a baselined path pattern.
  bool matchesPath(String filePath) {
    final patterns = paths;
    if (patterns == null || !patterns.hasPatterns) return false;
    return patterns.matches(_normalizePath(filePath));
  }

  /// Date check from the preloaded cache; false when not preloaded.
  bool isOldCached(String filePath, int line) {
    final cutoff = date?.baselineDate;
    if (cutoff == null) return false;
    return BaselineManager._dateCache[(cutoff, filePath)]?[line] ?? false;
  }

  /// Date check that runs git blame when needed.
  Future<bool> isOld(String filePath, int line) async {
    final baselineDate = date;
    if (baselineDate == null) return false;
    return baselineDate.isOlderThanBaseline(filePath, line, projectRoot: root);
  }

  /// Resolve a baseline file path relative to project root.
  String _resolveFilePath(String path) {
    final base = root;
    // The bare path is correct only when it is absolute or there is no root.
    // A relative path must never fall back to the bare form when it is missing
    // under [root]: it would then resolve against the process working
    // directory and could load another project's baseline.
    if (base == null || p.isAbsolute(path)) return path;
    // A missing file is left to BaselineFile.load, which returns null.
    return '$base/$path'.replaceAll('\\', '/');
  }

  /// Normalize a file path for pattern matching: forward slashes, relative
  /// to [root].
  String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    final base = root?.replaceAll('\\', '/');
    if (base != null && normalized.startsWith(base)) {
      normalized = normalized.afterIndex(base.length);
      if (normalized.startsWith('/')) normalized = normalized.afterIndex(1);
    }
    if (normalized.startsWith('./')) normalized = normalized.afterIndex(2);
    return normalized;
  }
}
