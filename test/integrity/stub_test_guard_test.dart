import 'dart:io';

import 'package:saropa_lints/src/cli/project_health/stub_density.dart';
import 'package:test/test.dart';

/// Guards against re-introducing tautological tests that do not validate
/// behavior and always pass.
void main() {
  group('Stub test guard', () {
    // Hard zero gate on the unambiguous stub shape: a `test`/`testWidgets` with
    // an empty block body (`() {}`). 396 of these were removed 2026-06-10 (see
    // plans/history/2026.06/2026.06.14/BUG_stub_tests_in_suite.md). This is
    // intentionally NARROWER than
    // scanStubTests' "no assertion call" heuristic, which legitimately flags
    // helper-asserted and "does not throw" tests — gating that broader metric
    // to zero would force-delete real tests. Empty-body has no such ambiguity.
    test('no empty-body test/testWidgets stubs remain', () {
      final offenders = scanEmptyBodyStubTests('.');
      final total = offenders.values.fold<int>(0, (sum, count) => sum + count);
      final preview =
          (offenders.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(20)
              .map((e) => '- ${e.key}: ${e.value}')
              .join('\n');
      expect(
        offenders,
        isEmpty,
        reason:
            'Found $total empty-body stub test(s) across ${offenders.length} '
            'files. An empty test body always passes and asserts nothing — '
            'give it a real expect/assert or delete it.\n$preview',
      );
    });

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
