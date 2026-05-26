/// **Project vibrancy** scan: reads a Dart/Flutter workspace, parses `pubspec.yaml` and Dart units,
/// correlates `coverage/lcov.info` (when present), and emits a JSON report of per-function signals
/// (coverage %, usage heuristics, complexity, documentation hints, and quality flags such as
/// `unused`, `uncovered`, `stub_tested`, `suspicious_coverage`, `test_drift`).
///
/// **Inputs:** [ProjectVibrancyOptions] selects project root, optional single-file or folder scope,
/// optional `includedFiles` set (e.g. git-changed paths), and lcov location.
///
/// **Outputs:** [ProjectVibrancyReport] with UTC `generatedAt` and flat [ProjectVibrancyFunctionResult]
/// rows suitable for the extension webview and CLI thresholds (`--min-grade`, unused caps, …).
///
/// **Performance:** resolves analysis context once per run; skips gracefully when analyzer or lcov
/// is missing. See `bin/project_vibrancy.dart` for CLI exit-code mapping.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_vibrancy_coverage_quality.dart';

/// Live progress + cooperative pause/cancel sink for [runProjectVibrancy].
///
/// The Code Health webview opens immediately and renders a progress bar, the
/// file currently being processed, and Pause/Resume/Cancel controls while the
/// scan runs in the background. The scan reports through [onEvent] (the CLI maps
/// each event to one NDJSON line on stderr) and `await`s [gate] before each unit
/// of work.
///
/// [gate] is the pause/cancel mechanism: it returns immediately during normal
/// running, blocks (polling) while the user has paused, and throws to abort when
/// the user cancels. Pause is cooperative on purpose — there is no portable way
/// to SIGSTOP a child process on Windows, so the scan must suspend itself rather
/// than rely on the OS. A null [ProjectScanProgress] (the CLI/CI default) makes
/// every call site a no-op, so non-interactive runs are byte-for-byte unchanged.
class ProjectScanProgress {
  ProjectScanProgress({required this.onEvent, required this.gate});

  /// Receives one progress event map per call (phase/tick/row). The CLI
  /// serializes each to NDJSON on stderr; stdout stays the pure report JSON.
  final void Function(Map<String, Object?> event) onEvent;

  /// Awaited before each unit of work. Resolves instantly when running, waits
  /// while paused, and throws when cancelled (the CLI catches and exits clean).
  final Future<void> Function() gate;
}

/// CLI and library entry options for [runProjectVibrancy].
class ProjectVibrancyOptions {
  const ProjectVibrancyOptions({
    required this.projectPath,
    this.lcovPath = 'coverage/lcov.info',
    this.filePath,
    this.folderPath,
    this.includedFiles,
    this.cachePath,
  });

  final String projectPath;
  final String lcovPath;
  final String? filePath;
  final String? folderPath;
  final Set<String>? includedFiles;
  final String? cachePath;
}

/// One function-level row in the vibrancy report (scores, grades, and string `flags`).
class ProjectVibrancyFunctionResult {
  const ProjectVibrancyFunctionResult({
    required this.id,
    required this.file,
    required this.name,
    required this.lineStart,
    required this.lineEnd,
    required this.score,
    required this.grade,
    required this.category,
    required this.ageScore,
    required this.coverageScore,
    required this.usageScore,
    required this.complexityScore,
    required this.documentationScore,
    required this.usageCount,
    required this.coveragePercent,
    required this.complexity,
    required this.flags,
  });

  final String id;
  final String file;
  final String name;
  final int lineStart;
  final int lineEnd;
  final double score;
  final String grade;
  final String category;
  final double ageScore;
  final double coverageScore;
  final double usageScore;
  final double complexityScore;
  final double documentationScore;
  final int usageCount;
  final double coveragePercent;
  final int complexity;
  final List<String> flags;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'file': file,
    'name': name,
    'lineStart': lineStart,
    'lineEnd': lineEnd,
    'score': score,
    'grade': grade,
    'category': category,
    'signals': <String, Object>{
      'age': ageScore,
      'coverage': coverageScore,
      'usage': usageScore,
      'complexity': complexityScore,
      'documentation': documentationScore,
    },
    'usageCount': usageCount,
    'coveragePercent': coveragePercent,
    'complexity': complexity,
    'flags': flags,
  };
}

