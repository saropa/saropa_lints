#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Cross-file analysis CLI (unused files, circular deps, feature deps, etc.).
///
/// Run `dart run saropa_lints:cross_file --help` for commands and options.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
import 'package:saropa_lints/src/cli/cross_file_baseline.dart';
import 'package:saropa_lints/src/cli/cross_file_dot_reporter.dart';
import 'package:saropa_lints/src/cli/cross_file_html_reporter.dart';
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

Future<void> main(List<String> args) async {
  final exitCode = await _run(args);
  exit(exitCode);
}

Future<int> _run(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return 0;
  }

  String projectPath = p.current;
  String outputFormat = 'text';
  String? outputDir;
  String? baselinePath;
  bool updateBaseline = false;
  bool includePrivateSymbols = false;
  bool excludePublicApi = false;
  bool heuristicUnusedSymbols = false;
  int watchDebounceMs = 600;
  String watchCommand = 'import-stats';
  final excludes = <String>[];

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg == '--path' && i + 1 < args.length) {
      projectPath = args[++i];
    } else if (arg == '--output' && i + 1 < args.length) {
      outputFormat = args[++i];
    } else if (arg == '--output-dir' && i + 1 < args.length) {
      outputDir = args[++i];
    } else if (arg == '--baseline' && i + 1 < args.length) {
      baselinePath = args[++i];
    } else if (arg == '--update-baseline') {
      updateBaseline = true;
    } else if (arg == '--exclude' && i + 1 < args.length) {
      excludes.add(args[++i]);
    } else if (arg == '--include-private') {
      includePrivateSymbols = true;
    } else if (arg == '--exclude-public-api') {
      excludePublicApi = true;
    } else if (arg == '--heuristic-unused-symbols') {
      heuristicUnusedSymbols = true;
    } else if (arg == '--exclude-overrides') {
      // Reserved for method-level analysis; currently no-op.
    } else if (arg == '--watch-debounce-ms' && i + 1 < args.length) {
      watchDebounceMs = int.tryParse(args[++i]) ?? watchDebounceMs;
    } else if (arg == '--command' && i + 1 < args.length) {
      watchCommand = args[++i];
    } else if (!arg.startsWith('-')) {
      break;
    }
    i++;
  }

  final rest = args.skip(i).toList();
  if (rest.isEmpty) {
    print('Error: missing command.');
    _printUsage();
    return 2;
  }

  final command = rest.first;
  final validCommands = [
    'unused-files',
    'circular-deps',
    'import-stats',
    'feature-deps',
    'unused-symbols',
    'dead-imports',
    'watch',
    'report',
    'graph',
  ];
  if (!validCommands.contains(command)) {
    print('Error: unknown command "$command".');
    _printUsage();
    return 2;
  }

  final dir = Directory(projectPath);
  if (!dir.existsSync()) {
    print('Error: path does not exist: $projectPath');
    return 2;
  }

  // Allow --output-dir after the command as well (e.g. `report --output-dir x`).
  final outputDirIdx = rest.indexOf('--output-dir');
  if (outputDirIdx >= 0 && outputDirIdx + 1 < rest.length) {
    outputDir = rest[outputDirIdx + 1];
  }

  final resolvedOutputDir = outputDir ?? 'reports';
  final normalizedWatchDebounceMs = watchDebounceMs < 100
      ? 100
      : watchDebounceMs;

  if (command == 'watch') {
    final watchTarget = watchCommand.trim().isEmpty
        ? 'import-stats'
        : watchCommand;
    const forbidden = {'watch', 'report', 'graph'};
    if (forbidden.contains(watchTarget)) {
      stderr.writeln(
        'Error: --command for watch must be one of unused-files, circular-deps, import-stats, feature-deps, dead-imports, unused-symbols.',
      );
      return 2;
    }
    if (!validCommands.contains(watchTarget)) {
      stderr.writeln('Error: unknown watch command "$watchTarget".');
      return 2;
    }
    return await _runWatchMode(
      projectPath: projectPath,
      watchCommand: watchTarget,
      outputFormat: outputFormat,
      excludeGlobs: excludes,
      includePrivateSymbols: includePrivateSymbols,
      excludePublicApi: excludePublicApi,
      heuristicUnusedSymbols: heuristicUnusedSymbols,
      debounceMs: normalizedWatchDebounceMs,
    );
  }

  // Build import graph and run analysis (unused files, circular deps, stats).
  // All commands share this step; the graph command only uses includedPaths.
  stderr.writeln('Building import graph...');
  CrossFileResult result;
  try {
    result = await runCrossFileAnalysis(
      projectPath: projectPath,
      excludeGlobs: excludes,
      unusedSymbolsOptions: command == 'unused-symbols'
          ? UnusedSymbolsOptions(
              includePrivate: includePrivateSymbols,
              excludePublicApi: excludePublicApi,
              forceHeuristic: heuristicUnusedSymbols,
            )
          : null,
    );
  } on Object catch (e, st) {
    // Fix: avoid_print_error / avoid_stack_trace_in_production — structured
    // CLI error output goes to stderr with a single diagnostic line. The
    // stack trace is only printed when SAROPA_DEBUG is set so production
    // runs do not leak implementation details.
    stderr.writeln('Error: $e');
    if (Platform.environment['SAROPA_DEBUG'] == '1') {
      stderr.writeln(st);
    }
    return 2;
  }

  if (updateBaseline) {
    final path = baselinePath ?? 'cross_file_baseline.json';
    CrossFileBaseline(
      unusedFiles: result.unusedFiles,
      circularDependencies: result.circularDependencies,
      missingMirrorTests: result.missingMirrorTests,
    ).save(path);
    stderr.writeln('Baseline written to $path');
    return 0;
  }

  if (command == 'report') {
    reportToHtml(result, resolvedOutputDir);
    stderr.writeln('HTML report written to $resolvedOutputDir/');
    return 0;
  }

  if (command == 'graph') {
    final dotPath = '$resolvedOutputDir/import_graph.dot';
    // Pass includedPaths so the DOT output respects --exclude filters.
    // When empty (no excludes active), exportDotGraph falls back to the full
    // graph — see includedPaths parameter doc.
    exportDotGraph(
      projectPath: projectPath,
      outputPath: dotPath,
      includedPaths: result.includedPaths.isEmpty ? null : result.includedPaths,
    );
    stderr.writeln('DOT graph written to $dotPath');
    stderr.writeln(
      'Render with: dot -Tsvg $dotPath -o $resolvedOutputDir/import_graph.svg',
    );
    return 0;
  }

  CrossFileReporter.report(result, format: outputFormat, sink: stdout);

  if (baselinePath != null) {
    final base = CrossFileBaseline.load(baselinePath);
    if (CrossFileBaseline.hasNewViolations(result, base)) {
      return 1;
    }
    return 0;
  }

  final hasIssues =
      result.unusedFiles.isNotEmpty ||
      result.circularDependencies.isNotEmpty ||
      result.missingMirrorTests.isNotEmpty ||
      result.deadImports.isNotEmpty ||
      result.unusedSymbols.isNotEmpty;
  return hasIssues ? 1 : 0;
}

