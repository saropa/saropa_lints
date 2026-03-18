#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Cross-file analysis CLI: unused files, circular deps, import stats.
///
/// Usage:
///   dart run saropa_lints:cross_file [command] [options]
///
/// Commands:
///   unused-files   Find files not imported by any other file
///   circular-deps  Detect circular import chains
///   import-stats   Show import graph statistics
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_analyzer.dart';
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
  final excludes = <String>[];

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    if (arg == '--path' && i + 1 < args.length) {
      projectPath = args[++i];
    } else if (arg == '--output' && i + 1 < args.length) {
      outputFormat = args[++i];
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
  final validCommands = ['unused-files', 'circular-deps', 'import-stats'];
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

  // Options must appear before the command; --exclude is reserved for future use.
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

  CrossFileReporter.report(result, format: outputFormat, sink: stdout);

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

Options:
  --path <dir>     Project directory (default: current)
  --output <fmt>   Output format: text, json (default: text)
  --exclude <glob> Reserved for future use (can repeat)
  -h, --help       Show this help

Exit codes: 0 = no issues, 1 = issues found, 2 = configuration error
''');
}
