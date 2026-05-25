#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see
/// `plans/COMMENT_COVERAGE_PLAN.md`.

library;

// `bin/project_vibrancy.dart` — CLI for the **project vibrancy** scan (`lib/src/cli/project_vibrancy.dart`).
// Parses flags (`--path`, `--format`, `--lcov`, `--file`, `--folder`, `--since`, grade/coverage caps),
// runs [runProjectVibrancy], prints JSON or text, and maps thresholds to **non-zero exit codes** for CI.
// `--since` narrows analysis to git-changed Dart files (see [_changedDartFilesSince]).
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/project_vibrancy.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  final projectPath = p.normalize(
    p.absolute(_readOption(args, '--path') ?? p.current),
  );
  final format = _readOption(args, '--format') ?? 'json';
  final lcovPath = _readOption(args, '--lcov') ?? 'coverage/lcov.info';
  final filePath = _readOption(args, '--file');
  final folderPath = _readOption(args, '--folder');
  final since = _readOption(args, '--since');
  final minGrade = (_readOption(args, '--min-grade') ?? 'F').toUpperCase();
  final maxUnused = int.tryParse(_readOption(args, '--max-unused') ?? '');
  final maxUncovered = int.tryParse(_readOption(args, '--max-uncovered') ?? '');
  final maxStubTested = int.tryParse(
    _readOption(args, '--max-stub-tested') ?? '',
  );
  final maxSuspiciousCoverage = int.tryParse(
    _readOption(args, '--max-suspicious-coverage') ?? '',
  );
  final maxTestDrift = int.tryParse(
    _readOption(args, '--max-test-drift') ?? '',
  );

  final includedFiles = since == null
      ? null
      : await _changedDartFilesSince(projectPath, since);

  // --progress streams NDJSON scan events to stderr (the dashboard webview
  // consumes them for a live progress bar + current file). --control <path>
  // points at a tiny text file the dashboard rewrites with run/pause/cancel so
  // the user can suspend or abort a long scan. Both are opt-in; without them the
  // CLI/CI output is byte-for-byte unchanged. stdout stays the pure report JSON.
  final wantsProgress = args.contains('--progress');
  final controlPath = _readOption(args, '--control');
  final progress = wantsProgress
      ? ProjectScanProgress(onEvent: _emitEvent, gate: _makeGate(controlPath))
      : null;

  final options = ProjectVibrancyOptions(
    projectPath: projectPath,
    lcovPath: lcovPath,
    filePath: filePath == null
        ? null
        : p.normalize(
            p.isAbsolute(filePath) ? filePath : p.join(projectPath, filePath),
          ),
    folderPath: folderPath == null
        ? null
        : p.normalize(
            p.isAbsolute(folderPath)
                ? folderPath
                : p.join(projectPath, folderPath),
          ),
    includedFiles: includedFiles,
  );

  final ProjectVibrancyReport report;
  try {
    report = await runProjectVibrancy(options, progress: progress);
  } on _ScanCancelled {
    // User cancelled from the dashboard. Exit clean with no stdout payload —
    // the extension treats an empty result after a cancel request as "stopped",
    // not "failed", so no error toast fires.
    exit(0);
  }

  var exitCode = 0;
  final avgGrade = _averageGrade(report);
  final unusedCount = report.functions
      .where((f) => f.flags.contains('unused'))
      .length;
  final uncoveredCount = report.functions
      .where((f) => f.flags.contains('uncovered'))
      .length;
  final stubTestedCount = report.functions
      .where((f) => f.flags.contains('stub_tested'))
      .length;
  final suspiciousCoverageCount = report.functions
      .where((f) => f.flags.contains('suspicious_coverage'))
      .length;
  final testDriftCount = report.functions
      .where((f) => f.flags.contains('test_drift'))
      .length;
  if (_gradeRank(avgGrade) > _gradeRank(minGrade)) {
    stderr.writeln(
      'Gate failed: average grade $avgGrade is below minimum $minGrade',
    );
    exitCode = 1;
  }
  if (maxUnused != null && unusedCount > maxUnused) {
    stderr.writeln(
      'Gate failed: unused functions $unusedCount > max-unused $maxUnused',
    );
    exitCode = 1;
  }
  if (maxUncovered != null && uncoveredCount > maxUncovered) {
    stderr.writeln(
      'Gate failed: uncovered functions $uncoveredCount > max-uncovered $maxUncovered',
    );
    exitCode = 1;
  }
  if (maxStubTested != null && stubTestedCount > maxStubTested) {
    stderr.writeln(
      'Gate failed: stub_tested functions $stubTestedCount > max-stub-tested $maxStubTested',
    );
    exitCode = 1;
  }
  if (maxSuspiciousCoverage != null &&
      suspiciousCoverageCount > maxSuspiciousCoverage) {
    stderr.writeln(
      'Gate failed: suspicious_coverage functions $suspiciousCoverageCount > max-suspicious-coverage $maxSuspiciousCoverage',
    );
    exitCode = 1;
  }
  if (maxTestDrift != null && testDriftCount > maxTestDrift) {
    stderr.writeln(
      'Gate failed: test_drift functions $testDriftCount > max-test-drift $maxTestDrift',
    );
    exitCode = 1;
  }

  if (format == 'text') {
    for (final fn in report.functions.take(200)) {
      final flags = fn.flags.isEmpty ? '' : ' [${fn.flags.join(', ')}]';
      print(
        '${fn.grade} ${fn.score.toStringAsFixed(1)}'
        ' ${fn.file}:${fn.lineStart}-${fn.lineEnd}'
        ' ${fn.name}$flags',
      );
    }
    print('');
    print('Functions scored: ${report.functions.length}');
    final base = report.toJson();
    final summaryRaw = base['summary'];
    final summary = summaryRaw is Map<String, Object?>
        ? summaryRaw
        : <String, Object?>{};
    final avgRaw = summary['averageScore'];
    final avgScore = avgRaw is num ? avgRaw.toDouble() : 0.0;
    final gradeRaw = summary['averageGrade'];
    final gradeStr = gradeRaw is String ? gradeRaw : 'F';
    print('Average: ${avgScore.toStringAsFixed(1)} ($gradeStr)');
    print(
      'Unused: $unusedCount, Uncovered: $uncoveredCount, '
      'stub_tested: $stubTestedCount, suspicious_coverage: $suspiciousCoverageCount, '
      'test_drift: $testDriftCount',
    );
    exit(exitCode);
  }

  final payload = _buildJsonPayload(
    report: report,
    minGrade: minGrade,
    maxUnused: maxUnused,
    maxUncovered: maxUncovered,
    avgGrade: avgGrade,
    unusedCount: unusedCount,
    uncoveredCount: uncoveredCount,
    stubTestedCount: stubTestedCount,
    suspiciousCoverageCount: suspiciousCoverageCount,
    testDriftCount: testDriftCount,
    maxStubTested: maxStubTested,
    maxSuspiciousCoverage: maxSuspiciousCoverage,
    maxTestDrift: maxTestDrift,
    since: since,
    exitCode: exitCode,
  );
  // Signal scan completion before the payload so the webview can flip from the
  // scanning view to the rendered dashboard the instant stdout arrives.
  if (progress != null) {
    _emitEvent(<String, Object?>{'event': 'done'});
  }
  print(const JsonEncoder.withIndent('  ').convert(payload));
  exit(exitCode);
}