/// Full report payload returned by [runProjectVibrancy].
class ProjectVibrancyReport {
  const ProjectVibrancyReport({
    required this.generatedAt,
    required this.projectPath,
    required this.functions,
  });

  final String generatedAt;
  final String projectPath;
  final List<ProjectVibrancyFunctionResult> functions;

  Map<String, Object> toJson() {
    final avg = functions.isEmpty
        ? 0.0
        : functions.fold<double>(0, (sum, f) => sum + f.score) /
              functions.length;
    int countFlag(String flag) =>
        functions.where((f) => f.flags.contains(flag)).length;
    return <String, Object>{
      'generatedAt': generatedAt,
      'projectPath': projectPath,
      'summary': <String, Object>{
        'functionCount': functions.length,
        'averageScore': avg,
        'averageGrade': _scoreToGrade(avg),
        'stubTestedCount': countFlag('stub_tested'),
        'suspiciousCoverageCount': countFlag('suspicious_coverage'),
        'testDriftCount': countFlag('test_drift'),
      },
      'functions': functions.map((f) => f.toJson()).toList(growable: false),
    };
  }
}

Future<ProjectVibrancyReport> runProjectVibrancy(
  ProjectVibrancyOptions options, {
  ProjectScanProgress? progress,
}) async {
  final root = p.normalize(options.projectPath);
  // Earliest possible signal: file enumeration + the `dart run` compile that
  // precedes it are the longest stretch with no other feedback. Emitting this
  // first means the dashboard shows "Discovering files…" the instant the
  // process produces any output, instead of sitting at a dead 0%.
  progress?.onEvent(<String, Object?>{'event': 'phase', 'phase': 'collect'});
  final files = _collectTargetFiles(options);
  final cache = _ProjectVibrancyCache.open(
    options.cachePath ??
        p.join(root, '.saropa', 'project-vibrancy-cache', 'mvp_cache.json'),
  );
  final lcov = _parseLcov(root, options.lcovPath, cache);
  final packageName = readPubspecPackageName(root);
  final coverageIdx = buildProjectCoverageQualityIndex(
    projectRoot: root,
    packageName: packageName,
  );
  final fileContents = <String, String>{};
  final declaredFunctions = <_FunctionNode>[];

  progress?.onEvent(<String, Object?>{
    'event': 'phase',
    'phase': 'parse',
    'total': files.length,
  });
  var parsedCount = 0;
  for (final filePath in files) {
    await progress?.gate();
    // Emit the file BEFORE parsing it (not after), so the panel shows what the
    // scan is currently chewing on. A single huge generated file can take many
    // seconds to parse with no tick in between; showing it as "in progress"
    // means the user sees real work instead of a frozen bar.
    progress?.onEvent(<String, Object?>{
      'event': 'tick',
      'phase': 'parse',
      'done': parsedCount,
      'total': files.length,
      'file': p.relative(filePath, from: root).replaceAll('\\', '/'),
      'functions': declaredFunctions.length,
    });
    parsedCount++;
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    fileContents[filePath] = content;
    // throwIfDiagnostics:false is essential — a Code Health scan runs over
    // possibly-broken source (a consumer project mid-edit, an example fixture
    // with intentional violations). The analyzer default throws on ANY parse
    // diagnostic (e.g. await_in_wrong_context), which previously aborted the
    // whole scan on the first imperfect file. Tolerate diagnostics and keep
    // scanning the rest of the project.
    final parsed = parseString(
      content: content,
      path: filePath,
      throwIfDiagnostics: false,
    );
    final collector = _FunctionCollector(content: content, filePath: filePath);
    parsed.unit.accept(collector);
    declaredFunctions.addAll(collector.functions);
  }

  final pathsForGit = <String>{};
  for (final fn in declaredFunctions) {
    pathsForGit.add(fn.filePath);
    final libRel = p.relative(fn.filePath, from: root).replaceAll('\\', '/');
    pathsForGit.addAll(
      coverageIdx.testsImportingLib[libRel] ?? const <String>{},
    );
  }
  final commitEpoch = <String, int?>{};
  progress?.onEvent(<String, Object?>{
    'event': 'phase',
    'phase': 'history',
    'total': pathsForGit.length,
  });
  var historyDone = 0;
  for (final path in pathsForGit) {
    await progress?.gate();
    historyDone++;
    commitEpoch[path] = await gitLastCommitEpochSec(
      projectRoot: root,
      absoluteDartPath: path,
    );
    progress?.onEvent(<String, Object?>{
      'event': 'tick',
      'phase': 'history',
      'done': historyDone,
      'total': pathsForGit.length,
      'file': p.relative(path, from: root).replaceAll('\\', '/'),
    });
  }

  final extendedForUsage = Map<String, String>.from(fileContents);
  for (final testPath in listProjectTestDartPaths(root)) {
    final tf = File(testPath);
    if (tf.existsSync()) {
      extendedForUsage[testPath] = tf.readAsStringSync();
    }
  }
  final usageCounts = _computeUsageCounts(
    extendedForUsage,
    declaredFunctions,
    progress: progress,
    root: root,
  );
  final blameByFile = await _collectBlameAges(files, cache, progress: progress, root: root);
  final results = <ProjectVibrancyFunctionResult>[];

  progress?.onEvent(<String, Object?>{
    'event': 'phase',
    'phase': 'score',
    'total': declaredFunctions.length,
  });
  var scoreDone = 0;
  var streamedRows = 0;
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  for (final fn in declaredFunctions) {
    await progress?.gate();
    scoreDone++;
    final content = fileContents[fn.filePath] ?? '';
    final rawCoverage = _computeCoverage(fn, lcov[fn.filePath]);
    final libRel = p.relative(fn.filePath, from: root).replaceAll('\\', '/');
    final linkedTests =
        coverageIdx.testsImportingLib[libRel] ?? const <String>{};
    var stubTested = false;
    if (rawCoverage != null &&
        rawCoverage > 0 &&
        linkedTests.isNotEmpty &&
        linkedTests.every((t) => coverageIdx.testIsTrivial[t] == true)) {
      stubTested = true;
    }
    final effectiveCoverage = stubTested ? 0.0 : rawCoverage;
    final coverageScore = effectiveCoverage == null
        ? 50.0
        : effectiveCoverage * 100.0;
    final ageScore = _computeAgeScore(fn, blameByFile[fn.filePath]);
    final usageCount = usageCounts[fn.id] ?? 0;
    final usageScore = _usageBucket(usageCount).toDouble();
    final complexityScore = _complexityScore(fn.complexity);
    final documentationScore = _documentationScore(content, fn);

    final distinctNonTrivial = linkedTests
        .where((t) => coverageIdx.testIsTrivial[t] == false)
        .length;
    var suspiciousCoverage = false;
    if (fn.complexity >= 10 &&
        rawCoverage != null &&
        rawCoverage >= 0.9 &&
        linkedTests.isNotEmpty &&
        distinctNonTrivial < fn.complexity / 3.0) {
      suspiciousCoverage = true;
    }

    var testDrift = false;
    if (linkedTests.isNotEmpty) {
      final prodEp = commitEpoch[fn.filePath];
      if (prodEp != null) {
        final prodDays = (nowSec - prodEp) / 86400.0;
        var newestTestEp = 0;
        for (final t in linkedTests) {
          final te = commitEpoch[t];
          if (te != null && te > newestTestEp) newestTestEp = te;
        }
        if (newestTestEp > 0) {
          final testDays = (nowSec - newestTestEp) / 86400.0;
          testDrift = computeTestDriftFlag(
            prodDaysSinceCommit: prodDays,
            newestLinkedTestDaysSinceCommit: testDays,
          );
        }
      }
    }

    final total =
        (0.15 * ageScore) +
        (0.40 * coverageScore) +
        (0.25 * usageScore) +
        (0.15 * complexityScore) +
        (0.05 * documentationScore);
    final rounded = (total * 10).roundToDouble() / 10.0;
    final grade = _scoreToGrade(rounded);
    final category = _scoreToCategory(rounded);
    final flags = <String>[];
    if (usageCount == 0) flags.add('unused');
    if (rawCoverage != null && rawCoverage == 0) flags.add('uncovered');
    if (stubTested) flags.add('stub_tested');
    if (suspiciousCoverage) flags.add('suspicious_coverage');
    if (testDrift) flags.add('test_drift');
    if (fn.complexity > 10) flags.add('complex');
    if (documentationScore < 20 && fn.complexity > 10) {
      flags.add('undocumented');
    }

    results.add(
      ProjectVibrancyFunctionResult(
        id: fn.id,
        file: libRel,
        name: fn.name,
        lineStart: fn.lineStart,
        lineEnd: fn.lineEnd,
        score: rounded,
        grade: grade,
        category: category,
        ageScore: _round1(ageScore),
        coverageScore: _round1(coverageScore),
        usageScore: _round1(usageScore),
        complexityScore: _round1(complexityScore),
        documentationScore: _round1(documentationScore),
        usageCount: usageCount,
        coveragePercent: _round1((rawCoverage ?? 0) * 100),
        complexity: fn.complexity,
        flags: flags,
      ),
    );
    // Stream a bounded sample of problem functions (grade D and worse) so the
    // webview "fills out" a live preview as the scan learns the code, without
    // flooding stderr on a large project. The full sorted table renders at the
    // end; this is just the at-a-glance "worst found so far" feel.
    if (progress != null && streamedRows < 100 && rounded < 35) {
      streamedRows++;
      progress.onEvent(<String, Object?>{
        'event': 'row',
        'grade': grade,
        'score': rounded,
        'name': fn.name,
        'file': libRel,
        'line': fn.lineStart,
        'complexity': fn.complexity,
        'flags': flags,
      });
    }
    // Throttle score ticks — the function count can be in the thousands and
    // this phase is fast; one tick per 25 keeps the bar moving without spam.
    if (scoreDone % 25 == 0 || scoreDone == declaredFunctions.length) {
      progress?.onEvent(<String, Object?>{
        'event': 'tick',
        'phase': 'score',
        'done': scoreDone,
        'total': declaredFunctions.length,
      });
    }
  }

  results.sort((a, b) => a.score.compareTo(b.score));
  cache.save();
  return ProjectVibrancyReport(
    generatedAt: DateTime.now().toUtc().toIso8601String(),
    projectPath: root,
    functions: results,
  );
}

