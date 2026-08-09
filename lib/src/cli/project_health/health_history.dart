/// Health "time-machine": reconstructs the trajectory of key metrics across
/// recent git tags by `git archive`-ing each tag's tree into a temp dir and
/// scanning it. Non-destructive (never touches the working tree or checks out).
/// Bounded by [maxTags] so it stays affordable. Answers "is the codebase getting
/// healthier or rotting?".
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'size_scanner.dart';

/// One tag's snapshot of headline metrics.
class HistoryPoint {
  const HistoryPoint({
    required this.tag,
    required this.fileCount,
    required this.loc,
    required this.codeLoc,
    required this.maxCognitive,
  });

  final String tag;
  final int fileCount;
  final int loc;
  final int codeLoc;
  final int maxCognitive;

  Map<String, Object?> toJson() => {
    'tag': tag,
    'fileCount': fileCount,
    'loc': loc,
    'codeLoc': codeLoc,
    'maxCognitive': maxCognitive,
  };

  /// Formats this point as a markdown table row matching the header from
  /// [markdownHeader]. Example output:
  /// `| v14.3.3 | 145 | 12340 | 9870 | 42 |`
  String toMarkdownRow() =>
      '| $tag | $fileCount | $loc | $codeLoc | $maxCognitive |';

  /// Column header row + separator for a table of [toMarkdownRow] entries.
  static const markdownHeader =
      '| Tag | Files | LoC | Code LoC | Max Cognitive |\n'
      '| --- | ----: | --: | -------: | ------------: |';

  /// Combines [markdownHeader] with [toMarkdownRow] for every point into a
  /// complete markdown table. Returns empty string when [points] is empty so
  /// callers don't emit a header-only table.
  static String toMarkdownTable(List<HistoryPoint> points) {
    if (points.isEmpty) return '';
    final buf = StringBuffer(markdownHeader);
    for (final p in points) {
      buf
        ..write('\n')
        ..write(p.toMarkdownRow());
    }
    return buf.toString();
  }
}

/// Builds the trajectory across the most recent [maxTags] tags (chronological).
/// Returns empty when not a git repo or there are no tags.
///
/// Each tag's point is cached on disk keyed by the tag's resolved commit SHA
/// (tags are immutable in normal use, so a SHA hit is reused verbatim without
/// re-archiving or re-scanning). This makes repeat calls — e.g. re-running the
/// test suite locally — near-instant after the first run.
Future<List<HistoryPoint>> loadHealthHistory(
  String projectPath, {
  int maxTags = 6,
  bool withComplexity = true,
}) async {
  final cache = _HistoryCache.load(projectPath);
  final points = <HistoryPoint>[];
  for (final tag in _recentTags(projectPath, maxTags)) {
    final sha = _resolveTagSha(projectPath, tag);
    final cacheKey = sha == null ? null : '${sha}_$withComplexity';
    final cached = cacheKey == null ? null : cache.get(cacheKey);
    if (cached != null) {
      points.add(cached);
      continue;
    }

    final dir = Directory.systemTemp.createTempSync('saropa_hist_');
    try {
      if (!_archive(projectPath, tag, dir.path)) continue;
      final agg = await runSizeScan(
        SizeScanOptions(projectPath: dir.path, withComplexity: withComplexity),
      );
      final point = HistoryPoint(
        tag: tag,
        fileCount: agg.fileCount,
        loc: agg.totalLoc,
        codeLoc: agg.totalCodeLoc,
        maxCognitive: agg.maxCognitiveSeen,
      );
      points.add(point);
      if (cacheKey != null) cache.put(cacheKey, point);
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Best-effort temp cleanup; a leftover temp dir is harmless.
      }
    }
  }
  cache.persist();
  return points;
}

/// Resolves [tag] to its commit SHA, or null if resolution fails (e.g. the
/// tag was deleted between `_recentTags` and this call).
String? _resolveTagSha(String projectPath, String tag) {
  final r = Process.runSync('git', [
    '-C',
    projectPath,
    'rev-list',
    '-n',
    '1',
    tag,
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0) return null;
  final sha = (r.stdout as String).trim();
  return sha.isEmpty ? null : sha;
}

/// On-disk cache of [HistoryPoint]s keyed by `<commitSha>_<withComplexity>`,
/// stored under `.dart_tool/saropa_lints/` so it survives across process runs
/// but stays out of version control (matches `.dart_tool`'s existing
/// gitignore treatment).
class _HistoryCache {
  _HistoryCache(this._file, this._entries);

  factory _HistoryCache.load(String projectPath) {
    final file = File(
      p.join(
        projectPath,
        '.dart_tool',
        'saropa_lints',
        'health_history_cache.json',
      ),
    );
    if (!file.existsSync()) return _HistoryCache(file, {});
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) return _HistoryCache(file, {});
      final entries = <String, HistoryPoint>{};
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is! Map<String, Object?>) continue;
        entries[entry.key] = HistoryPoint(
          tag: v['tag'] as String? ?? '',
          fileCount: v['fileCount'] as int? ?? 0,
          loc: v['loc'] as int? ?? 0,
          codeLoc: v['codeLoc'] as int? ?? 0,
          maxCognitive: v['maxCognitive'] as int? ?? 0,
        );
      }
      return _HistoryCache(file, entries);
    } on FormatException {
      return _HistoryCache(file, {});
    }
  }

  final File _file;
  final Map<String, HistoryPoint> _entries;
  bool _dirty = false;

  HistoryPoint? get(String key) => _entries[key];

  void put(String key, HistoryPoint point) {
    _entries[key] = point;
    _dirty = true;
  }

  void persist() {
    if (!_dirty) return;
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(
        jsonEncode({for (final e in _entries.entries) e.key: e.value.toJson()}),
      );
    } on FileSystemException {
      // Best-effort cache write; a missing cache just costs a re-scan.
    }
  }
}

/// Most recent [maxTags] tags, returned oldest-first (chronological).
List<String> _recentTags(String projectPath, int maxTags) {
  // git climbs the directory tree looking for a repo, so running `git tag`
  // from a non-repo subdirectory of another repo silently inherits the
  // parent's tags. That misreports a stranger repo's history as the project's
  // own — for example when the test runner places its temp dirs under
  // build/test_tmp inside this repo. Require projectPath to host its own .git
  // entry (a directory for regular repos, a file for worktrees) before
  // trusting git to answer for it.
  if (FileSystemEntity.typeSync(p.join(projectPath, '.git')) ==
      FileSystemEntityType.notFound) {
    return const [];
  }
  final r = Process.runSync('git', [
    '-C',
    projectPath,
    'tag',
    '--sort=-creatordate',
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0) return const [];
  final all = (r.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return all.take(maxTags).toList().reversed.toList();
}

/// Extracts [tag]'s tree into [destDir] via `git archive` + `tar` (no checkout).
bool _archive(String projectPath, String tag, String destDir) {
  final tarPath = p.join(destDir, '_tree.tar');
  final archived = Process.runSync('git', [
    '-C',
    projectPath,
    'archive',
    '--format=tar',
    '-o',
    tarPath,
    tag,
  ]);
  if (archived.exitCode != 0) return false;
  final extracted = Process.runSync('tar', ['-xf', tarPath, '-C', destDir]);
  try {
    File(tarPath).deleteSync();
  } on FileSystemException {
    // ignore
  }
  return extracted.exitCode == 0;
}
