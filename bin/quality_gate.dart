#!/usr/bin/env dart

/// CLI for [QualityGateEvaluator]: reads `violations.json` summary and gate config,
/// prints PASS / FAIL / WARN, exits 0 (pass or no config), 1 (breach with fail), 2 (errors).
// ignore_for_file: avoid_print

library;

import 'dart:convert' show jsonDecode;
import 'dart:io' show File, exit;

import 'package:saropa_lints/src/report/quality_gate.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Defaults match typical saropa_lints report layout and repo-root config file.
  final reportPath =
      _readOption(args, '--report') ??
      _readOption(args, '-r') ??
      'reports/.saropa_lints/violations.json';
  final configPath =
      _readOption(args, '--config') ??
      _readOption(args, '-c') ??
      'saropa_quality_gate.yaml';
  final projectRoot = _readOption(args, '--project-root') ?? '.';

  final reportFile = File(reportPath);
  if (!reportFile.existsSync()) {
    print('Error: report file not found: $reportPath');
    exit(2);
  }

  // Expect top-level JSON with a `summary` object (same shape CI uses).
  final summary = _readSummary(reportFile);
  if (summary == null) {
    print('Error: invalid report format. Missing summary object.');
    exit(2);
  }

  final config = QualityGateEvaluator.parseConfigFile(
    projectRoot: projectRoot,
    configPath: configPath,
  );
  if (config.isEmpty) {
    // Missing file or empty conditions: not an error (nothing to enforce).
    print(
      'No quality gate conditions configured. '
      'Expected YAML/JSON with quality_gate.conditions in $configPath',
    );
    exit(0);
  }

  final result = QualityGateEvaluator.evaluate(
    summary: summary,
    config: config,
  );

  // Config errors (e.g. bad operator) are fatal like missing report.
  if (result.configErrors.isNotEmpty) {
    print('Quality gate configuration errors:');
    for (final err in result.configErrors) {
      print('  - $err');
    }
    exit(2);
  }

  if (result.breaches.isEmpty) {
    print('Quality gate: PASS');
    exit(0);
  }

  // Split breaches so `fail` drives exit 1; `warn`-only exits 0 with WARN banner.
  final failures = result.breaches.where((b) => b.condition.onFail == 'fail');
  final warnings = result.breaches.where((b) => b.condition.onFail == 'warn');

  if (failures.isNotEmpty) {
    print('Quality gate: FAIL');
    for (final breach in failures) {
      print('  - FAIL: ${breach.message}');
    }
    for (final breach in warnings) {
      print('  - WARN: ${breach.message}');
    }
    exit(1);
  }

  print('Quality gate: WARN');
  for (final breach in warnings) {
    print('  - WARN: ${breach.message}');
  }
  exit(0);
}

/// Extract `summary` from violations JSON; returns null on parse errors or wrong shape.
Map<String, dynamic>? _readSummary(File reportFile) {
  try {
    final decoded = jsonDecode(reportFile.readAsStringSync());
    if (decoded is! Map) return null;
    final map = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
    final summary = map['summary'];
    if (summary is! Map) return null;
    return Map<String, dynamic>.from(summary.cast<String, dynamic>());
  } on Object {
    return null;
  }
}

/// Reads `--key value` style argv; returns null if key missing or no following token.
String? _readOption(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _printUsage() {
  print('Quality gate evaluator');
  print('');
  print('Usage: dart run saropa_lints:quality_gate [options]');
  print('');
  print('Options:');
  print(
    '  -r, --report <path>      violations.json path '
    '(default: reports/.saropa_lints/violations.json)',
  );
  print(
    '  -c, --config <path>      quality gate YAML/JSON config '
    '(default: saropa_quality_gate.yaml)',
  );
  print(
    '      --project-root <dir> Resolve relative config path from this root',
  );
  print('  -h, --help               Show this help');
  print('');
  print('Config format (YAML):');
  print('quality_gate:');
  print('  conditions:');
  print('    - metric: new_critical_issues');
  print('      op: eq');
  print('      value: 0');
  print('      on_fail: fail');
  print('');
  print('Config format (JSON):');
  print('{');
  print('  "quality_gate": {');
  print('    "conditions": [');
  print(
    '      { "metric": "new_critical_issues", "op": "eq", "value": 0, "on_fail": "fail" }',
  );
  print('    ]');
  print('  }');
  print('}');
}
