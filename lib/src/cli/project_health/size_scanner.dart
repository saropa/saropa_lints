/// Streaming, memory-safe size scanner (Project Health, size increment).
///
/// Walks the project once, and for EACH file reads its content, computes the
/// size/LOC profile, folds it into the bounded [HealthAggregator], hands the
/// row to [SizeScanOptions.onRow] (the NDJSON sink), then lets it go out of
/// scope. Only one file's content is ever held in memory — the all-files
/// content map used elsewhere in the CLI is deliberately NOT replicated here.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;

import 'class_metrics.dart';
import 'complexity_scanner.dart';
import 'coupling_metrics.dart';
import 'doc_coverage.dart';
import 'git_signals.dart';
import 'health_cache.dart';
import 'health_aggregator.dart';
import 'health_model.dart';
import 'line_metrics.dart';
import 'maintainability_index.dart';
import 'metrics_model.dart';

/// Directory names whose subtrees never count toward project size (build
/// artifacts, VCS internals, tool caches) — they are not source the developer
/// owns and would dominate the size map with noise.
const Set<String> _excludedDirs = {
  '.git',
  '.dart_tool',
  'build',
  '.fvm',
  '.symlinks',
  'Pods',
};

/// Options for [runSizeScan]. Grouped into one object so new criteria extend
/// this struct rather than growing the function's parameter list.
class SizeScanOptions {
  const SizeScanOptions({
    required this.projectPath,
    this.excludeGlobs = const [],
    this.topN = 25,
    this.onRow,
    this.withComplexity = false,
    this.unusedFiles,
    this.deadSymbols,
    this.coverage,
    this.gitSignals,
    this.coupling,
    this.complexityCache,
    this.cacheSink,
  });

  final String projectPath;

  /// Extra glob patterns (matched against project-relative posix paths).
  final List<String> excludeGlobs;

  final int topN;

  /// Per-file sink for streaming rows to disk (NDJSON). Null = aggregate only.
  final void Function(FileHealth row)? onRow;

  /// When true, also compute per-file complexity + Maintainability Index
  /// (one extra parse per file; opt-in so the size-only scan stays fast).
  final bool withComplexity;

  // Optional overlays precomputed before the walk and attached per file. Each is
  // keyed by project-relative posix path. Null = that section did not run.
  final Set<String>? unusedFiles;
  final Map<String, int>? deadSymbols;
  final Map<String, double>? coverage;
  final Map<String, GitSignal>? gitSignals;
  final Map<String, Coupling>? coupling;

  /// Prior-run cache: reuse complexity for files whose content hash is unchanged.
  final Map<String, CacheEntry>? complexityCache;

  /// Mutable sink the scan fills with the current run's cache (hits carried
  /// forward, misses recomputed) for the caller to persist.
  final Map<String, CacheEntry>? cacheSink;
}

/// Scans `.dart` files under [SizeScanOptions.projectPath] and returns the
/// populated aggregate. Heavy work is async so the caller (and any host
/// process) stays responsive.
Future<HealthAggregator> runSizeScan(SizeScanOptions options) async {
  final root = options.projectPath;
  final excludes = options.excludeGlobs
      .map(_globToRegExp)
      .toList(growable: false);
  final agg = HealthAggregator(topN: options.topN);

  final dir = Directory(root);
  if (!dir.existsSync()) return agg;

  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = p.relative(entity.path, from: root).replaceAll('\\', '/');
    if (_hasExcludedSegment(rel)) continue;
    if (excludes.any((re) => re.hasMatch(rel))) continue;
    final row = await _measure(entity, rel, options);
    if (row == null) continue;
    agg.add(row);
    options.onRow?.call(row);
  }
  return agg;
}

