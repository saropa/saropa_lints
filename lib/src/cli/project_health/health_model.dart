/// Data model for the Project Health dashboard (size scan increment).
///
/// Holds only the fields the current scanners populate (size + LOC split).
/// Coverage, git, complexity, and dead-weight fields are added by later
/// increments alongside the scanners that fill them — per the "minimal viable
/// shape" rule, no field exists here without a downstream consumer.
library;

import 'dart:math' as math;

import 'metrics_model.dart';

/// One source file's size profile (plus optional complexity when the
/// `--complexity` section runs). Rows are streamed to NDJSON on disk; only
/// bounded aggregates (folder rollups, top-N) stay in memory, so a [FileHealth]
/// is short-lived — built, emitted, and discarded per file.
class FileHealth {
  const FileHealth({
    required this.path,
    required this.bytes,
    required this.loc,
    required this.codeLoc,
    required this.commentLoc,
    required this.blankLoc,
    this.complexity,
    this.maintainability,
    this.maintainabilityRaw,
    this.docCoverage,
    this.isUnusedFile = false,
    this.deadSymbols = 0,
    this.coveragePct,
    this.churn,
    this.lastCommitDaysAgo,
    this.busFactorPct,
    this.fanIn,
    this.fanOut,
    this.perfWeight = 0,
    this.perfPatternCount = 0,
  });

  /// Project-relative, posix-separated path (stable across OSes for the report).
  final String path;

  /// On-disk size in bytes (the "KB" axis of the size map; includes line
  /// endings and encoding, so it reflects true disk footprint).
  final int bytes;

  /// Total physical lines (the "LOC" axis of the size map).
  final int loc;

  /// Lines containing source code (a line with code AND a trailing comment
  /// counts here, matching the cloc convention).
  final int codeLoc;

  /// Lines that are only comment (line, doc, or inside a block comment).
  final int commentLoc;

  /// Empty / whitespace-only lines.
  final int blankLoc;

  /// Per-file complexity rollup, or null when the `--complexity` section did
  /// not run (size-only scan).
  final FileComplexity? complexity;

  /// Maintainability Index (0..100), or null when complexity did not run.
  final double? maintainability;

  /// Unclamped Maintainability Index — used only to rank the worst-of-the-worst
  /// (the clamped score saturates at 0). Not a user-facing score.
  final double? maintainabilityRaw;

  /// Public-API doc coverage (0..1), or null when complexity did not run or the
  /// file has no public API.
  final double? docCoverage;

  /// True when no other file imports this one (dead-weight section). A large
  /// unused file is a prime cleanup target.
  final bool isUnusedFile;

  /// Count of top-level symbols here with no cross-file references.
  final int deadSymbols;

  /// Line coverage 0..1 from lcov, or null when the coverage section did not run
  /// (or no lcov entry exists for this file).
  final double? coveragePct;

  /// Number of commits touching this file (git section), or null.
  final int? churn;

  /// Days since the last commit to this file, or null.
  final int? lastCommitDaysAgo;

  /// Share (0..1) of this file's commits by its single top author — a bus-factor
  /// proxy (commit share, not line share), or null.
  final double? busFactorPct;

  /// Afferent coupling: how many files import this one (dead-weight section), or null.
  final int? fanIn;

  /// Efferent coupling: how many files this one imports, or null.
  final int? fanOut;

  /// Summed compound-performance pattern weight in this file (0 when the
  /// performance section did not run or the file has no such patterns). Drives
  /// the per-feature gravity rollup; see `perf_gravity.dart`.
  final int perfWeight;

  /// Count of compound-performance patterns detected in this file.
  final int perfPatternCount;

  /// Instability `Ce/(Ca+Ce)` (0 stable, 1 unstable), or null when coupling
  /// data is absent.
  double? get instability {
    if (fanIn == null || fanOut == null) return null;
    final total = fanIn! + fanOut!;
    return total == 0 ? 0 : fanOut! / total;
  }

  /// Comment density relative to CODE, not total lines: a file of pure comments
  /// must not read as ">100% documented", and blank lines should not dilute the
  /// signal. Guarded against divide-by-zero for code-free files.
  double get commentRatio => commentLoc / math.max(codeLoc, 1);

  Map<String, Object?> toJson() => {
    'path': path,
    'bytes': bytes,
    'loc': loc,
    'codeLoc': codeLoc,
    'commentLoc': commentLoc,
    'blankLoc': blankLoc,
    'commentRatio': double.parse(commentRatio.toStringAsFixed(4)),
    if (complexity != null) 'complexity': complexity!.toJson(),
    if (maintainability != null)
      'maintainability': double.parse(maintainability!.toStringAsFixed(2)),
    if (docCoverage != null)
      'docCoverage': double.parse(docCoverage!.toStringAsFixed(4)),
    if (isUnusedFile) 'isUnusedFile': true,
    if (deadSymbols > 0) 'deadSymbols': deadSymbols,
    if (coveragePct != null)
      'coveragePct': double.parse(coveragePct!.toStringAsFixed(4)),
    if (churn != null) 'churn': churn,
    if (lastCommitDaysAgo != null) 'lastCommitDaysAgo': lastCommitDaysAgo,
    if (busFactorPct != null)
      'busFactorPct': double.parse(busFactorPct!.toStringAsFixed(4)),
    if (fanIn != null) 'fanIn': fanIn,
    if (fanOut != null) 'fanOut': fanOut,
    if (instability != null)
      'instability': double.parse(instability!.toStringAsFixed(4)),
    if (perfWeight > 0) 'perfWeight': perfWeight,
    if (perfPatternCount > 0) 'perfPatternCount': perfPatternCount,
  };
}

/// Recursive size rollup for one directory (sum of every file beneath it).
///
/// Folders are the default treemap unit at scale: there are far fewer folders
/// than files, so the full folder set stays bounded in memory while per-file
/// detail lives on disk and loads only on drill-down.
class FolderHealth {
  FolderHealth(this.path);

  /// Project-relative, posix-separated directory path (`.` for the root).
  final String path;

  int fileCount = 0;
  int bytes = 0;
  int loc = 0;
  int codeLoc = 0;
  int commentLoc = 0;
  int blankLoc = 0;

  /// Accumulates one file into this folder's totals.
  void addFile(FileHealth f) {
    fileCount++;
    bytes += f.bytes;
    loc += f.loc;
    codeLoc += f.codeLoc;
    commentLoc += f.commentLoc;
    blankLoc += f.blankLoc;
  }

  Map<String, Object?> toJson() => {
    'path': path,
    'fileCount': fileCount,
    'bytes': bytes,
    'loc': loc,
    'codeLoc': codeLoc,
    'commentLoc': commentLoc,
    'blankLoc': blankLoc,
  };
}
