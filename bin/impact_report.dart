#!/usr/bin/env dart
// ignore_for_file: avoid_print

// CLI tool to run custom_lint and display impact summary.
//
// Usage:
//   dart run saropa_lints:impact_report [path]
//   dart run saropa_lints:impact_report --help
//
// This tool:
// 1. Runs `dart run custom_lint` on your project
// 2. Parses the output to extract violations
// 3. Displays a summary grouped by impact level
// 4. Shows critical issues first

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

  // Run custom_lint
  final result = await Process.run(
    'dart',
    ['run', 'custom_lint'],
    workingDirectory: path,
    runInShell: true,
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  if (stderr.isNotEmpty && !stderr.contains('Analyzing')) {
    print('Error running custom_lint:');
    print(stderr);
    exit(1);
  }

  // Parse violations
  final violations = parseViolations(output);

  if (violations.isEmpty) {
    print('No issues found!');
    print('');
    print('Impact Summary');
    print('==============');
    print('CRITICAL: 0');
    print('HIGH:     0');
    print('MEDIUM:   0');
    print('LOW:      0');
    print('OPINIONATED: 0');
    return;
  }

  // Group by impact
  final byImpact = <LintImpact, List<Violation>>{
    LintImpact.critical: [],
    LintImpact.high: [],
    LintImpact.medium: [],
    LintImpact.low: [],
    LintImpact.opinionated: [],
  };

  for (final v in violations) {
    if (v.impact != null) {
      byImpact[v.impact!]!.add(v);
    }
  }

  // Print violations sorted by impact (critical first)
  var printed = false;
  for (final impact in LintImpact.values) {
    final list = byImpact[impact]!;
    if (list.isEmpty) continue;

    if (printed) print('');
    printed = true;

    final label = impact.name.toUpperCase();
    print('--- $label (${list.length}) ---');
    for (final v in list) {
      print('  ${v.file}:${v.line} - ${v.rule}');
    }
  }

  // Print summary
  print('');
  print('Impact Summary');
  print('==============');

  final criticalCount = byImpact[LintImpact.critical]!.length;
  final highCount = byImpact[LintImpact.high]!.length;
  final mediumCount = byImpact[LintImpact.medium]!.length;
  final lowCount = byImpact[LintImpact.low]!.length;
  final opinionatedCount = byImpact[LintImpact.opinionated]!.length;

  if (criticalCount > 0) {
    print('CRITICAL: $criticalCount (fix immediately!)');
  } else {
    print('CRITICAL: 0');
  }

  if (highCount > 0) {
    print('HIGH:     $highCount (address soon)');
  } else {
    print('HIGH:     0');
  }

  if (mediumCount > 0) {
    print('MEDIUM:   $mediumCount (tech debt)');
  } else {
    print('MEDIUM:   0');
  }

  if (lowCount > 0) {
    print('LOW:      $lowCount (style)');
  } else {
    print('LOW:      0');
  }

  if (opinionatedCount > 0) {
    print('OPINIONATED: $opinionatedCount (style)');
  } else {
    print('OPINIONATED: 0');
  }

  print('');
  print('Total: ${violations.length} issues');

  // Exit with code = number of critical issues (capped)
  if (criticalCount > 0) {
    print('');
    print('WARNING: $criticalCount critical issue(s) found!');
    exit(criticalCount > 125 ? 125 : criticalCount);
  }
}

void _printUsage() {
  print('saropa_lints Impact Report');
  print('');
  print('Usage: dart run saropa_lints:impact_report [path]');
  print('');
  print('Runs custom_lint and displays results grouped by impact level.');
  print('Critical issues are shown first, followed by high, medium, and low.');
  print('');
  print('Options:');
  print('  --help, -h    Show this help message');
  print('');
  print('Exit codes:');
  print('  0             No critical issues');
  print('  1-125         Number of critical issues found');
  print('');
  print('Example:');
  print('  dart run saropa_lints:impact_report');
  print('  dart run saropa_lints:impact_report ./my_project');
}
