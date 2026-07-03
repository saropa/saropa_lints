// Unit tests for [detectAnalysisFailure], the guard that stops the baseline
// generator from reporting a false "clean codebase" success when the analysis
// server crashes (issue #269). A crashed analyzer produces no parseable
// violations, so an empty result must be distinguished from a genuinely clean
// run before the tool claims no baseline is needed.
library;

import 'package:saropa_lints/src/baseline/analysis_failure.dart';
import 'package:test/test.dart';

void main() {
  group('detectAnalysisFailure', () {
    // The exact crash reproducer from issue #269: an analyzer plugin using
    // native build hooks fails to AOT-compile, the plugin manager throws, and
    // dart analyze exits 255 with no violation lines.
    const pluginCrashStderr = '''
An error occurred while executing an analyzer plugin: Failed to compile
"C:\\Users\\EDY\\AppData\\Local\\.dartServer\\.plugin_manager\\bin\\plugin.dart"
 to an AOT snapshot.

stderr = 'dart compile' does not support build hooks, use 'dart build' instead.
#0      PluginManager._compileAsAot (package:analysis_server/src/plugin/plugin_manager.dart:515)
''';

    test('flags the analyzer plugin AOT crash (exit 255, no violations)', () {
      final failure = detectAnalysisFailure(
        exitCode: 255,
        parsedViolationCount: 0,
        stdout: '',
        stderr: pluginCrashStderr,
      );

      expect(failure, isNotNull);
    });

    test('detects the crash signature even when exit code is 0', () {
      // Some crash paths still return a zero exit code; the signature match is
      // what makes this unambiguous, independent of the exit code heuristic.
      final failure = detectAnalysisFailure(
        exitCode: 0,
        parsedViolationCount: 0,
        stdout: pluginCrashStderr,
        stderr: '',
      );

      expect(failure, isNotNull);
    });

    test('flags non-zero exit with zero parsed violations as a failure', () {
      // Analysis that exits non-zero yet yields nothing to parse never
      // completed; the empty result cannot be trusted as clean.
      final failure = detectAnalysisFailure(
        exitCode: 255,
        parsedViolationCount: 0,
        stdout: '',
        stderr: 'some unexpected fatal output',
      );

      expect(failure, isNotNull);
      expect(failure, contains('255'));
    });

    test('returns null for a genuinely clean run (exit 0, no violations)', () {
      final failure = detectAnalysisFailure(
        exitCode: 0,
        parsedViolationCount: 0,
        stdout: 'Analyzing project...\nNo issues found!',
        stderr: '',
      );

      expect(failure, isNull);
    });

    test('returns null when real violations were parsed (non-zero exit)', () {
      // The normal baseline case: dart analyze finds lint issues and exits
      // non-zero, but the violations parsed successfully, so it is not a crash.
      final failure = detectAnalysisFailure(
        exitCode: 1,
        parsedViolationCount: 12,
        stdout: 'lib/main.dart:1:1 • avoid_print • ...',
        stderr: '',
      );

      expect(failure, isNull);
    });

    test('matches signatures case-insensitively', () {
      final failure = detectAnalysisFailure(
        exitCode: 0,
        parsedViolationCount: 0,
        stdout: 'AN ERROR OCCURRED WHILE EXECUTING AN ANALYZER PLUGIN',
        stderr: '',
      );

      expect(failure, isNotNull);
    });
  });
}