String? _readOption(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// Writes one scan event as a single NDJSON line on stderr. stdout is reserved
/// for the final report JSON, so the extension parses the two streams separately.
void _emitEvent(Map<String, Object?> event) {
  stderr.writeln(jsonEncode(event));
}

/// Thrown by the control gate when the dashboard requests cancel; caught in
/// [main] to exit cleanly without emitting a partial report.
class _ScanCancelled implements Exception {
  const _ScanCancelled();
}

/// Builds the cooperative pause/cancel gate the scan awaits before each unit of
/// work. With no control file it is a no-op. With one, it reads the file's
/// current command: `pause` blocks (re-checking every 150 ms) until the command
/// changes; `cancel` throws [_ScanCancelled]; anything else resumes immediately.
Future<void> Function() _makeGate(String? controlPath) {
  if (controlPath == null) {
    return () async {};
  }
  return () async {
    while (true) {
      final command = _readControl(controlPath);
      if (command == 'cancel') {
        throw const _ScanCancelled();
      }
      if (command != 'pause') {
        return;
      }
      // Poll while paused. 150 ms is responsive to a Resume click without
      // busy-spinning a CPU core during a long pause.
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  };
}

/// Reads the control command, defaulting to `run` on any miss/error so a missing
/// or transiently-locked control file never wedges the scan.
String _readControl(String controlPath) {
  try {
    final file = File(controlPath);
    if (!file.existsSync()) return 'run';
    return file.readAsStringSync().trim().toLowerCase();
  } on Object {
    return 'run';
  }
}

void _printUsage() {
  print('Project Vibrancy (MVP): function-level project code health scoring.');
  print('');
  print('Usage: dart run saropa_lints:project_vibrancy [options]');
  print('');
  print('Options:');
  print('  --path <dir>      Project root (default: current directory)');
  print('  --format <fmt>    Output format: json | text (default: json)');
  print('  --lcov <path>     LCOV path (default: coverage/lcov.info)');
  print('  --file <path>     Analyze one Dart file only');
  print('  --folder <path>   Analyze Dart files under one folder only');
  print('  --since <ref>     Analyze Dart files changed since git ref');
  print('  --min-grade <A-F> Fail if average grade is below this (default: F)');
  print('  --max-unused <n>  Fail if unused function count exceeds n');
  print('  --max-uncovered <n>  Fail if uncovered function count exceeds n');
  print(
    '  --max-stub-tested <n>  Fail if stub_tested function count exceeds n',
  );
  print(
    '  --max-suspicious-coverage <n>  Fail if suspicious_coverage count exceeds n',
  );
  print('  --max-test-drift <n>  Fail if test_drift function count exceeds n');
  print('  -h, --help        Show this help');
}

Future<Set<String>> _changedDartFilesSince(
  String projectPath,
  String since,
) async {
  final proc = await Process.run('git', <String>[
    'diff',
    '--name-only',
    '$since...HEAD',
  ], workingDirectory: projectPath);
  if (proc.exitCode != 0) {
    return const <String>{};
  }
  final files = <String>{};
  final stdoutText = proc.stdout;
  if (stdoutText is! String) return files;
  for (final raw in stdoutText.split('\n')) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.endsWith('.dart')) continue;
    files.add(p.normalize(p.join(projectPath, trimmed)));
  }
  return files;
}

