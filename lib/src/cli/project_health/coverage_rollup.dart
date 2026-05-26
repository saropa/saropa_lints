/// Parses an lcov `coverage/lcov.info` into per-file line coverage (0..1).
///
/// Coverage is only as good as the last `flutter test --coverage` — callers
/// should surface staleness rather than treat a missing/old entry as "fine".
/// Keys are project-relative posix paths so they join cleanly to `FileHealth`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads [lcovPath] (if it exists) and returns path → line-coverage fraction.
/// Returns an empty map when the file is absent.
Map<String, double> loadLcovCoverage(String lcovPath, String projectPath) {
  final file = File(lcovPath);
  if (!file.existsSync()) return {};
  return parseLcov(file.readAsStringSync(), projectPath: projectPath);
}

/// True when [lcovPath] predates the latest git commit — coverage was generated
/// before the current code, so the numbers are unverified (re-run with
/// `flutter test --coverage`). Returns false when git is unavailable or the
/// file is absent (cannot determine staleness, so do not cry wolf).
bool isCoverageStale(String lcovPath, String projectPath) {
  final file = File(lcovPath);
  if (!file.existsSync()) return false;
  final head = Process.runSync('git', [
    '-C',
    projectPath,
    'log',
    '-1',
    '--format=%ct',
  ], stdoutEncoding: utf8);
  if (head.exitCode != 0) return false;
  final headSecs = int.tryParse((head.stdout as String).trim());
  if (headSecs == null) return false;
  final lcovSecs = file.lastModifiedSync().millisecondsSinceEpoch ~/ 1000;
  return lcovSecs < headSecs;
}

/// Parses lcov [content]. Coverage per record = (DA lines with hits) / (DA
/// lines total). Records with no DA lines are skipped (nothing to measure).
Map<String, double> parseLcov(String content, {required String projectPath}) {
  final result = <String, double>{};
  String? current;
  var found = 0;
  var hit = 0;

  void flush() {
    if (current != null && found > 0) {
      result[current!] = hit / found;
    }
    current = null;
    found = 0;
    hit = 0;
  }

  for (final raw in const LineSplitter().convert(content)) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      flush();
      current = _relativePosix(line.substring(3), projectPath);
    } else if (line.startsWith('DA:')) {
      found++;
      // DA:<line>,<hits> — hits>0 means covered.
      final comma = line.lastIndexOf(',');
      final hits = comma < 0 ? 0 : int.tryParse(line.substring(comma + 1)) ?? 0;
      if (hits > 0) hit++;
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush(); // final record may omit end_of_record
  return result;
}

String _relativePosix(String sfPath, String projectPath) {
  final normalized = sfPath.replaceAll('\\', '/');
  if (p.isAbsolute(normalized)) {
    return p.relative(normalized, from: projectPath).replaceAll('\\', '/');
  }
  return normalized;
}
