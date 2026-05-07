/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see
/// `plans/COMMENT_COVERAGE_PLAN.md`.
library;

import 'dart:convert';
import 'dart:io';

// Scans test/*.dart for absurd expect() anti-patterns; writes optional JSON report; non-zero if found.

void main(List<String> args) {
  final outputPath = _parseOutputPath(args);
  final report = _buildReport();
  final prettyJson = const JsonEncoder.withIndent('  ').convert(report);

  if (outputPath != null) {
    final file = File(outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$prettyJson\n');
  }

  stdout.writeln(prettyJson);
  if (_total(report, 'literalIsNotNull') > 0 ||
      _total(report, 'trueIsTrue') > 0) {
    exitCode = 1;
  }
}

Map<String, Object?> _buildReport() {
  final literalPattern = RegExp(
    r'''expect\(\s*(?:'[^']*'|"[^"]*")\s*,\s*isNotNull\s*\)''',
  );
  final truePattern = RegExp(r'expect\(\s*true\s*,\s*isTrue\s*\)');
  final files = <Map<String, Object?>>[];
  var literalTotal = 0;
  var trueTotal = 0;

  for (final file in Directory('test').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('_test.dart')) continue;
    if (file.path.endsWith('stub_test_guard_test.dart')) continue;
    final content = file.readAsStringSync();
    final literalCount = literalPattern.allMatches(content).length;
    final trueCount = truePattern.allMatches(content).length;
    if (literalCount == 0 && trueCount == 0) continue;

    literalTotal += literalCount;
    trueTotal += trueCount;
    files.add({
      'path': file.path.replaceAll('\\', '/'),
      'literalIsNotNull': literalCount,
      'trueIsTrue': trueCount,
      'total': literalCount + trueCount,
    });
  }

  int totalOf(Map<String, Object?> row) {
    final t = row['total'];
    return t is int ? t : 0;
  }

  files.sort((a, b) => totalOf(b).compareTo(totalOf(a)));

  return {
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'patterns': {
      'literalIsNotNull': literalPattern.pattern,
      'trueIsTrue': truePattern.pattern,
    },
    'totals': {
      'literalIsNotNull': literalTotal,
      'trueIsTrue': trueTotal,
      'combined': literalTotal + trueTotal,
      'filesWithMatches': files.length,
    },
    'files': files,
  };
}

String? _parseOutputPath(List<String> args) {
  const prefix = '--write=';
  for (final arg in args) {
    if (!arg.startsWith(prefix)) continue;
    final value = arg.replaceFirst(prefix, '').trim();
    if (value.isEmpty) continue;
    return value;
  }
  return null;
}

int _total(Map<String, Object?> report, String key) {
  final totals = report['totals'];
  if (totals is! Map<String, Object?>) return 0;
  final v = totals[key];
  return v is int ? v : 0;
}