/// Directory names pruned from the file walk. None hold the project's own
/// scannable `lib/` sources, but on a real Flutter app they are huge (build
/// outputs, the pub cache, generated tool state) or contain symlink loops
/// (iOS/macOS `Pods`, plugin `.symlinks`). Walking them with `followLinks` was
/// the dominant cost of the long "0 files" dead-zone before the first progress
/// event — and could hang outright on a symlink cycle. Pruning the *traversal*
/// does not change which files are scanned: the `/lib/` + `.dart` + `build/`
/// filters below already excluded everything under these directories.
bool _isPrunedScanDir(String name) {
  switch (name) {
    case '.git':
    case '.dart_tool':
    case '.fvm':
    case '.symlinks':
    case '.plugin_symlinks':
    case '.gradle':
    case '.idea':
    case '.vscode':
    case 'build':
    case 'node_modules':
    case 'Pods':
      return true;
    default:
      return false;
  }
}

List<String> _collectTargetFiles(ProjectVibrancyOptions options) {
  final root = Directory(options.projectPath);
  if (!root.existsSync()) return const <String>[];
  final rootPath = p.normalize(root.path);
  final selectedFile = options.filePath;
  final selectedFolder = options.folderPath;
  final included = options.includedFiles?.map(p.normalize).toSet();
  final files = <String>[];
  // Manual stack walk with followLinks:false so a symlink cycle can never wedge
  // the scan, and pruned dirs are never descended into.
  final stack = <Directory>[root];
  while (stack.isNotEmpty) {
    final dir = stack.removeLast();
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      // Permission denied or the dir vanished mid-walk — skip it, never abort
      // the whole scan over one unreadable directory.
      continue;
    }
    for (final entity in entries) {
      if (entity is Directory) {
        if (!_isPrunedScanDir(p.basename(entity.path))) {
          stack.add(entity);
        }
        continue;
      }
      if (entity is! File) continue;
      final path = p.normalize(entity.path);
      if (!path.endsWith('.dart')) continue;
      final posix = path.replaceAll('\\', '/');
      if (posix.endsWith('.g.dart') ||
          posix.endsWith('.freezed.dart') ||
          posix.endsWith('.mocks.dart')) {
        continue;
      }
      // Skip pathologically large files — almost always generated (gen-l10n
      // `app_localizations_*.dart` runs to 1MB+, protobuf, etc.). Parsing and
      // visiting a 30k-line generated file stalls the scan for many seconds with
      // no per-file progress and adds no health signal. lengthSync is cheap (no
      // read). ~512KB ≈ 12k lines, well above any hand-written Dart file.
      try {
        if (entity.lengthSync() > 512000) continue;
      } on FileSystemException {
        continue;
      }
      // Exclude project `build/` outputs only (relative to root). A plain
      // substring match on `/build/` skips real packages under paths like
      // `<repo>/build/test_tmp/.../lib/` when TMP is redirected for tests.
      final rel = p.relative(path, from: rootPath);
      final posixRel = rel.replaceAll('\\', '/');
      if (posixRel.startsWith('build/') || posixRel.contains('/build/')) {
        continue;
      }
      if (!posix.contains('/lib/')) continue;
      if (selectedFile != null && p.normalize(selectedFile) != path) continue;
      if (selectedFolder != null &&
          !path.startsWith(p.normalize(selectedFolder))) {
        continue;
      }
      if (included != null && !included.contains(path)) continue;
      files.add(path);
    }
  }
  files.sort();
  return files;
}

