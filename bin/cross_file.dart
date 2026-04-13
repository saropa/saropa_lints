#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Cross-file analysis CLI: unused files, circular deps, import stats, graph.
///
/// Usage:
///   dart run saropa_lints:cross_file [command] [options]
///
/// Commands:
///   unused-files   Find files not imported by any other file
///   circular-deps  Detect circular import chains
///   import-stats   Show import graph statistics
///   report         Write HTML report (use --output-dir)
///   graph          Export import graph in DOT format (use --output-dir)
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

  // Build import graph and run analysis (unused files, circular deps, stats).
  // All commands share this step; the graph command only uses includedPaths.
  stderr.writeln('Building import graph...');
  CrossFileResult result;
  try {
    result = await runCrossFileAnalysis(
      projectPath: projectPath,
      excludeGlobs: excludes,
    );
  } catch (e, st) {
    print('Error: $e');
    print(st);
    return 2;
  }

  if (updateBaseline) {
    final path = baselinePath ?? 'cross_file_baseline.json';
    CrossFileBaseline(
      unusedFiles: result.unusedFiles,
      circularDependencies: result.circularDependencies,
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
      includedPaths:
          result.includedPaths.isEmpty ? null : result.includedPaths,
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

  final hasIssues = result.unusedFiles.isNotEmpty ||
      result.circularDependencies.isNotEmpty;
  return hasIssues ? 1 : 0;
}

void _printUsage() {
  print('''
Cross-file analysis (unused files, circular deps, import stats).

Usage: dart run saropa_lints:cross_file <command> [options]

Commands:
  unused-files   Find files not imported by any other file
  circular-deps  Detect circular import chains
  import-stats   Show import graph statistics
  report         Write HTML report (use --output-dir)
  graph          Export import graph in DOT format (use --output-dir)

Options:
  --path <dir>         Project directory (default: current)
  --output <fmt>       Output format: text, json (default: text)
  --output-dir <path>  Directory for report/graph output (default: reports)
  --baseline <file>    Load baseline JSON; exit 0 only if no new violations
  --update-baseline    Write current results to baseline file (default: cross_file_baseline.json)
  --exclude <glob>     Exclude matching paths from results (can repeat)
  -h, --help           Show this help

Exit codes: 0 = no issues, 1 = issues found, 2 = configuration error
''');
}
