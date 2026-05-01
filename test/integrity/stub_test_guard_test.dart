import 'dart:io';

import 'package:test/test.dart';

/// Guards against re-introducing tautological tests that do not validate
/// behavior and always pass.
void main() {
  group('Stub test guard', () {
    test('no expect(true, isTrue) stubs remain', () {
      final offenders = _collectFileCounts(
        RegExp(r'expect\(\s*true\s*,\s*isTrue\s*\)'),
      );
      expect(
        offenders,
        isEmpty,
        reason: _formatFailure(
          offenders,
          issueLabel: 'expect(true, isTrue)',
          guidance: 'Replace these with real lint-behavior assertions.',
        ),
      );
    });

    test('no literal expect(..., isNotNull) stubs remain', () {
      final offenders = _collectFileCounts(
        RegExp(r'''expect\(\s*(?:'[^']*'|"[^"]*")\s*,\s*isNotNull\s*\)'''),
      );
      expect(
        offenders,
        isEmpty,
        reason: _formatFailure(
          offenders,
          issueLabel: 'expect(<string literal>, isNotNull)',
          guidance: 'Assert analysis output instead of tautological literals.',
        ),
      );
    });
  });
}

Map<String, int> _collectFileCounts(RegExp pattern) {
  final matchesByFile = <String, int>{};
  for (final file in Directory('test').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('_test.dart')) continue;
    if (file.path.endsWith('stub_test_guard_test.dart')) continue;
    final normalizedPath = file.path.replaceAll('\\', '/');
    final content = file.readAsStringSync();
    final count = pattern.allMatches(content).length;
    if (count == 0) continue;
    matchesByFile[normalizedPath] = count;
  }
  return matchesByFile;
}

String _formatFailure(
  Map<String, int> offenders, {
  required String issueLabel,
  required String guidance,
}) {
  if (offenders.isEmpty) return '';
  final total = offenders.values.fold<int>(0, (sum, count) => sum + count);
  final lines = offenders.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final preview = lines
      .take(20)
      .map((entry) => '- ${entry.key}: ${entry.value}');
  final suffix = lines.length > 20
      ? '\n- ... ${lines.length - 20} more files omitted'
      : '';
  return 'Found $total $issueLabel tautologies across ${lines.length} files.\n'
      '$guidance\n'
      '${preview.join('\n')}$suffix';
}