Map<String, Set<int>> _parseLcov(
  String root,
  String lcovPath,
  _ProjectVibrancyCache cache,
) {
  final file = File(p.isAbsolute(lcovPath) ? lcovPath : p.join(root, lcovPath));
  if (!file.existsSync()) return const <String, Set<int>>{};
  final lcovText = file.readAsStringSync();
  final fingerprint = _stableHash(lcovText);
  final cached = cache.getLcov(fingerprint);
  if (cached != null) return cached;
  final byFile = <String, Set<int>>{};
  String? current;
  const sfPrefix = 'SF:';
  const daPrefix = 'DA:';
  for (final raw in lcovText.split('\n')) {
    if (raw.startsWith(sfPrefix)) {
      final pathPart = raw.replaceFirst(sfPrefix, '');
      if (pathPart.isNotEmpty) {
        current = p.normalize(pathPart);
        byFile.putIfAbsent(current, () => <int>{});
      }
      continue;
    }
    if (current == null || !raw.startsWith(daPrefix)) continue;
    final daSegments = raw.replaceFirst(daPrefix, '').split(',');
    final String linePart;
    final String hitsPart;
    switch (daSegments) {
      case [final a, final b]:
        linePart = a;
        hitsPart = b;
      default:
        continue;
    }
    final line = int.tryParse(linePart);
    final hits = int.tryParse(hitsPart);
    if (line == null || hits == null) continue;
    if (hits > 0) {
      byFile[current]!.add(line);
    }
  }
  cache.setLcov(fingerprint, byFile);
  return byFile;
}