String _averageGrade(ProjectVibrancyReport report) {
  if (report.functions.isEmpty) return 'F';
  final sum = report.functions.fold<double>(0, (total, f) => total + f.score);
  final avg = sum / report.functions.length;
  if (avg >= 80) return 'A';
  if (avg >= 65) return 'B';
  if (avg >= 50) return 'C';
  if (avg >= 35) return 'D';
  if (avg >= 20) return 'E';
  return 'F';
}

int _gradeRank(String grade) {
  switch (grade) {
    case 'A':
      return 0;
    case 'B':
      return 1;
    case 'C':
      return 2;
    case 'D':
      return 3;
    case 'E':
      return 4;
    default:
      return 5;
  }
}

Map<String, Object?> _buildJsonPayload({
  required ProjectVibrancyReport report,
  required String minGrade,
  required int? maxUnused,
  required int? maxUncovered,
  required int? maxStubTested,
  required int? maxSuspiciousCoverage,
  required int? maxTestDrift,
  required String avgGrade,
  required int unusedCount,
  required int uncoveredCount,
  required int stubTestedCount,
  required int suspiciousCoverageCount,
  required int testDriftCount,
  required String? since,
  required int exitCode,
}) {
  final base = report.toJson();
  final summaryRaw = base['summary'];
  final summary = summaryRaw is Map<String, Object?>
      ? summaryRaw
      : <String, Object?>{};
  final avgRaw = summary['averageScore'];
  final avgScore = avgRaw is num ? avgRaw.toDouble() : 0.0;
  final gateViolations = <Map<String, Object?>>[];
  if (_gradeRank(avgGrade) > _gradeRank(minGrade)) {
    gateViolations.add(<String, Object?>{
      'gate': 'min_grade',
      'expected': minGrade,
      'actual': avgGrade,
      'message': 'Average grade is below configured minimum.',
    });
  }
  if (maxUnused != null && unusedCount > maxUnused) {
    gateViolations.add(<String, Object?>{
      'gate': 'max_unused',
      'expected': maxUnused,
      'actual': unusedCount,
      'message': 'Unused function count exceeds threshold.',
    });
  }
  if (maxUncovered != null && uncoveredCount > maxUncovered) {
    gateViolations.add(<String, Object?>{
      'gate': 'max_uncovered',
      'expected': maxUncovered,
      'actual': uncoveredCount,
      'message': 'Uncovered function count exceeds threshold.',
    });
  }
  if (maxStubTested != null && stubTestedCount > maxStubTested) {
    gateViolations.add(<String, Object?>{
      'gate': 'max_stub_tested',
      'expected': maxStubTested,
      'actual': stubTestedCount,
      'message': 'stub_tested function count exceeds threshold.',
    });
  }
  if (maxSuspiciousCoverage != null &&
      suspiciousCoverageCount > maxSuspiciousCoverage) {
    gateViolations.add(<String, Object?>{
      'gate': 'max_suspicious_coverage',
      'expected': maxSuspiciousCoverage,
      'actual': suspiciousCoverageCount,
      'message': 'suspicious_coverage count exceeds threshold.',
    });
  }
  if (maxTestDrift != null && testDriftCount > maxTestDrift) {
    gateViolations.add(<String, Object?>{
      'gate': 'max_test_drift',
      'expected': maxTestDrift,
      'actual': testDriftCount,
      'message': 'test_drift function count exceeds threshold.',
    });
  }

  return <String, Object?>{
    'schemaVersion': 'project-vibrancy.v1',
    'determinism': <String, Object?>{
      'functionOrdering': 'score_asc_then_file_then_name',
      'rounding': 'score_1dp',
      'since': since,
    },
    'gates': <String, Object?>{
      'minGrade': minGrade,
      'maxUnused': maxUnused,
      'maxUncovered': maxUncovered,
      'maxStubTested': maxStubTested,
      'maxSuspiciousCoverage': maxSuspiciousCoverage,
      'maxTestDrift': maxTestDrift,
      'pass': exitCode == 0,
      'violations': gateViolations,
    },
    'summary': <String, Object?>{
      ...summary,
      'averageScore': avgScore,
      'averageGrade': avgGrade,
      'unusedCount': unusedCount,
      'uncoveredCount': uncoveredCount,
      'stubTestedCount': stubTestedCount,
      'suspiciousCoverageCount': suspiciousCoverageCount,
      'testDriftCount': testDriftCount,
    },
    'projectPath': base['projectPath'],
    'generatedAt': base['generatedAt'],
    'functions': base['functions'],
  };
}
