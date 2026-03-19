import 'dart:io' show Platform, stdout;
import 'dart:typed_data' show Uint64List;

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

  /// Canonical path (normalized separators + platform case rules) -> the
  /// corresponding key in [_rawImports].
  static final Map<String, String> _registeredKeyByCanonical = {};

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
    final timingEnabled =
        Platform.environment['SAROPA_LINTS_IMPORT_GRAPH_TIMING'] == 'true';
    Stopwatch? swResolve;
    if (timingEnabled) {
      swResolve = Stopwatch()..start();
    }

    _buildRegisteredKeyLookup();
    _resolveAllImports();
    swResolve?.stop();

    _buildReverseGraph();
    // _buildReverseGraph is fast; no separate stopwatch.

    Stopwatch? swFanIn;
    if (timingEnabled) {
      swFanIn = Stopwatch()..start();
    }
    _computeFanIn();
    swFanIn?.stop();

    Stopwatch? swClassify;
    if (timingEnabled) {
      swClassify = Stopwatch()..start();
    }
    _classifyLayers();
    swClassify?.stop();

    if (timingEnabled) {
      // Print to stdout so it shows up in unit test logs.
      stdout.writeln(
        'ImportGraphTracker timing: resolve=${swResolve?.elapsedMilliseconds}ms '
        'fanIn=${swFanIn?.elapsedMilliseconds}ms '
        'classify=${swClassify?.elapsedMilliseconds}ms',
      );
    }
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
    _registeredKeyByCanonical.clear();
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
        // Fast path: package self-imports are already library-relative.
        // We only need canonical separator/case matching in lookup.
        final resolved = '$_projectRoot/lib/$relative';
        return _coerceToRegisteredPath(resolved);
      }
      // External package — skip
      return null;
    }

    // External package imports (when no package name known)
    if (uri.startsWith('package:')) return null;

    // Relative imports
    final fromDir = _parentDir(fromFile);
    final candidate = '$fromDir/$uri';
    final needsNormalize =
        uri.contains('../') ||
        uri.contains('/./') ||
        uri.startsWith('./') ||
        uri.startsWith('../');
    final resolved = needsNormalize ? _normalize(candidate) : candidate;
    return _coerceToRegisteredPath(resolved);
  }

  /// Maps a normalized path to the matching key in [_rawImports] so edges
  /// align on Windows (mixed separators in analyzer paths vs `_normalize`).
  static String? _coerceToRegisteredPath(String path) {
    final key = _canonicalPathKey(path);
    return _registeredKeyByCanonical[key];
  }

  static String _canonicalPathKey(String path) {
    final normalized = path.replaceAll('\\', '/');
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static void _buildRegisteredKeyLookup() {
    _registeredKeyByCanonical.clear();
    for (final registered in _rawImports.keys) {
      _registeredKeyByCanonical[_canonicalPathKey(registered)] = registered;
    }
  }

  /// Get parent directory of a file path.
  static String _parentDir(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    return lastSlash >= 0 ? normalized.substring(0, lastSlash) : '.';
  }

  /// Normalize a path: replace backslashes, resolve `.` and `..`.
  static String _normalize(String path) {
    final replaced = path.replaceAll('\\', '/');
    // Fast path: most analyzer-generated paths don't contain `.` or `..`
    // segments. Avoid splitting/iterating in those cases.
    //
    // Note: we intentionally check for `'/./'` and `'/../'` (segment-level),
    // not for '.' in filenames like `foo.dart`.
    final hasDotSegments =
        replaced.contains('/./') ||
        replaced.contains('/../') ||
        replaced.startsWith('./') ||
        replaced.startsWith('../') ||
        replaced.endsWith('/.') ||
        replaced.endsWith('/..') ||
        replaced == '.' ||
        replaced == '..';
    if (!hasDotSegments) return replaced;

    final parts = replaced.split('/');
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
    if (Platform.isWindows && replaced.length >= 2 && replaced[1] == ':') {
      return result;
    }
    return replaced.startsWith('/') ? '/$result' : result;
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
    final files = _rawImports.keys.toList(growable: false);
    final n = files.length;
    if (n == 0) return;

    // Build adjacency list on the reverse graph: fileIndex -> importerIndex.
    final indexOf = <String, int>{};
    for (var i = 0; i < n; i++) {
      indexOf[files[i]] = i;
    }

    final adj = List<List<int>>.generate(n, (_) => <int>[]);
    final directCounts = List<int>.filled(n, 0, growable: false);
    final indegreeNode = List<int>.filled(n, 0, growable: false);
    for (var i = 0; i < n; i++) {
      final file = files[i];
      final importers = _importedBy[file] ?? const <String>{};
      directCounts[i] = importers.length;
      for (final importer in importers) {
        final j = indexOf[importer];
        if (j == null) continue;
        adj[i].add(j);
        indegreeNode[j]++;
      }
    }

    // Fast path: if the reverse graph is acyclic, compute transitive importer
    // sets directly on node-level DAG (faster than SCC condensation).
    final topoNode = <int>[];
    final queueNode = <int>[];
    for (var i = 0; i < n; i++) {
      if (indegreeNode[i] == 0) queueNode.add(i);
    }
    while (queueNode.isNotEmpty) {
      final v = queueNode.removeLast();
      topoNode.add(v);
      for (final w in adj[v]) {
        indegreeNode[w]--;
        if (indegreeNode[w] == 0) queueNode.add(w);
      }
    }
    if (topoNode.length == n) {
      final words = (n + 63) >> 6;
      final reach = List<Uint64List>.generate(n, (_) => Uint64List(words));

      for (final v in topoNode.reversed) {
        final reachV = reach[v];
        for (final w in adj[v]) {
          reachV[w >> 6] |= (1 << (w & 63));
          final reachW = reach[w];
          for (var k = 0; k < words; k++) {
            reachV[k] |= reachW[k];
          }
        }
      }

      for (var i = 0; i < n; i++) {
        var transitiveCount = 0;
        final bits = reach[i];
        for (var w = 0; w < words; w++) {
          transitiveCount += _popcount64(bits[w]);
        }
        final direct = directCounts[i];
        final indirect = transitiveCount - direct;
        _importanceScores[files[i]] =
            direct + (indirect * _transitiveImportWeight);
      }
      return;
    }

    // Fallback: SCC condensation for cyclic graphs.
    final indexArr = List<int>.filled(n, -1, growable: false);
    final lowlink = List<int>.filled(n, 0, growable: false);
    final onStack = List<bool>.filled(n, false, growable: false);
    final stack = <int>[];
    var indexCounter = 0;

    var sccCount = 0;
    final sccId = List<int>.filled(n, -1, growable: false);
    final sccSizes = <int>[];

    void strongconnect(int v) {
      indexArr[v] = indexCounter;
      lowlink[v] = indexCounter;
      indexCounter++;

      stack.add(v);
      onStack[v] = true;

      for (final w in adj[v]) {
        if (indexArr[w] == -1) {
          strongconnect(w);
          // lowlink[v] = min(lowlink[v], lowlink[w])
          if (lowlink[w] < lowlink[v]) lowlink[v] = lowlink[w];
        } else if (onStack[w]) {
          // lowlink[v] = min(lowlink[v], indexArr[w])
          if (indexArr[w] < lowlink[v]) lowlink[v] = indexArr[w];
        }
      }

      if (lowlink[v] == indexArr[v]) {
        var size = 0;
        while (true) {
          final w = stack.removeLast();
          onStack[w] = false;
          sccId[w] = sccCount;
          size++;
          if (w == v) break;
        }
        sccSizes.add(size);
        sccCount++;
      }
    }

    for (var v = 0; v < n; v++) {
      if (indexArr[v] == -1) strongconnect(v);
    }

    // Condensation DAG edges between SCCs.
    // We intentionally allow duplicate edges here: reachability is computed
    // via bitset OR (idempotent), and Kahn's topo sort remains correct as
    // indegrees are decremented per edge occurrence.
    final dag = List<List<int>>.generate(sccCount, (_) => <int>[]);
    final indegree = List<int>.filled(sccCount, 0, growable: false);
    for (var v = 0; v < n; v++) {
      final sv = sccId[v];
      for (final w in adj[v]) {
        final sw = sccId[w];
        if (sv == sw) continue;
        dag[sv].add(sw);
        indegree[sw]++;
      }
    }

    // Topo sort SCC DAG.
    final queue = <int>[];
    for (var s = 0; s < sccCount; s++) {
      if (indegree[s] == 0) queue.add(s);
    }
    final topo = <int>[];
    while (queue.isNotEmpty) {
      final s = queue.removeLast();
      topo.add(s);
      for (final t in dag[s]) {
        indegree[t]--;
        if (indegree[t] == 0) queue.add(t);
      }
    }

    // SCC reachability via DP with bitsets on the SCC DAG.
    final m = sccCount;
    final wordsM = (m + 63) >> 6;
    final reachScc = List<Uint64List>.generate(m, (_) => Uint64List(wordsM));

    for (final s in topo.reversed) {
      final reachS = reachScc[s];
      for (final t in dag[s]) {
        // Include t itself.
        reachS[t >> 6] |= (1 << (t & 63));
        // Include everything t can reach.
        final reachT = reachScc[t];
        for (var w = 0; w < wordsM; w++) {
          reachS[w] |= reachT[w];
        }
      }
    }

    // Compute transitive importer counts per SCC:
    // includes (sccSize - 1) nodes inside SCC (excluding starting node),
    // plus all nodes in reachable other SCCs.
    final reachCountOtherScc = List<int>.filled(m, 0, growable: false);
    for (var s = 0; s < m; s++) {
      var sum = 0;
      final bits = reachScc[s];
      for (var t = 0; t < m; t++) {
        if ((bits[t >> 6] & (1 << (t & 63))) == 0) continue;
        sum += sccSizes[t];
      }
      reachCountOtherScc[s] = sum;
    }

    for (var i = 0; i < n; i++) {
      final file = files[i];
      final s = sccId[i];
      final transitiveCount = (sccSizes[s] - 1) + reachCountOtherScc[s];
      final direct = directCounts[i];
      final indirect = transitiveCount - direct;
      _importanceScores[file] = direct + (indirect * _transitiveImportWeight);
    }
  }

  static int _popcount64(int x) {
    var v = x;
    var count = 0;
    while (v != 0) {
      count += _popcount8[v & 0xFF];
      v = v >>> 8;
    }
    return count;
  }

  static final List<int> _popcount8 = List<int>.generate(256, (i) {
    var v = i;
    var c = 0;
    while (v != 0) {
      v &= v - 1;
      c++;
    }
    return c;
  }, growable: false);

  // ══════════════════════════════════════════════════════════════════
  // Private — Layer Classification
  // ══════════════════════════════════════════════════════════════════

  static void _classifyLayers() {
    final root = _projectRoot;
    final rootPath = root?.replaceAll('\\', '/');

    for (final file in _rawImports.keys) {
      final fileNorm = file.replaceAll('\\', '/');
      final relativePath = rootPath != null && fileNorm.startsWith('$rootPath/')
          ? fileNorm.substring(rootPath.length + 1)
          : fileNorm;

      final (layer, weight) = _classifyFile(relativePath);
      _layers[file] = layer;
      _layerWeights[file] = weight;
    }
  }

  /// Classify a relative file path into an architectural layer.
  static (String, double) _classifyFile(String relativePath) {
    // `relativePath` is already normalized to `/` by `_classifyLayers`.
    // Avoid allocating a lowercase copy when the path is already lowercase.
    final normalized = _toLowerAsciiIfNeeded(relativePath);

    for (final (layer, patterns, weight) in _layerRules) {
      for (final pattern in patterns) {
        if (pattern.endsWith('.dart')) {
          // Filename match (e.g. main.dart)
          if (normalized.endsWith('/$pattern') || normalized == pattern) {
            return (layer, weight);
          }
        } else {
          // Directory match
          if (normalized.contains('/$pattern')) {
            return (layer, weight);
          }
        }
      }
    }
    return ('other', 1.0);
  }

  static String _toLowerAsciiIfNeeded(String value) {
    for (var i = 0; i < value.length; i++) {
      final c = value.codeUnitAt(i);
      if (c >= 0x41 && c <= 0x5A) {
        return value.toLowerCase();
      }
    }
    return value;
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