/// Reads one file and builds its [FileHealth], or null if it cannot be read.
/// Content is local and released on return — no caching. Attaches any
/// precomputed overlays (dead-weight, coverage, git) by relative path.
Future<FileHealth?> _measure(File file, String rel, SizeScanOptions o) async {
  try {
    final bytes = await file.length();
    final content = await file.readAsString();
    final counts = countLines(content);
    // Reuse the cached parse when content is unchanged; otherwise parse and
    // record it. Size/LOC above is always fresh, so it can never go stale.
    _FileMetrics? metrics;
    if (o.withComplexity) {
      final hash = stableHash(content);
      final cached = o.complexityCache?[rel];
      if (cached != null && cached.hash == hash) {
        o.cacheSink?[rel] = cached;
        metrics = _FileMetrics(
          cached.complexity,
          cached.maintainability,
          cached.maintainabilityRaw,
          cached.docCoverage,
        );
      } else {
        metrics = _metricsOf(content, counts);
        o.cacheSink?[rel] = CacheEntry(
          hash: hash,
          complexity: metrics.complexity,
          maintainability: metrics.maintainability,
          maintainabilityRaw: metrics.maintainabilityRaw,
          docCoverage: metrics.docCoverage,
        );
      }
    }
    final git = o.gitSignals?[rel];
    final coupling = o.coupling?[rel];
    return FileHealth(
      path: rel,
      bytes: bytes,
      loc: counts.total,
      codeLoc: counts.code,
      commentLoc: counts.comment,
      blankLoc: counts.blank,
      complexity: metrics?.complexity,
      maintainability: metrics?.maintainability,
      maintainabilityRaw: metrics?.maintainabilityRaw,
      docCoverage: metrics?.docCoverage,
      isUnusedFile: o.unusedFiles?.contains(rel) ?? false,
      deadSymbols: o.deadSymbols?[rel] ?? 0,
      coveragePct: o.coverage?[rel],
      churn: git?.churn,
      lastCommitDaysAgo: git?.lastCommitDaysAgo,
      busFactorPct: git?.busFactorPct,
      fanIn: coupling?.fanIn,
      fanOut: coupling?.fanOut,
    );
  } on FileSystemException {
    return null; // unreadable / vanished mid-walk; skip rather than abort
  }
}

/// Complexity rollup + Maintainability Index for one file, both derived from a
/// SINGLE parse (the element model is never built — memory stays light).
class _FileMetrics {
  const _FileMetrics(
    this.complexity,
    this.maintainability,
    this.maintainabilityRaw,
    this.docCoverage,
  );
  final FileComplexity complexity;
  final double maintainability;
  final double maintainabilityRaw;
  final double? docCoverage;
}

_FileMetrics _metricsOf(String content, LineCounts counts) {
  final unit = parseString(content: content, throwIfDiagnostics: false).unit;
  final complexity = FileComplexity.from(
    scanComplexityUnit(unit),
    scanClassMetricsUnit(unit),
  );
  final inputs = MaintainabilityInputs(
    halsteadVolume: halsteadVolumeFromUnit(unit),
    cyclomatic: complexity.maxCyclomatic,
    loc: counts.total,
    commentRatio: counts.total == 0 ? 0 : counts.comment / counts.total,
  );
  return _FileMetrics(
    complexity,
    maintainabilityIndex(inputs),
    maintainabilityIndexRaw(inputs),
    docCoverageOf(unit),
  );
}

bool _hasExcludedSegment(String relPosix) {
  for (final seg in relPosix.split('/')) {
    if (_excludedDirs.contains(seg)) return true;
  }
  return false;
}

/// Minimal glob → anchored RegExp supporting `**`, `*`, and `?`. Matches the
/// project-relative posix path so patterns like `lib/generated/**` work.
RegExp _globToRegExp(String glob) {
  final buffer = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final c = glob[i];
    if (c == '*') {
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        buffer.write('.*');
        i++;
      } else {
        buffer.write('[^/]*');
      }
    } else if (c == '?') {
      buffer.write('[^/]');
    } else {
      buffer.write(RegExp.escape(c));
    }
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}
