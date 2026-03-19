import 'dart:io' show Platform;

import 'package:saropa_lints/src/project_context.dart' show ProjectContext;
import 'package:saropa_lints/src/saropa_lint_rule.dart' show LintImpact;

/// Numeric weights for [LintImpact] used in priority scoring.
extension _LintImpactNumeric on LintImpact {
  /// Numeric value for priority calculations.
  double get numericValue => switch (this) {
    LintImpact.critical => 5.0,
    LintImpact.high => 4.0,
    LintImpact.medium => 2.0,
    LintImpact.low => 1.0,
    LintImpact.opinionated => 0.5,
  };
}

/// Collects import edges during analysis and computes file importance
/// scores at report time.
///
/// Call [collectImports] once per file during analysis (wired from
/// `SaropaContext`, immediately after progress records the file path).
/// Call [compute] once before rendering the report to resolve imports,
/// build the graph, and calculate scores.
///
/// **Multi-isolate:** Each isolate collects imports in memory; snapshots are
/// written in batch JSON (`rawImportsByFile`) and merged when building the
/// consolidated report, so the graph spans all isolates in the session.
/// Falls back to in-memory data only when batch files omit import snapshots
/// (legacy batches).
class ImportGraphTracker {
  ImportGraphTracker._();

  // ── Collection phase (during analysis) ──

  /// Raw import/export URIs extracted from each file.
  static final Map<String, Set<String>> _rawImports = {};

  // ── Computation phase (at report time) ──

  /// Resolved absolute paths this file imports.
  static final Map<String, Set<String>> _importsOf = {};

  /// Reverse graph: files that import this file.
  static final Map<String, Set<String>> _importedBy = {};

  /// Computed importance scores (fan-in based).
  static final Map<String, double> _importanceScores = {};

  /// Layer classifications.
  static final Map<String, String> _layers = {};

  /// Layer weights.
  static final Map<String, double> _layerWeights = {};

  static bool _isComputed = false;
  static String? _projectRoot;
  static String? _packageName;

  /// Weight applied to indirect (transitive) importers in fan-in scoring.
  static const _transitiveImportWeight = 0.3;

  // ── Regex patterns ──

