import 'dart:io';

import 'package:test/test.dart';

/// Guards against re-introducing tautological tests that do not validate
/// behavior and always pass.
void main() {
  group('Stub test guard', () {
    // Ratchet baseline captured on 2026-04-27 after widget-pattern + code-quality
    // stub cleanup batches.
    // This must only move downward as stub conversions land.
    const maxLiteralIsNotNullCount = 3349;

    test('no literal expect(true, isTrue) stubs remain', () {
      final matches = <String>[];
      final pattern = RegExp(r'expect\(\s*true\s*,\s*isTrue\s*\)');

      for (final file in Directory('test').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('_test.dart')) continue;
        if (file.path.endsWith('stub_test_guard_test.dart')) continue;
        final content = file.readAsStringSync();
        if (!pattern.hasMatch(content)) continue;
        matches.add(file.path.replaceAll('\\', '/'));
      }

      expect(
        matches,
        isEmpty,
        reason: matches.isEmpty
            ? null
            : 'Replace tautological tests in:\n- ${matches.join('\n- ')}',
      );
    });

    test('literal expect(..., isNotNull) count does not increase', () {
      final pattern = RegExp(r"expect\(\s*'[^']*'\s*,\s*isNotNull\s*\)");
      var count = 0;

      for (final file in Directory('test').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('_test.dart')) continue;
        if (file.path.endsWith('stub_test_guard_test.dart')) continue;
        final content = file.readAsStringSync();
        count += pattern.allMatches(content).length;
      }

      expect(
        count,
        lessThanOrEqualTo(maxLiteralIsNotNullCount),
        reason:
            'Found $count literal isNotNull assertions; baseline is '
            '$maxLiteralIsNotNullCount. Only reductions are allowed.',
      );
    });
  });
}
