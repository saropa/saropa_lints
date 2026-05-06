/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/COMMENT_COVERAGE_PLAN.md`.

#!/usr/bin/env dart
// ignore_for_file: avoid_print

library;

import 'dart:convert' show JsonEncoder, jsonDecode;
import 'dart:io' show File, Platform, exit;

/// Generates a baseline snapshot for diagnostic statistics comparisons.
///
/// Reads `reports/.saropa_lints/violations.json` and writes:
/// `{ "issuesByRule": { ... }, "totalViolations": n, "generatedAt": ... }`
/// to a target JSON file.
Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final sourcePath =
      _readOption(args, '--from') ??
      _readOption(args, '-f') ??
      'reports/.saropa_lints/violations.json';
  final outputPath =
      _readOption(args, '--output') ??
      _readOption(args, '-o') ??
      'reports/.saropa_lints/diagnostic_baseline.json';

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('Error: source file not found: $sourcePath');
    print(
      'Run analysis first to generate violations.json, then retry this command.',
    );
    exit(2);
  }

  final snapshot = _buildSnapshot(sourceFile);
  if (snapshot == null) {
    print('Error: could not parse issuesByRule from: $sourcePath');
    exit(3);
  }

  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(snapshot),
  );

  final issuesByRuleValue = snapshot['issuesByRule'];
  final totalValue = snapshot['totalViolations'];
  if (issuesByRuleValue is! Map<String, Object?> || totalValue is! int) {
    print('Error: baseline snapshot payload is missing expected fields.');
    exit(4);
  }

  final issuesByRule = issuesByRuleValue;
  final total = totalValue;
  print('Diagnostic baseline written: $outputPath');
  print('Rules captured: ${issuesByRule.length}');
  print('Total violations captured: $total');
}

Map<String, Object>? _buildSnapshot(File sourceFile) {
  try {
    final raw = jsonDecode(sourceFile.readAsStringSync());
    if (raw is! Map) return null;

    final summary = raw['summary'];
    if (summary is! Map) return null;

    final rawIssuesByRule = summary['issuesByRule'];
    if (rawIssuesByRule is! Map) return null;

    final issuesByRule = <String, int>{};
    rawIssuesByRule.forEach((key, value) {
      if (key is! String || value is! int) return;
      issuesByRule[key] = value;
    });

    return <String, Object>{
      'schema': 'diagnostic-baseline.v1',
      'source': sourceFile.path.replaceAll(Platform.pathSeparator, '/'),
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'totalViolations': issuesByRule.values.fold<int>(
        0,
        (sum, count) => sum + count,
      ),
      'issuesByRule': issuesByRule,
    };
  } on Object {
    return null;
  }
}

String? _readOption(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _printUsage() {
  print('Diagnostic baseline snapshot generator');
  print('');
  print('Usage: dart run saropa_lints:diagnostic_baseline [options]');
  print('');
  print('Options:');
  print(
    '  -f, --from <path>     Source violations JSON '
    '(default: reports/.saropa_lints/violations.json)',
  );
  print(
    '  -o, --output <path>   Output baseline JSON '
    '(default: reports/.saropa_lints/diagnostic_baseline.json)',
  );
  print('  -h, --help            Show this help');
  print('');
  print('Example:');
  print(
    '  dart run saropa_lints:diagnostic_baseline '
    '--from reports/.saropa_lints/violations.json '
    '--output reports/.saropa_lints/diagnostic_baseline.json',
  );
}