void _printUsage() {
  print('''
Cross-file analysis (unused files, circular deps, lib/test mirror gaps, import stats).

Usage: dart run saropa_lints:cross_file <command> [options]

Commands:
  unused-files   Find files not imported by any other file
  circular-deps  Detect circular import chains
  import-stats   Show import graph statistics
  feature-deps   Show cross-feature dependency imports
  unused-symbols Find likely unused top-level symbols
  dead-imports   Find likely dead relative imports
  watch          Re-run cross-file analysis on file changes
  report         Write HTML report (use --output-dir)
  graph          Export import graph in DOT format (use --output-dir)

Options:
  --path <dir>         Project directory (default: current)
  --output <fmt>       Output format: text, json (default: text)
  --output-dir <path>  Directory for report/graph output (default: reports)
  --baseline <file>    Load baseline JSON; exit 0 only if no new violations
  --update-baseline    Write current results to baseline file (default: cross_file_baseline.json)
  --exclude <glob>     Exclude matching paths from results (can repeat)
  --include-private    Include private symbols for unused-symbol analysis
  --exclude-public-api Skip symbols from lib files that are exported by other lib files
  --heuristic-unused-symbols  Use regex heuristic only (skip analyzer resolution)
  --exclude-overrides  Reserved for method-level analysis (currently no-op)
  --command <name>     For watch mode: command to run per change (default: import-stats)
  --watch-debounce-ms  For watch mode: debounce window in ms (default: 600, min: 100)
  -h, --help           Show this help

Exit codes: 0 = no issues, 1 = issues found (unused files, circular imports,
or lib sources without a mirror *_test.dart), 2 = configuration error
''');
}

