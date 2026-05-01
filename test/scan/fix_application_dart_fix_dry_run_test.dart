// Plan §10 D4 — `dart fix --dry-run` integration smoke.
//
// Runs `dart fix --dry-run` inside the `example/` package, captures the output,
// and asserts:
//   * The command exits 0.
//   * The output is parseable (matches the established "X fixes" line format).
//
// We do NOT assert specific saropa fixes appear here because `dart fix` only
// invokes built-in analyzer fixes plus any registered through the analyzer
// plugin protocol; saropa-side custom-fix registration through that surface
// is part of plan §3 / plan §10 E1-E5. Once that lands, the per-fixture diff
// assertions below can be tightened.
//
// Skips when the dart binary is unavailable (CI image without SDK on PATH).

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group(
    'Plan §10 D4 — dart fix --dry-run on example/',
    timeout: const Timeout(Duration(minutes: 3)),
    () {
      test('exits cleanly and emits parseable output', () async {
        final exampleDir = Directory('example');
        if (!exampleDir.existsSync()) {
          // Allow CI images without the example checkout to skip cleanly.
          return;
        }

        final result = await Process.run(
          'dart',
          ['fix', '--dry-run'],
          workingDirectory: exampleDir.path,
          runInShell: true,
        );

        // exit 0 = nothing to fix OR dry-run completed; both are healthy.
        // Any other exit (e.g. analyzer crash, missing SDK) is a real failure.
        expect(
          result.exitCode,
          equals(0),
          reason:
              'dart fix --dry-run exited ${result.exitCode}\n'
              'STDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}',
        );

        final out = (result.stdout as String) + (result.stderr as String);
        // Expect either "Nothing to fix!" or a "X fixes" enumeration. Both
        // shapes are valid; either confirms the analyzer engaged.
        final hasReport =
            out.contains('Nothing to fix') ||
            RegExp(r'\d+\s+fix(es)?\b').hasMatch(out);
        expect(
          hasReport,
          isTrue,
          reason: 'Unexpected dart fix output shape:\n$out',
        );
      });
    },
  );
}
