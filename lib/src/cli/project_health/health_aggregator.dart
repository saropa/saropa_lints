/// Bounded, streaming aggregator for the size scan.
///
/// Memory discipline: this holds only what is provably small — O(folders)
/// rollups and fixed-size top-N heaps. Per-file rows are NOT retained here;
/// the caller streams them to disk. Peak memory is therefore flat in file
/// count, so a 100k-file project costs no more here than a 5k-file one.
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'health_model.dart';

/// Accumulates folder rollups, project totals, and top-N files as rows arrive.
class HealthAggregator {
  HealthAggregator({this.topN = 25})
    : _topByLoc = PriorityQueue<FileHealth>((a, b) => a.loc.compareTo(b.loc)),
      _topByBytes = PriorityQueue<FileHealth>(
        (a, b) => a.bytes.compareTo(b.bytes),
      ),
      _topByCognitive = PriorityQueue<FileHealth>(
        (a, b) => _cognitive(a).compareTo(_cognitive(b)),
      ),
      // Descending so the head is the HIGHEST MI; evicting the head keeps the
      // N lowest (worst) maintainability scores.
      _worstMaintainability = PriorityQueue<FileHealth>(
        (a, b) => _maint(b).compareTo(_maint(a)),
      ),
      _topByChurn = PriorityQueue<FileHealth>(
        (a, b) => _churn(a).compareTo(_churn(b)),
      ),
      // Descending: head is HIGHEST coverage; evicting keeps the N lowest.
      _lowestCoverage = PriorityQueue<FileHealth>(
        (a, b) => _coverage(b).compareTo(_coverage(a)),
      ),
      _deadFiles = PriorityQueue<FileHealth>((a, b) => a.loc.compareTo(b.loc)),
      _topByRoi = PriorityQueue<FileHealth>(
        (a, b) => roiOf(a).compareTo(roiOf(b)),
      );

  /// How many files to keep in each "largest" list. Bounds heap memory.
  final int topN;

  final Map<String, FolderHealth> _folders = {};

  // Min-heaps: the smallest sits at the head, so once full we evict the head to
  // keep the N LARGEST. O(N) memory regardless of total file count.
  final PriorityQueue<FileHealth> _topByLoc;
  final PriorityQueue<FileHealth> _topByBytes;

  // Populated only when the complexity section ran (rows carry complexity/MI).
  final PriorityQueue<FileHealth> _topByCognitive;
  final PriorityQueue<FileHealth> _worstMaintainability;

  // Populated only when the respective overlay ran (dead-weight / git / coverage).
  final PriorityQueue<FileHealth> _topByChurn;
  final PriorityQueue<FileHealth> _lowestCoverage;
  final PriorityQueue<FileHealth> _deadFiles;
  final PriorityQueue<FileHealth> _topByRoi;

  static int _cognitive(FileHealth f) => f.complexity?.maxCognitive ?? 0;
  // Rank by the UNCLAMPED MI so the worst-of-the-worst sort correctly (the
  // clamped score saturates at 0); the displayed value stays clamped.
  static double _maint(FileHealth f) =>
      f.maintainabilityRaw ?? f.maintainability ?? 100;
  static int _churn(FileHealth f) => f.churn ?? 0;
  // Missing coverage counts as fully covered so it never reads as "low".
  static double _coverage(FileHealth f) => f.coveragePct ?? 1.0;

  /// Refactoring-ROI score: a continuous "fix this for maximum risk reduction"
  /// priority. Combines how hard the file is (cognitive + size) with how risky
  /// it is to leave alone (changes often, poorly tested). Higher = fix sooner.
  /// Each factor degrades gracefully when its section did not run.
  static double roiOf(FileHealth f) {
    final difficulty = _cognitive(f) + f.loc / 100.0;
    final churnFactor = f.churn == null ? 1.0 : 1 + math.log(1 + f.churn!);
    // Uncovered → full weight; covered → small floor (still worth fixing if
    // complex/churning); unknown coverage → neutral.
    final cov = f.coveragePct;
    final coverageFactor = cov == null ? 0.65 : 0.3 + 0.7 * (1 - cov);
    return difficulty * churnFactor * coverageFactor;
  }

  int fileCount = 0;
  int totalBytes = 0;
  int totalLoc = 0;
  int totalCodeLoc = 0;
  int totalCommentLoc = 0;
  int totalBlankLoc = 0;

  // Exact aggregates (every file is seen by add, so these are not top-N-bounded)
  // — used by the baseline so regression detection is precise.
  int maxCognitiveSeen = 0;
  int deadFileCount = 0;
  int deadLocTotal = 0;
  int deadBytesTotal = 0;
  int deadSymbolTotal = 0;
  double _coverageSum = 0;
  int _coverageCount = 0;
  double _docSum = 0;
  int _docCount = 0;

