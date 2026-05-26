/// Per-file git signals: churn (commit count), recency, and a bus-factor proxy.
///
/// Bounded by `-n maxCommits` so deep histories do not blow out memory or time;
/// the log is read once and reduced. Bus factor here is COMMIT share by the top
/// author (cheap), not line share from blame. Returns empty when not a git repo.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Git activity for one file.
class GitSignal {
  const GitSignal({
    required this.churn,
    required this.lastCommitDaysAgo,
    required this.busFactorPct,
  });

  final int churn;
  final int lastCommitDaysAgo;
  final double busFactorPct;
}

/// Loads git signals for files under [projectPath]. [maxCommits] bounds the
/// history window (default 2000) so huge repos stay fast.
Map<String, GitSignal> loadGitSignals(
  String projectPath, {
  int maxCommits = 2000,
}) {
  final root = _gitRoot(projectPath);
  if (root == null) return {};
  final log = Process.runSync('git', [
    '-C',
    projectPath,
    'log',
    '-n',
    '$maxCommits',
    '--no-merges',
    '--format=__C__%ct|%ae',
    '--name-only',
  ], stdoutEncoding: utf8);
  if (log.exitCode != 0) return {};
  return _parseLog(
    log.stdout as String,
    gitRoot: root,
    projectPath: projectPath,
  );
}

String? _gitRoot(String projectPath) {
  final r = Process.runSync('git', [
    '-C',
    projectPath,
    'rev-parse',
    '--show-toplevel',
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0) return null;
  final out = (r.stdout as String).trim();
  return out.isEmpty ? null : out;
}

Map<String, GitSignal> _parseLog(
  String log, {
  required String gitRoot,
  required String projectPath,
}) {
  final churn = <String, int>{};
  final lastCommit = <String, int>{};
  final authors = <String, Map<String, int>>{};
  var commitTime = 0;
  var author = '';

  for (final line in const LineSplitter().convert(log)) {
    if (line.startsWith('__C__')) {
      final rest = line.substring(5);
      final bar = rest.indexOf('|');
      commitTime = int.tryParse(bar < 0 ? rest : rest.substring(0, bar)) ?? 0;
      author = bar < 0 ? '' : rest.substring(bar + 1);
      continue;
    }
    if (line.isEmpty) continue;
    final rel = _toProjectRel(line, gitRoot, projectPath);
    if (rel == null) continue;
    churn[rel] = (churn[rel] ?? 0) + 1;
    if (commitTime > (lastCommit[rel] ?? 0)) lastCommit[rel] = commitTime;
    (authors[rel] ??= {})[author] = (authors[rel]![author] ?? 0) + 1;
  }

  final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final out = <String, GitSignal>{};
  churn.forEach((path, commits) {
    final topAuthor = authors[path]!.values.fold<int>(
      0,
      (m, v) => v > m ? v : m,
    );
    out[path] = GitSignal(
      churn: commits,
      lastCommitDaysAgo: ((nowSecs - (lastCommit[path] ?? nowSecs)) / 86400)
          .floor(),
      busFactorPct: commits == 0 ? 0 : topAuthor / commits,
    );
  });
  return out;
}

String? _toProjectRel(String gitRelPath, String gitRoot, String projectPath) {
  final abs = p.join(gitRoot, gitRelPath);
  final rel = p.relative(abs, from: projectPath).replaceAll('\\', '/');
  return rel.startsWith('..') ? null : rel; // outside the scanned scope
}