Future<Map<String, Map<int, int>>> _collectBlameAges(
  List<String> files,
  _ProjectVibrancyCache cache, {
  ProjectScanProgress? progress,
  String? root,
}) async {
  final result = <String, Map<int, int>>{};
  progress?.onEvent(<String, Object?>{
    'event': 'phase',
    'phase': 'blame',
    'total': files.length,
  });
  var blameDone = 0;
  for (final file in files) {
    await progress?.gate();
    blameDone++;
    progress?.onEvent(<String, Object?>{
      'event': 'tick',
      'phase': 'blame',
      'done': blameDone,
      'total': files.length,
      'file': root == null
          ? file
          : p.relative(file, from: root).replaceAll('\\', '/'),
    });
    final fileHash = await _gitBlobHash(file);
    if (fileHash != null) {
      final cached = cache.getBlame(fileHash);
      if (cached != null) {
        result[file] = cached;
        continue;
      }
    }
    // workingDirectory: root so blame targets the SCANNED project's repo even
    // when the CLI process runs from elsewhere (the dev path runs the local
    // saropa_lints CLI but scans a different project via --path).
    final proc = await Process.run('git', <String>[
      'blame',
      '--line-porcelain',
      '-w',
      '--',
      file,
    ], workingDirectory: root);
    if (proc.exitCode != 0) {
      result[file] = const <int, int>{};
      continue;
    }
    final map = <int, int>{};
    var lineNo = 0;
    var currentAuthorTime = 0;
    final stdoutText = proc.stdout;
    if (stdoutText is! String) {
      result[file] = const <int, int>{};
      continue;
    }
    const authorTimePrefix = 'author-time ';
    final lines = stdoutText.split('\n');
    for (final line in lines) {
      if (line.startsWith(authorTimePrefix)) {
        currentAuthorTime =
            int.tryParse(line.replaceFirst(authorTimePrefix, '').trim()) ?? 0;
        continue;
      }
      if (line.startsWith('\t')) {
        lineNo++;
        map[lineNo] = currentAuthorTime;
      }
    }
    result[file] = map;
    if (fileHash != null) {
      cache.setBlame(fileHash, map);
    }
  }
  return result;
}

