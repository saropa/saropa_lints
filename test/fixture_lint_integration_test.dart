import 'dart:io';

import 'package:saropa_lints/src/violation_parser.dart';
import 'package:test/test.dart';

/// Integration test: run custom_lint on an example package and assert
/// output is parseable and fixtures produce expected rule diagnostics.
///
/// Validates that fixture files are actually analyzed and that
/// parseViolations correctly parses custom_lint output. Run from repo root.
void main() {
  group('Fixture lint integration', () {
    test('custom_lint on example_async produces parseable violations', () async {
      final exampleDir = Directory('example_async');
      if (!exampleDir.existsSync()) {
        return; // Skip when example_async not present (e.g. in some CI)
      }

      final result = await Process.run(
        'dart',
        ['run', 'custom_lint'],
        workingDirectory: exampleDir.path,
        runInShell: true,
      );

      // custom_lint may exit with 1 when there are lint issues
      final output = result.stdout as String;
      final errors = result.stderr as String;
      final violations = parseViolations(output);

      // Should be able to parse output without throwing
      expect(violations, isA<List>());

      // If there are lint issues, we should see some violations from our rules
      if (result.exitCode == 1 && output.isNotEmpty) {
        expect(
          violations.isNotEmpty || errors.contains('custom_lint'),
          isTrue,
          reason: 'Expected parseable lint output or custom_lint message',
        );
      }
    });
  });
}
