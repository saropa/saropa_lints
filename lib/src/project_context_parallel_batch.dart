part of 'project_context.dart';

// PARALLEL ANALYSIS (Performance Optimization)
// =============================================================================
//
// Provides parallel pre-analysis capabilities using Dart isolates. Since the
// analysis framework controls rule execution order, we can't parallelize
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
    final fp = map['filePath'];
    final ch = map['contentHash'];
    final lc = map['lineCount'];
    final cc = map['characterCount'];
    final ic = map['importCount'];
    final clc = map['classCount'];
    final fc = map['functionCount'];
    final ha = map['hasAsyncCode'];
    final hw = map['hasWidgets'];
    final hf = map['hasFlutterImport'];
    final hb = map['hasBlocImport'];
    final hp = map['hasProviderImport'];
    final hr = map['hasRiverpodImport'];
    final fpr = map['fingerprint'];
    final ft = map['fileTypes'];
    final mp = map['matchingPatterns'];
    if (fp is! String ||
        ch is! int ||
        lc is! int ||
        cc is! int ||
        ic is! int ||
        clc is! int ||
        fc is! int ||
        ha is! bool ||
        hw is! bool ||
        fpr is! int ||
        ft is! List ||
        mp is! List) {
      throw ArgumentError('Invalid ParallelAnalysisResult map');
    }
    return ParallelAnalysisResult(
      filePath: fp,
      contentHash: ch,
      metrics: FileMetrics(
        lineCount: lc,
        characterCount: cc,
        importCount: ic,
        classCount: clc,
        functionCount: fc,
        hasAsyncCode: ha,
        hasWidgets: hw,
        hasFlutterImport: hf is bool ? hf : false,
        hasBlocImport: hb is bool ? hb : false,
        hasProviderImport: hp is bool ? hp : false,
        hasRiverpodImport: hr is bool ? hr : false,
      ),
      fingerprint: fpr,
      fileTypes: ft
          .map<FileType>((e) => FileType.values[e is int ? e : 0])
          .toSet(),
      matchingPatterns: mp.cast<String>().toSet(),
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
  static bool _isInitialized = false;
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
  static Future<void> initialize({int? workerCount, bool useIsolates = true}) {
    if (_isInitialized) return Future.value();

    // Determine worker count (default: CPU cores - 1, min 1, max 8)
    _workerCount = workerCount ?? _getDefaultWorkerCount();
    _useIsolates = useIsolates;
    _isInitialized = true;
    return Future.value();
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
    // ignore: avoid_redundant_async
    required List<String> filePaths,
    required Set<String> patterns,
  }) async {
    if (!_isInitialized || _workerCount <= 1) {
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
      batches.add(
        uncached.sublist(i, (i + batchSize).clamp(0, uncached.length)),
      );
    }

    if (_useIsolates && batches.length > 1) {
      // Process batches in parallel using isolates
      final futures = batches.map(
        (batch) => _processBatchInIsolate(batch, patterns.toList()),
      );
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
    } on IsolateSpawnException catch (e, st) {
      developer.log(
        'isolate/spawn failed, falling back to sync',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      _syncTasksRun++;
      return await _processBatch(filePaths, patterns.toSet());
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
      } on IOException catch (e, st) {
        developer.log(
          '_analyzeFilesInIsolate file read failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be read
      } on FormatException catch (e, st) {
        developer.log(
          '_analyzeFilesInIsolate parse failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be parsed
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
      } on IOException catch (e, st) {
        developer.log(
          '_processBatch file read failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be read
      } on FormatException catch (e, st) {
        developer.log(
          '_processBatch parse failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be parsed
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
      } on IOException catch (e, st) {
        developer.log(
          '_analyzeFilesSync file read failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be read
      } on FormatException catch (e, st) {
        developer.log(
          '_analyzeFilesSync parse failed',
          name: 'saropa_lints',
          error: e,
          stackTrace: st,
        );
        // Skip files that can't be parsed
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

  static final RegExp _functionLikeLine = RegExp(r'^\s*\w+\s+\w+\s*\(');

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
      if (trimmed.contains(' Function') || _functionLikeLine.hasMatch(line)) {
        functionCount++;
      }
    }

    // Package import detection
    final hasFlutterImport = content.contains('package:flutter/');
    final hasBlocImport =
        content.contains('package:bloc/') ||
        content.contains('package:flutter_bloc/');
    final hasProviderImport = content.contains('package:provider/');
    final hasRiverpodImport =
        content.contains('package:riverpod/') ||
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
    FileTypeDetector._cache.putIfAbsent(
      result.filePath,
      () => result.fileTypes,
    );
    ContentFingerprint._cache.putIfAbsent(
      result.filePath,
      () => result.fingerprint,
    );
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
      'initialized': _isInitialized,
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
// While the analysis framework controls actual rule invocation, this
// allows pre-computation and result caching for rules that can be batched.
// =============================================================================

/// Information about a rule for batch execution planning.
class BatchableRuleInfo {
  const BatchableRuleInfo({
    required this.name,
    required this.cost,
    required this.requiredPatterns,
    required this.applicableFileTypes,
    required this.isAsyncRequired,
    required this.isWidgetsRequired,
    this.dependencies = const {},
  });

  final String name;
  final RuleCost cost;
  final Set<String>? requiredPatterns;
  final Set<FileType>? applicableFileTypes;
  final bool isAsyncRequired;
  final bool isWidgetsRequired;
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
    if (isAsyncRequired && !analysis.metrics.hasAsyncCode) {
      return false;
    }

    // Check widget requirement
    if (isWidgetsRequired && !analysis.metrics.hasWidgets) {
      return false;
    }

    // Check required patterns
    if (requiredPatterns != null && requiredPatterns!.isNotEmpty) {
      if (!requiredPatterns!.any(
        (p) => analysis.matchingPatterns.contains(p),
      )) {
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