double _computeAgeScore(_FunctionNode fn, Map<int, int>? blame) {
  if (blame == null || blame.isEmpty) return 50.0;
  final epochs = <int>[];
  for (var line = fn.lineStart; line <= fn.lineEnd; line++) {
    final ts = blame[line];
    if (ts != null && ts > 0) {
      epochs.add(ts);
    }
  }
  if (epochs.isEmpty) return 50.0;
  epochs.sort();
  final medianEpoch = epochs[epochs.length ~/ 2];
  final days =
      (DateTime.now().millisecondsSinceEpoch ~/ 1000 - medianEpoch) / 86400.0;
  final score = 100.0 * (2.718281828459045 * -days / 365.0).clamp(0.0, 1.0);
  return score.clamp(0.0, 100.0);
}

double? _computeCoverage(_FunctionNode fn, Set<int>? hitLines) {
  if (hitLines == null) return null;
  final totalLines = (fn.lineEnd - fn.lineStart + 1).clamp(1, 100000);
  var hits = 0;
  for (var line = fn.lineStart; line <= fn.lineEnd; line++) {
    if (hitLines.contains(line)) hits++;
  }
  return hits / totalLines;
}

Map<String, int> _computeUsageCounts(
  Map<String, String> contents,
  List<_FunctionNode> functions, {
  ProjectScanProgress? progress,
  String? root,
}) {
  final referencesByName = _collectReferenceCounts(
    contents,
    progress: progress,
    root: root,
  );
  final counts = <String, int>{};
  for (final fn in functions) {
    counts[fn.id] = referencesByName[fn.name] ?? 0;
  }
  return counts;
}

Map<String, int> _collectReferenceCounts(
  Map<String, String> contents, {
  ProjectScanProgress? progress,
  String? root,
}) {
  final counts = <String, int>{};
  progress?.onEvent(<String, Object?>{
    'event': 'phase',
    'phase': 'usage',
    'total': contents.length,
  });
  var usageDone = 0;
  for (final entry in contents.entries) {
    usageDone++;
    // throwIfDiagnostics:false: same robustness reason as the primary parse —
    // reference counting must not crash on a file the analyzer flags.
    final parsed = parseString(
      content: entry.value,
      path: entry.key,
      throwIfDiagnostics: false,
    );
    final visitor = _ReferenceVisitor();
    parsed.unit.accept(visitor);
    for (final name in visitor.references) {
      counts.update(name, (c) => c + 1, ifAbsent: () => 1);
    }
    if (usageDone % 25 == 0 || usageDone == contents.length) {
      progress?.onEvent(<String, Object?>{
        'event': 'tick',
        'phase': 'usage',
        'done': usageDone,
        'total': contents.length,
        'file': root == null
            ? entry.key
            : p.relative(entry.key, from: root).replaceAll('\\', '/'),
      });
    }
  }
  return counts;
}