  /// Matches `import 'uri';` and `import "uri";` (with optional show/hide).
  static final _importExportRe = RegExp(
    r'''(?:import|export)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Layer classification rules: first match wins.
  static const _layerRules = <(String, List<String>, double)>[
    ('entry', ['main.dart'], 5.0),
    ('routing', ['routes/', 'router/', 'navigation/'], 4.0),
    ('state', ['bloc/', 'provider/', 'riverpod/', 'store/', 'cubit/'], 4.0),
    ('data', ['database/', 'repository/', 'api/', 'service/'], 3.0),
    ('shared', ['components/', 'widgets/', 'shared/', 'common/'], 3.0),
    ('screen', ['views/', 'screens/', 'pages/', 'features/'], 2.0),
    ('utility', ['utils/', 'helpers/', 'extensions/', 'config/'], 2.0),
    ('model', ['models/', 'entities/', 'dto/'], 1.0),
    ('test', ['test/'], 0.5),
  ];

  // ══════════════════════════════════════════════════════════════════
  // Public API — Collection
  // ══════════════════════════════════════════════════════════════════

  /// Set project root and package name for import resolution.
  static void setProjectInfo(String projectRoot, String packageName) {
    _projectRoot = projectRoot;
    _packageName = packageName;
  }

  /// Extract import/export URIs from [content] for [filePath].
  ///
  /// Runs at most once per path (map guard). Invoked from
  /// `SaropaContext._shouldSkipCurrentFile` immediately after
  /// `ProgressTracker.recordFile` so graph data uses the same unit content
  /// as the analyzer (no extra I/O).
  ///
  /// If [setProjectInfo] was not called yet (e.g. progress reporting
  /// disabled so `AnalysisReporter.initialize` never ran), infers root and
  /// package name from [filePath] once.
  static void collectImports(String filePath, String content) {
    if (_projectRoot == null) {
      final root = ProjectContext.findProjectRoot(filePath);
      if (root != null && root.isNotEmpty) {
        setProjectInfo(root, ProjectContext.getPackageName(root));
      }
    }
    if (_rawImports.containsKey(filePath)) return;
    final uris = <String>{};
    for (final match in _importExportRe.allMatches(content)) {
      final uri = match.group(1);
      if (uri != null) uris.add(uri);
    }
    _rawImports[filePath] = uris;
  }

  // ══════════════════════════════════════════════════════════════════
  // Public API — Computation
  // ══════════════════════════════════════════════════════════════════

  /// Resolve imports, build graph, and compute all scores.
  ///
  /// Idempotent — subsequent calls are no-ops until [reset].
  static void compute() {
    if (_isComputed) return;
    _isComputed = true;

    _resolveAllImports();
    _buildReverseGraph();
    _computeFanIn();
    _classifyLayers();
  }

  // ══════════════════════════════════════════════════════════════════
  // Public API — Getters
  // ══════════════════════════════════════════════════════════════════

  /// All files seen during analysis.
  static Set<String> get allFiles => Set.unmodifiable(_rawImports.keys.toSet());

  /// Total import edges in the resolved graph.
  static int get totalEdges =>
      _importsOf.values.fold(0, (s, v) => s + v.length);

  /// Files that [path] imports (fan-out).
  static Set<String> importsOf(String path) {
    final key = _canonicalTrackedPath(path);
    return _importsOf[key ?? path] ?? const <String>{};
  }

  /// Files that import [path] (fan-in).
  static Set<String> importersOf(String path) {
    final key = _canonicalTrackedPath(path);
    return _importedBy[key ?? path] ?? const <String>{};
  }

  /// Computed importance score for [path] (relative or absolute file path).
  static double getImportance(String path) {
    final key = _canonicalTrackedPath(path);
    return _importanceScores[key ?? path] ?? 0.0;
  }

  /// Layer name for [path] (e.g. 'data', 'screen', 'utility').
  static String getLayer(String path) {
    final key = _canonicalTrackedPath(path);
    return _layers[key ?? path] ?? 'other';
  }

  /// Numeric layer weight for [path].
  static double getLayerWeight(String path) {
    final key = _canonicalTrackedPath(path);
    return _layerWeights[key ?? path] ?? 1.0;
  }

  /// Combined priority score for a violation in [path] with [impact].
  ///
  /// [path] may be project-relative (as in consolidated reports) or absolute;
  /// it is matched to internal graph keys via [_canonicalTrackedPath].
  static double getPriority(String path, LintImpact impact) {
    final key = _canonicalTrackedPath(path);
    final k = key ?? path;
    final importance = _importanceScores[k] ?? 0.0;
    final layerWeight = _layerWeights[k] ?? 1.0;
    return impact.numericValue * (importance + 1) * layerWeight;
  }

  /// Issue count per file from [ProgressTracker] data.
  static int getIssueCount(String path, Map<String, int> issuesByFile) =>
      issuesByFile[path] ?? 0;

  /// File importance score for ranking (without lint impact).
  static double getFileScore(String path) {
    final key = _canonicalTrackedPath(path);
    final k = key ?? path;
    final imp = _importanceScores[k] ?? 0.0;
    final w = _layerWeights[k] ?? 1.0;
    return (imp + 1) * w;
  }

  /// Issue count for a graph file path against [issuesByFile] keys (often
  /// project-relative after consolidation).
  static int lookupIssuesForGraphPath(
    Map<String, int> issuesByFile,
    String graphKey,
  ) {
    final rel = _toRelative(graphKey);
    return issuesByFile[rel] ??
        issuesByFile[graphKey] ??
        issuesByFile[graphKey.replaceAll('\\', '/')] ??
        0;
  }

  /// Serializable copy of raw import URIs per file for batch JSON.
  static Map<String, List<String>> snapshotRawImportsForBatch() => {
    for (final e in _rawImports.entries) e.key: e.value.toList(),
  };

  /// Replace collected imports with a merged snapshot from all isolates,
  /// then recompute on next [compute]. Clears derived graph state only.
  static void applyMergedImportSnapshot(Map<String, List<String>> merged) {
    reset();
    for (final e in merged.entries) {
      _rawImports[e.key] = e.value.toSet();
    }
  }

  /// Maps consolidated / relative paths to internal absolute graph keys.
  static String? _canonicalTrackedPath(String path) {
    if (path.isEmpty) return null;
    if (_rawImports.containsKey(path)) return path;
    final norm = path.replaceAll('\\', '/');
    for (final k in _rawImports.keys) {
      if (_toRelative(k) == norm) return k;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════
  // Reset
  // ══════════════════════════════════════════════════════════════════

  /// Clear all state for a new analysis session.
  static void reset() {
    _rawImports.clear();
    _importsOf.clear();
    _importedBy.clear();
    _importanceScores.clear();
    _layers.clear();
    _layerWeights.clear();
    _isComputed = false;
    // Keep _projectRoot and _packageName — they're config, not state.
  }

  // ══════════════════════════════════════════════════════════════════
  // Private — Import Resolution
  // ══════════════════════════════════════════════════════════════════

  static void _resolveAllImports() {
    for (final entry in _rawImports.entries) {
      final filePath = entry.key;
      final resolved = <String>{};
      for (final uri in entry.value) {
        final abs = _resolveUri(uri, filePath);
        if (abs != null) resolved.add(abs);
      }
      _importsOf[filePath] = resolved;
    }
  }

  /// Resolve an import URI to an absolute file path, or null if external.
  static String? _resolveUri(String uri, String fromFile) {
    // Skip SDK imports
    if (uri.startsWith('dart:')) return null;

    // Self-package imports
    if (uri.startsWith('package:') && _packageName != null) {
      final prefix = 'package:$_packageName/';
      if (uri.startsWith(prefix)) {
        final relative = uri.substring(prefix.length);
        final resolved = _normalize('$_projectRoot/lib/$relative');
        return _coerceToRegisteredPath(resolved);
      }
      // External package — skip
      return null;
    }

    // External package imports (when no package name known)
    if (uri.startsWith('package:')) return null;

    // Relative imports
    final fromDir = _parentDir(fromFile);
    final resolved = _normalize('$fromDir/$uri');
    return _coerceToRegisteredPath(resolved);
  }

  /// Maps a normalized path to the matching key in [_rawImports] so edges
  /// align on Windows (mixed separators in analyzer paths vs [_normalize]).
  static String? _coerceToRegisteredPath(String path) {
    for (final k in _rawImports.keys) {
      if (_pathsSameFile(k, path)) return k;
    }
    return null;
  }

  static bool _pathsSameFile(String a, String b) {
    final na = a.replaceAll('\\', '/');
    final nb = b.replaceAll('\\', '/');
    if (na == nb) return true;
    if (Platform.isWindows && na.toLowerCase() == nb.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Get parent directory of a file path.
  static String _parentDir(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    return lastSlash >= 0 ? normalized.substring(0, lastSlash) : '.';
  }

  /// Normalize a path: replace backslashes, resolve `.` and `..`.
  static String _normalize(String path) {
    final parts = path.replaceAll('\\', '/').split('/');
    final normalized = <String>[];
    for (final part in parts) {
      if (part == '..') {
        if (normalized.isNotEmpty) normalized.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        normalized.add(part);
      }
    }
    // Preserve drive letter on Windows (e.g. D:)
    final result = normalized.join('/');
    if (Platform.isWindows && path.length >= 2 && path[1] == ':') {
      return result;
    }
    return path.startsWith('/') ? '/$result' : result;
  }

  // ══════════════════════════════════════════════════════════════════
  // Private — Graph Building
  // ══════════════════════════════════════════════════════════════════

  static void _buildReverseGraph() {
    // Initialize every known file
    for (final file in _rawImports.keys) {
      _importedBy.putIfAbsent(file, () => <String>{});
    }
    // Build reverse edges
    for (final entry in _importsOf.entries) {
      for (final target in entry.value) {
        (_importedBy[target] ??= <String>{}).add(entry.key);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // Private — Fan-in Scoring
  // ══════════════════════════════════════════════════════════════════

  static void _computeFanIn() {
    for (final file in _rawImports.keys) {
      final direct = (_importedBy[file] ?? const <String>{}).length;
      final indirect = _countTransitiveImporters(file) - direct;
      _importanceScores[file] = direct + (indirect * _transitiveImportWeight);
    }
  }

  /// Count all transitive importers of [file] via BFS.
  static int _countTransitiveImporters(String file) {
    final visited = <String>{file};
    final queue = <String>[...(_importedBy[file] ?? const <String>{})];
    var count = 0;
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (!visited.add(current)) continue;
      count++;
      final importers = _importedBy[current];
      if (importers != null) queue.addAll(importers);
    }
    return count;
  }

  // ══════════════════════════════════════════════════════════════════
  // Private — Layer Classification
  // ══════════════════════════════════════════════════════════════════

  static void _classifyLayers() {
    for (final file in _rawImports.keys) {
      final relativePath = _toRelative(file);
      final (layer, weight) = _classifyFile(relativePath);
      _layers[file] = layer;
      _layerWeights[file] = weight;
    }
  }

  /// Classify a relative file path into an architectural layer.
  static (String, double) _classifyFile(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/').toLowerCase();

    for (final (layer, patterns, weight) in _layerRules) {
      for (final pattern in patterns) {
        if (pattern.endsWith('.dart')) {
          // Filename match (e.g. main.dart)
          if (normalized.endsWith('/$pattern') ||
              normalized == pattern ||
              normalized.endsWith(pattern)) {
            return (layer, weight);
          }
        } else {
          // Directory match
          if (normalized.contains('/$pattern') ||
              normalized.startsWith(pattern)) {
            return (layer, weight);
          }
        }
      }
    }
    return ('other', 1.0);
  }

  /// Convert an absolute path to relative (from project root).
  static String _toRelative(String filePath) {
    final root = _projectRoot;
    if (root == null) return filePath;
    final rootPath = root.replaceAll('\\', '/');
    final file = filePath.replaceAll('\\', '/');
    if (file.startsWith('$rootPath/')) {
      return file.substring(rootPath.length + 1);
    }
    return filePath;
  }
}
