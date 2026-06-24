#!/usr/bin/env dart
/// CLI: measure rule liveness against the `expect_lint` fixture ground truth.
///
/// For every rule declared by an `// expect_lint:` marker in a fixtures tree
/// (default `example/lib`), runs a resolved scan and checks the rule actually
/// fires in that fixture. A declared-but-silent rule is reported and (by
/// default) fails the gate — the existing contract tests only check the marker
/// text exists, never that the rule still works. Mirrors the `quality_gate`
/// split: the matching logic lives in the testable
/// `lib/src/report/accuracy_report.dart` core; this entrypoint only does IO,
/// scan execution, formatting, and exit codes.
///
/// True false-positive / true-positive *rate* measurement against each rule's
/// `accuracyTarget` is out of scope until the fixture corpus is line-precise —
/// see `plans/TODO_rule_metadata_completeness.md` §4.1.
///
/// Exit codes:
///   0 - no silent rules (or --fail-on none)
///   1 - at least one rule is declared in a fixture but never fires there
///   2 - bad arguments / scan could not run
// ignore_for_file: avoid_print
library;

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show AccuracyTarget, allSaropaRules;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/report/accuracy_report.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final fixturesDir = _readOption(args, '--fixtures') ?? 'example/lib';
  final tier = _readOption(args, '--tier') ?? 'pedantic';
  final failOn = _readOption(args, '--fail-on') ?? 'silent';
  final asJson = args.contains('--format') &&
      (_readOption(args, '--format') == 'json');

  if (!const {'silent', 'none'}.contains(failOn)) {
    print('Error: --fail-on must be one of silent, none (got "$failOn").');
    exit(2);
  }

  final dir = Directory(fixturesDir);
  if (!dir.existsSync()) {
    print('Error: fixtures directory not found: $fixturesDir');
    exit(2);
  }

  final expected = _collectExpectedLints(dir);
  final diagnostics = await _runScan(fixturesDir, tier);
  if (diagnostics == null) {
    print('Error: scan failed for $fixturesDir (tier: $tier).');
    exit(2);
  }

  final report = computeAccuracy(
    expected: expected,
    actual: diagnostics.map(_toLocation),
    targets: _buildTargets(),
  );

  if (asJson) {
    print(_reportToJson(report));
  } else {
    _printReport(report);
  }

  exit(_exitCode(report, failOn));
}

/// Walks [dir] for `.dart` files and parses their `expect_lint` markers into
/// canonical-path locations so they compare equal to scan diagnostic paths.
List<LintLocation> _collectExpectedLints(Directory dir) {
  final locations = <LintLocation>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final canonicalPath = p.canonicalize(entity.path);
    for (final marker in parseExpectedLints(entity.readAsStringSync())) {
      locations.add((rule: marker.rule, file: canonicalPath, line: marker.line));
    }
  }
  return locations;
}

/// Runs a fully-resolved scan so type-based and instance-creation rules fire
/// (the default syntactic pass under-reports them — see scan.dart).
Future<List<ScanDiagnostic>?> _runScan(String path, String tier) {
  final runner = ScanRunner(
    targetPath: path,
    tier: tier,
    // Suppress the scanner's own progress chatter; this CLI prints its report.
    messageSink: (_) {},
  );
  return runner.runResolved();
}

/// Normalizes a scan diagnostic to a core [LintLocation] with a canonical path.
LintLocation _toLocation(ScanDiagnostic d) =>
    (rule: d.ruleName, file: p.canonicalize(d.filePath), line: d.line);

/// Builds the rule -> target lookup from the live registry.
Map<String, AccuracyTarget?> _buildTargets() {
  final targets = <String, AccuracyTarget?>{};
  for (final rule in allSaropaRules) {
    targets[rule.code.name] = rule.accuracyTarget;
  }
  return targets;
}

/// Maps the report to the configured exit code. `none` always passes.
int _exitCode(AccuracyReport report, String failOn) {
  if (failOn == 'none') return 0;
  return report.silentRules.isEmpty ? 0 : 1;
}

String? _readOption(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// Prints a human-readable summary: totals, then the silent (dead) rules.
void _printReport(AccuracyReport report) {
  print('Rule liveness report');
  print('  rules measured:    ${report.rules.length}');
  print('  fixtures declared: ${report.totalTestedFiles}');
  print('  fixtures fired:    ${report.totalFiredFiles}');
  print('');

  final silent = report.silentRules;
  if (silent.isEmpty) {
    print('All declared rules fire in their fixtures.');
  } else {
    print('Silent rules (declared in a fixture but never fire there):');
    for (final r in silent) {
      print('  - ${r.rule}  [${r.testedFiles.join(', ')}]');
    }
  }

  // Partial firing is informational: a rule live in some fixtures, dead in
  // others — usually a missing case, not a fully broken rule.
  final partial = report.partiallyFiringRules;
  if (partial.isNotEmpty) {
    print('');
    print('Partially-firing rules (fire in some declaring fixtures):');
    for (final r in partial) {
      print('  - ${r.rule}: ${r.firedFiles.length}/${r.testedFiles.length} '
          'fixtures; silent in [${r.silentFiles.join(', ')}]');
    }
  }
}

/// Serializes the report to stable JSON for CI consumption / diffing.
String _reportToJson(AccuracyReport report) {
  final rules = report.rules
      .map((r) => {
            'rule': r.rule,
            'testedFiles': r.testedFiles.length,
            'firedFiles': r.firedFiles.length,
            'firingRate': r.firingRate,
            'silent': r.isSilent,
            'silentFiles': r.silentFiles.toList()..sort(),
          })
      .toList();

  final payload = {
    'summary': {
      'rulesMeasured': report.rules.length,
      'testedFiles': report.totalTestedFiles,
      'firedFiles': report.totalFiredFiles,
      'silentRules': report.silentRules.length,
    },
    'rules': rules,
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

void _printUsage() {
  print('saropa_lints accuracy_report - measure rule liveness in fixtures');
  print('');
  print('For every rule with an // expect_lint: marker, confirms the rule');
  print('actually fires in that fixture (the contract tests only check the');
  print('marker text exists). A declared-but-silent rule fails the gate.');
  print('');
  print('Usage: dart run saropa_lints:accuracy_report [options]');
  print('');
  print('Options:');
  print('  --fixtures <dir>   Fixtures tree to scan (default: example/lib)');
  print('  --tier <name>      Tier to enable for the scan (default: pedantic)');
  print('  --fail-on <mode>   silent | none (default: silent)');
  print('                       silent = exit 1 if any rule never fires');
  print('                       none   = always exit 0 (report only)');
  print('  --format json      Machine-readable JSON to stdout');
  print('  -h, --help         Show this help');
}