  /// Mean line coverage across files that had coverage data, or null when the
  /// coverage section did not run.
  double? get averageCoverage =>
      _coverageCount == 0 ? null : _coverageSum / _coverageCount;

  /// Mean public-API doc coverage across files with public API, or null when
  /// complexity (which computes it) did not run.
  double? get averageDocCoverage => _docCount == 0 ? null : _docSum / _docCount;

  /// Folds one file into the running aggregates. The [FileHealth] may be
  /// discarded by the caller immediately after (except the references retained
  /// in the bounded top-N heaps).
  void add(FileHealth f) {
    fileCount++;
    totalBytes += f.bytes;
    totalLoc += f.loc;
    totalCodeLoc += f.codeLoc;
    totalCommentLoc += f.commentLoc;
    totalBlankLoc += f.blankLoc;
    maxCognitiveSeen = math.max(maxCognitiveSeen, _cognitive(f));
    if (f.isUnusedFile) {
      deadFileCount++;
      deadLocTotal += f.loc;
      deadBytesTotal += f.bytes;
    }
    deadSymbolTotal += f.deadSymbols;
    if (f.coveragePct != null) {
      _coverageSum += f.coveragePct!;
      _coverageCount++;
    }
    if (f.docCoverage != null) {
      _docSum += f.docCoverage!;
      _docCount++;
    }
    _rollUp(f);
    _offer(_topByLoc, f);
    _offer(_topByBytes, f);
    if (f.complexity != null) _offer(_topByCognitive, f);
    if (f.maintainability != null) _offer(_worstMaintainability, f);
    if (f.churn != null) _offer(_topByChurn, f);
    if (f.coveragePct != null) _offer(_lowestCoverage, f);
    if (f.isUnusedFile || f.deadSymbols > 0) _offer(_deadFiles, f);
    _offer(_topByRoi, f);
  }

  void _offer(PriorityQueue<FileHealth> heap, FileHealth f) {
    heap.add(f);
    if (heap.length > topN) heap.removeFirst(); // drop the current smallest
  }

  /// Adds [f] to its directory and every ancestor up to the project root (`.`).
  void _rollUp(FileHealth f) {
    var current = _dirOf(f.path);
    while (true) {
      (_folders[current] ??= FolderHealth(current)).addFile(f);
      if (current == '.') break;
      final idx = current.lastIndexOf('/');
      current = idx < 0 ? '.' : current.substring(0, idx);
    }
  }

  static String _dirOf(String path) {
    final idx = path.lastIndexOf('/');
    return idx < 0 ? '.' : path.substring(0, idx);
  }

  /// Folder rollups sorted largest-LOC first (treemap-ready).
  List<FolderHealth> folders() {
    final list = _folders.values.toList();
    list.sort((a, b) => b.loc.compareTo(a.loc));
    return list;
  }

  /// The [topN] largest files by LOC, descending.
  List<FileHealth> topByLoc() => _drainDescending(_topByLoc, (f) => f.loc);

  /// The [topN] largest files by bytes, descending.
  List<FileHealth> topByBytes() =>
      _drainDescending(_topByBytes, (f) => f.bytes);

  /// The [topN] most cognitively complex files, descending. Empty unless the
  /// complexity section ran.
  List<FileHealth> topByCognitive() =>
      _drainDescending(_topByCognitive, _cognitive);

  /// The [topN] LOWEST maintainability files, worst first. Empty unless the
  /// complexity section ran.
  List<FileHealth> worstMaintainability() {
    final list = _worstMaintainability.toList();
    list.sort((a, b) => _maint(a).compareTo(_maint(b)));
    return list;
  }

  /// The [topN] most-churned files, descending. Empty unless the git section ran.
  List<FileHealth> topByChurn() => _drainDescending(_topByChurn, _churn);

  /// The [topN] biggest dead files (unused or with dead symbols), by LOC.
  /// Empty unless the dead-weight section ran.
  List<FileHealth> deadFiles() => _drainDescending(_deadFiles, (f) => f.loc);

  /// The [topN] files by refactoring-ROI, descending (fix these first).
  List<FileHealth> topByRoi() {
    final list = _topByRoi.toList();
    list.sort((a, b) => roiOf(b).compareTo(roiOf(a)));
    return list;
  }

  /// The [topN] LOWEST-coverage files, worst first. Empty unless coverage ran.
  List<FileHealth> lowestCoverage() {
    final list = _lowestCoverage.toList();
    list.sort((a, b) => _coverage(a).compareTo(_coverage(b)));
    return list;
  }

  static List<FileHealth> _drainDescending(
    PriorityQueue<FileHealth> heap,
    int Function(FileHealth) key,
  ) {
    final list = heap.toList();
    list.sort((a, b) => key(b).compareTo(key(a)));
    return list;
  }
}
