import 'dart:io';

/// Removes lines that match [stub_test_guard_test.dart] tautology detection:
/// `expect('<literal>', isNotNull)` / `expect("...", isNotNull)`.
///
/// Run from repo root: `dart run tool/strip_literal_isnotnull_stub_lines.dart`
void main() {
  final linePattern = RegExp(
    r'''^\s*expect\(\s*(?:'[^']*'|"[^"]*")\s*,\s*isNotNull\s*\);\s*$''',
  );
  var filesChanged = 0;
  var linesRemoved = 0;

  for (final entity in Directory('test').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_test.dart')) continue;
    if (entity.path.endsWith('stub_test_guard_test.dart')) continue;

    final original = entity.readAsStringSync();
    final out = <String>[];
    for (final line in original.split('\n')) {
      if (linePattern.hasMatch(line)) {
        linesRemoved++;
        continue;
      }
      out.add(line);
    }
    final next = out.join('\n');
    if (next != original) {
      entity.writeAsStringSync(next);
      filesChanged++;
    }
  }

  stderr.writeln(
    'strip_literal_isnotnull_stub_lines: '
    '$linesRemoved lines removed across $filesChanged files.',
  );
}
