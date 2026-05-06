/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/COMMENT_COVERAGE_PLAN.md`.

#!/usr/bin/env dart
// ignore_for_file: avoid_print

// CLI tool to run dart analyze and display severity summary.
//
// Usage:
//   dart run saropa_lints:impact_report [path]
//   dart run saropa_lints:impact_report --help
//
// This tool:
// 1. Runs `dart analyze` on your project
// 2. Parses the output to extract violations
// 3. Displays a summary grouped by severity (error / warning / info)
// 4. Shows errors first

import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/models/violation.dart';
import 'package:saropa_lints/src/violation_parser.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();

    return;
  }

  final path = args.isNotEmpty ? args.first : '.';

  print('Running lint analysis...');
  print('');

  final result = await Process.run(
    'dart',
    ['analyze'],
    workingDirectory: path,
    runInShell: true,
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  if (stderr.isNotEmpty && !stderr.contains('Analyzing')) {
    print('Error running dart analyze:');
    print(stderr);
    exit(1);
  }

  final violations = parseViolations(output);

  if (violations.isEmpty) {
    print('No issues found!');
    print('');
    print('Severity Summary');
    print('================');
    print('ERRORS:   0');
    print('WARNINGS: 0');
    print('INFO:     0');

    return;
  }

  // Group by severity (3 buckets — error/warning/info — collapsed from the
  // prior 5-bucket impact taxonomy on 2026-05-03).
  final byImpact = <LintImpact, List<Violation>>{
    LintImpact.error: [],
    LintImpact.warning: [],
    LintImpact.info: [],
  };

  for (final v in violations) {
    final impact = v.impact;
    if (impact != null) {
      final list = byImpact[impact];
      if (list != null) list.add(v);
    }
  }

  // Print violations sorted by severity (errors first).
  var printed = false;
  for (final impact in LintImpact.values) {
    final list = byImpact[impact] ?? [];
    if (list.isEmpty) continue;

    if (printed) print('');
    printed = true;

    final label = impact.name.toUpperCase();
    print('--- $label (${list.length}) ---');
    for (final v in list) {
      print('  ${v.file}:${v.line} - ${v.rule}');
    }
  }

  print('');
  print('Severity Summary');
  print('================');

  final errorCount = (byImpact[LintImpact.error] ?? []).length;
  final warningCount = (byImpact[LintImpact.warning] ?? []).length;
  final infoCount = (byImpact[LintImpact.info] ?? []).length;

  if (errorCount > 0) {
    print('ERRORS:   $errorCount (must fix)');
  } else {
    print('ERRORS:   0');
  }

  if (warningCount > 0) {
    print('WARNINGS: $warningCount (could fail or look bad)');
  } else {
    print('WARNINGS: 0');
  }

  if (infoCount > 0) {
    print('INFO:     $infoCount (FYI)');
  } else {
    print('INFO:     0');
  }

  print('');
  print('Total: ${violations.length} issues');

  // Exit with code = number of errors (capped at 125 to fit a POSIX byte).
  if (errorCount > 0) {
    print('');
    print('$errorCount error(s) found.');
    exit(errorCount > 125 ? 125 : errorCount);
  }
}

void _printUsage() {
  print('saropa_lints Severity Report');
  print('');
  print('Usage: dart run saropa_lints:impact_report [path]');
  print('');
  print('Runs dart analyze and displays results grouped by severity.');
  print('Errors are shown first, then warnings, then info.');
  print('');
  print('Options:');
  print('  --help, -h    Show this help message');
  print('');
  print('Exit codes:');
  print('  0             No errors');
  print('  1-125         Number of errors found');
  print('');
  print('Example:');
  print('  dart run saropa_lints:impact_report');
  print('  dart run saropa_lints:impact_report ./my_project');
}
