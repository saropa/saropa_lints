#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/PLAN_comment_coverage.md`.
library;

// CLI tool to run dart analyze and display severity summary.
//
// Usage:
//   dart run saropa_lints:severity_report [path]
//   dart run saropa_lints:severity_report --help
//
// This tool:
// 1. Runs `dart analyze` on your project
// 2. Parses the output to extract violations
// 3. Displays a summary grouped by severity (error / warning / info)
// 4. Shows errors first
//
// Renamed from `impact_report` on 2026-06-05 after the LintImpact 5-bucket
// taxonomy collapsed into the analyzer's 3-level severity model (error /
// warning / info). `bin/impact_report.dart` remains as a thin forwarder so
// existing `dart run saropa_lints:impact_report` invocations keep working.

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/models/violation.dart';
import 'package:saropa_lints/src/violation_parser.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();

    return;
  }

  // WP2 (plans/PLAN_ext_ui_dart_deferred.md): `--format json` is the first of
  // 7 report CLIs to grow a machine-readable output so the Project Map
  // Reports tab can render real File/Line/Rule/Message columns instead of a
  // generic line-number table. Parsed by hand (not `_readOption`, which lives
  // only in accuracy_report.dart) so this CLI keeps zero new dependencies;
  // `--format` consumes its value here so it is never mistaken for the
  // positional <path> below (previously `args.first` — a bare `--format`
  // would have been swallowed as the project path).
  String? path;
  String? format;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--format' && i + 1 < args.length) {
      format = args[++i];
    } else if (!arg.startsWith('-') && path == null) {
      path = arg;
    }
  }
  path ??= '.';
  final asJson = format == 'json';

  // JSON mode never prints the human progress banner — its stdout must be
  // pure JSON for the extension's JSON.parse to succeed.
  if (!asJson) {
    print('Running lint analysis...');
    print('');
  }

  final result = await Process.run(
    'dart',
    ['analyze'],
    workingDirectory: path,
    runInShell: true,
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  if (stderr.isNotEmpty && !stderr.contains('Analyzing')) {
    // JSON mode: an error object instead of freeform text, so a consumer that
    // always JSON.parse()s stdout (the extension's Reports tab) never trips
    // over a non-JSON failure payload.
    if (asJson) {
      print(
        const JsonEncoder.withIndent('  ').convert({'error': stderr.trim()}),
      );
    } else {
      print('Error running dart analyze:');
      print(stderr);
    }
    exit(1);
  }

  final violations = parseViolations(output);

  if (violations.isEmpty) {
    if (asJson) {
      // Empty array, not `{}` — the TS row parser always expects a JSON
      // array to map over regardless of violation count.
      print(const JsonEncoder.withIndent('  ').convert(<Object?>[]));
      return;
    }
    print('No issues found!');
    print('');
    print('Severity Summary');
    print('================');
    print('ERRORS:   0');
    print('WARNINGS: 0');
    print('INFO:     0');

    return;
  }

  // JSON mode short-circuits before any of the human-readable print()s below
  // — `violationsToJsonRows` is the single source of truth for the schema,
  // exercised directly by test/report/severity_report_json_test.dart.
  if (asJson) {
    print(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(violationsToJsonRows(violations)),
    );
    // Exit code contract is unchanged by --format: caller (CI, the extension)
    // still gets a non-zero code proportional to the error count.
    final errorCount = violations.where((v) => v.impact == LintImpact.error).length;
    if (errorCount > 0) exit(errorCount > 125 ? 125 : errorCount);
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

/// Converts violations into the `--format json` row shape: `file`, `line`,
/// `column`, `rule`, `severity`, `message`. Extracted (public, no leading
/// underscore) so a unit test can pin the schema without spawning
/// `dart analyze` — `main()` is otherwise untestable in isolation because it
/// always shells out to the real analyzer. `severity` mirrors
/// `Violation.impact` (error/warning/info) with `warning` as the fallback for
/// the rare violation whose rule has no registered impact.
List<Map<String, Object?>> violationsToJsonRows(List<Violation> violations) {
  return [
    for (final v in violations)
      {
        'file': v.file,
        'line': v.line,
        'column': v.column,
        'rule': v.rule,
        'severity': v.impact?.name ?? 'warning',
        'message': v.message,
      },
  ];
}

void _printUsage() {
  print('saropa_lints Severity Report');
  print('');
  print('Usage: dart run saropa_lints:severity_report [path]');
  print('');
  print('Runs dart analyze and displays results grouped by severity.');
  print('Errors are shown first, then warnings, then info.');
  print('');
  print('Options:');
  print('  --help, -h        Show this help message');
  print('  --format json     Machine-readable JSON array of');
  print('                    {file,line,column,rule,severity,message} rows');
  print('');
  print('Exit codes:');
  print('  0             No errors');
  print('  1-125         Number of errors found');
  print('');
  print('Example:');
  print('  dart run saropa_lints:severity_report');
  print('  dart run saropa_lints:severity_report ./my_project');
  print('  dart run saropa_lints:severity_report --format json ./my_project');
}