double _complexityScore(int complexity) {
  if (complexity <= 1) return 100;
  if (complexity >= 20) return 0;
  return (1 - ((complexity - 1) / 19)) * 100;
}

int _usageBucket(int count) {
  if (count <= 0) return 0;
  if (count <= 2) return 40;
  if (count <= 9) return 70;
  return 100;
}

double _documentationScore(String content, _FunctionNode fn) {
  var score = 0.0;
  if (fn.hasDocComment) score += 40;
  final lines = content.split('\n');
  final start = (fn.lineStart - 1).clamp(0, lines.length);
  final end = fn.lineEnd.clamp(0, lines.length);
  final slice = lines.sublist(start, end);
  final codeLines = slice.where((l) => l.trim().isNotEmpty).length;
  final commentLines = slice
      .where(
        (l) => l.trimLeft().startsWith('//') || l.trimLeft().startsWith('/*'),
      )
      .length;
  final density = codeLines == 0 ? 0 : commentLines / codeLines;
  score += (density * 320).clamp(0, 40);
  final commentText = slice
      .where((l) => l.trimLeft().startsWith('//'))
      .map((l) => l.replaceFirst(RegExp(r'^\s*//'), ''))
      .join(' ');
  if (commentText.isNotEmpty) {
    final letters = RegExp(r'[A-Za-z]').allMatches(commentText).length;
    final symbols =
        RegExp(r'[^A-Za-z0-9\s]').allMatches(commentText).length + 1;
    score += ((letters / symbols) * 4).clamp(0, 20);
  }
  return score.clamp(0, 100);
}

double _round1(double n) => (n * 10).roundToDouble() / 10.0;

String _scoreToGrade(double score) {
  if (score >= 80) return 'A';
  if (score >= 65) return 'B';
  if (score >= 50) return 'C';
  if (score >= 35) return 'D';
  if (score >= 20) return 'E';
  return 'F';
}

String _scoreToCategory(double score) {
  if (score >= 70) return 'fresh';
  if (score >= 40) return 'stable';
  if (score >= 20) return 'stale';
  return 'rotting';
}

class _FunctionCollector extends RecursiveAstVisitor<void> {
  _FunctionCollector({required this.content, required this.filePath});
  final String content;
  final String filePath;
  final List<_FunctionNode> functions = <_FunctionNode>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final body = node.functionExpression.body;
    _addFunction(
      name: node.name.lexeme,
      node: node,
      body: body,
      hasDocComment: node.documentationComment != null,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addFunction(
      name: node.name.lexeme,
      node: node,
      body: node.body,
      hasDocComment: node.documentationComment != null,
    );
    super.visitMethodDeclaration(node);
  }

  void _addFunction({
    required String name,
    required AstNode node,
    required FunctionBody body,
    required bool hasDocComment,
  }) {
    final start = _lineOf(node.offset);
    final end = _lineOf(node.end);
    final complexity = _ComplexityVisitor.compute(body);
    final id = '$filePath:$name:$start';
    functions.add(
      _FunctionNode(
        id: id,
        filePath: filePath,
        name: name,
        lineStart: start,
        lineEnd: end,
        complexity: complexity,
        hasDocComment: hasDocComment,
      ),
    );
  }

  int _lineOf(int offset) {
    var line = 1;
    for (var i = 0; i < offset && i < content.length; i++) {
      if (content.codeUnitAt(i) == 10) line++;
    }
    return line;
  }
}

class _ComplexityVisitor extends RecursiveAstVisitor<void> {
  int complexity = 1;

  static int compute(FunctionBody body) {
    final v = _ComplexityVisitor();
    body.accept(v);
    return v.complexity;
  }