Future<int> _runWatchMode({
  required String projectPath,
  required String watchCommand,
  required String outputFormat,
  required List<String> excludeGlobs,
  required bool includePrivateSymbols,
  required bool excludePublicApi,
  required bool heuristicUnusedSymbols,
  required int debounceMs,
}) async {
  final root = Directory(projectPath);
  final libDir = Directory(p.join(projectPath, 'lib'));
  final testDir = Directory(p.join(projectPath, 'test'));
  if (!libDir.existsSync() && !testDir.existsSync()) {
    stderr.writeln(
      'Error: watch mode expects lib/ or test/ directories under $projectPath.',
    );
    return 2;
  }

  DateTime? lastRunAt;
  CrossFileResult? previous;
  Future<void> runOnce(String trigger) async {
    final now = DateTime.now();
    if (lastRunAt != null &&
        now.difference(lastRunAt!).inMilliseconds < debounceMs) {
      return;
    }
    lastRunAt = now;

    stderr.writeln('');
    stderr.writeln('[watch] Trigger: $trigger');
    stderr.writeln(
      '[watch] Running: dart run saropa_lints:cross_file $watchCommand --path $projectPath',
    );
    try {
      final result = await runCrossFileAnalysis(
        projectPath: projectPath,
        excludeGlobs: excludeGlobs,
        unusedSymbolsOptions: watchCommand == 'unused-symbols'
            ? UnusedSymbolsOptions(
                includePrivate: includePrivateSymbols,
                excludePublicApi: excludePublicApi,
                forceHeuristic: heuristicUnusedSymbols,
              )
            : null,
      );
      CrossFileReporter.report(result, format: outputFormat, sink: stdout);
      final diff = _buildWatchDiff(
        previous: previous,
        current: result,
        command: watchCommand,
      );
      if (diff != null) {
        stderr.writeln(diff);
      }
      previous = result;
      stderr.writeln('[watch] Done.');
    } on Object catch (e) {
      stderr.writeln('[watch] Error: $e');
    }
  }

  stderr.writeln(
    'Watching Dart files in $projectPath (command: $watchCommand, debounce: ${debounceMs}ms). Press Ctrl+C to stop.',
  );
  await runOnce('initial');

  await for (final event in root.watch(recursive: true)) {
    final normalized = p.normalize(event.path).replaceAll('\\', '/');
    final rootPosix = p.normalize(projectPath).replaceAll('\\', '/');
    final rel = normalized.replaceFirst(
      RegExp('^${RegExp.escape(rootPosix)}/?'),
      '',
    );
    if (!rel.toLowerCase().endsWith('.dart')) continue;
    if (!rel.startsWith('lib/') && !rel.startsWith('test/')) continue;
    await runOnce(rel);
  }
  return 0;
}

String? _buildWatchDiff({
  required CrossFileResult? previous,
  required CrossFileResult current,
  required String command,
}) {
  if (previous == null) return null;

  (int, int) diffCounts(Set<String> before, Set<String> after) {
    final added = after.difference(before).length;
    final removed = before.difference(after).length;
    return (added, removed);
  }

  if (command == 'unused-files') {
    final (added, removed) = diffCounts(
      previous.unusedFiles.toSet(),
      current.unusedFiles.toSet(),
    );
    return '[watch] Diff unused-files: +$added new, -$removed resolved';
  }

  if (command == 'circular-deps') {
    Set<String> cycleKeys(List<List<String>> cycles) =>
        cycles.map((c) => c.join(' -> ')).toSet();
    final (added, removed) = diffCounts(
      cycleKeys(previous.circularDependencies),
      cycleKeys(current.circularDependencies),
    );
    return '[watch] Diff circular-deps: +$added new, -$removed resolved';
  }

  if (command == 'feature-deps') {
    final (added, removed) = diffCounts(
      previous.crossFeatureImports.toSet(),
      current.crossFeatureImports.toSet(),
    );
    return '[watch] Diff feature-deps: +$added new edge(s), -$removed resolved edge(s)';
  }

  if (command == 'dead-imports') {
    Set<String> flattenDeadImports(Map<String, List<String>> data) {
      final out = <String>{};
      for (final entry in data.entries) {
        for (final uri in entry.value) {
          out.add('${entry.key} -> $uri');
        }
      }
      return out;
    }

    final (added, removed) = diffCounts(
      flattenDeadImports(previous.deadImports),
      flattenDeadImports(current.deadImports),
    );
    return '[watch] Diff dead-imports: +$added new, -$removed resolved';
  }

  if (command == 'unused-symbols') {
    Set<String> flattenUnusedSymbols(Map<String, List<String>> data) {
      final out = <String>{};
      for (final entry in data.entries) {
        for (final symbol in entry.value) {
          out.add('${entry.key}::$symbol');
        }
      }
      return out;
    }

    final (added, removed) = diffCounts(
      flattenUnusedSymbols(previous.unusedSymbols),
      flattenUnusedSymbols(current.unusedSymbols),
    );
    return '[watch] Diff unused-symbols: +$added new, -$removed resolved';
  }

  if (command == 'import-stats') {
    final prevFiles = previous.stats['fileCount'] ?? 0;
    final prevImports = previous.stats['totalImports'] ?? 0;
    final currFiles = current.stats['fileCount'] ?? 0;
    final currImports = current.stats['totalImports'] ?? 0;
    final fileDelta = currFiles - prevFiles;
    final importDelta = currImports - prevImports;
    return '[watch] Diff import-stats: files ${fileDelta >= 0 ? '+' : ''}$fileDelta, imports ${importDelta >= 0 ? '+' : ''}$importDelta';
  }

  return null;
}

String? buildWatchDiffForTest({
  required CrossFileResult? previous,
  required CrossFileResult current,
  required String command,
}) => _buildWatchDiff(previous: previous, current: current, command: command);