  @override
  void visitIfStatement(IfStatement node) {
    complexity++;
    super.visitIfStatement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    complexity++;
    super.visitForStatement(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    complexity++;
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    complexity++;
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    complexity++;
    super.visitDoStatement(node);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    complexity++;
    super.visitSwitchCase(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    complexity++;
    super.visitConditionalExpression(node);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') complexity++;
    super.visitBinaryExpression(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    complexity++;
    super.visitCatchClause(node);
  }
}

class _FunctionNode {
  const _FunctionNode({
    required this.id,
    required this.filePath,
    required this.name,
    required this.lineStart,
    required this.lineEnd,
    required this.complexity,
    required this.hasDocComment,
  });

  final String id;
  final String filePath;
  final String name;
  final int lineStart;
  final int lineEnd;
  final int complexity;
  final bool hasDocComment;
}

class _ReferenceVisitor extends RecursiveAstVisitor<void> {
  final List<String> references = <String>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.inDeclarationContext()) {
      return;
    }
    references.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

String toJsonReport(ProjectVibrancyReport report) {
  return const JsonEncoder.withIndent('  ').convert(report.toJson());
}

Future<String?> _gitBlobHash(String filePath) async {
  final proc = await Process.run('git', <String>['hash-object', filePath]);
  if (proc.exitCode != 0) return null;
  final out = proc.stdout;
  if (out is! String) return null;
  final trimmed = out.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _stableHash(String input) {
  // Lightweight deterministic hash for cache keying.
  var h = 2166136261;
  for (final u in input.codeUnits) {
    h ^= u;
    h = (h * 16777619) & 0xffffffff;
  }
  return h.toRadixString(16);
}

class _ProjectVibrancyCache {
  _ProjectVibrancyCache(this.path, this.data);

  final String path;
  final Map<String, Object?> data;

  static _ProjectVibrancyCache open(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return _ProjectVibrancyCache(path, <String, Object?>{
        'schemaVersion': 1,
        'blameByBlob': <String, Object?>{},
        'lcovByFingerprint': <String, Object?>{},
      });
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, Object?>) {
        return _ProjectVibrancyCache(path, decoded);
      }
      stderr.writeln(
        'Project vibrancy cache ignored: root JSON is not an object.',
      );
    } on Object catch (e, st) {
      stderr.writeln('Project vibrancy cache ignored: $e');
      stderr.writeln('$st');
    }
    return _ProjectVibrancyCache(path, <String, Object?>{
      'schemaVersion': 1,
      'blameByBlob': <String, Object?>{},
      'lcovByFingerprint': <String, Object?>{},
    });
  }

  Map<int, int>? getBlame(String blobHash) {
    final table = data['blameByBlob'];
    if (table is! Map) return null;
    final value = table[blobHash];
    if (value is! Map) return null;
    final out = <int, int>{};
    value.forEach((k, v) {
      final kk = int.tryParse('$k');
      final vv = int.tryParse('$v');
      if (kk != null && vv != null) out[kk] = vv;
    });
    return out;
  }

  void setBlame(String blobHash, Map<int, int> blame) {
    final table = (data['blameByBlob'] as Map?) ?? <String, Object?>{};
    data['blameByBlob'] = table;
    table[blobHash] = blame.map((k, v) => MapEntry('$k', v));
  }

  Map<String, Set<int>>? getLcov(String fingerprint) {
    final table = data['lcovByFingerprint'];
    if (table is! Map) return null;
    final value = table[fingerprint];
    if (value is! Map) return null;
    final out = <String, Set<int>>{};
    value.forEach((k, v) {
      if (k is! String || v is! List) return;
      out[k] = v.map((e) => int.tryParse('$e')).whereType<int>().toSet();
    });
    return out;
  }

  void setLcov(String fingerprint, Map<String, Set<int>> byFile) {
    final table = (data['lcovByFingerprint'] as Map?) ?? <String, Object?>{};
    data['lcovByFingerprint'] = table;
    table[fingerprint] = byFile.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  void save() {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }
}
